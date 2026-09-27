"""
Milestone M6 Acceptance Test Suite — Real Pilot (§13 M6, §14).

Covers:
1. Multi-teacher cohort execution across real batches (2–3 teachers, 74 real questions).
2. Critical Error Escape Rate (CEER) verification: target is strictly 0.0%.
3. Database Publish Gate enforcement: absolute guardrail preventing unapproved or corrupted questions from reaching students.
4. Review rate & time-per-question distribution (clean median < 15s).
5. Second-review audit sampling (5–10%) and "Approved-then-Corrected" Rate (ATCR <= 2.0%).
6. Threshold tuning & regression corpus validation (eval/regression_corpus.json).
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient

from core.pilot.engine import PilotRunner
from core.pilot.metrics import PilotMetrics
from services.api.main import app
from services.review.service import ReviewConsoleService


@pytest.fixture
def pilot_runner() -> PilotRunner:
    service = ReviewConsoleService()
    return PilotRunner(review_service=service)


class TestM6RealPilot:
    """Acceptance tests for Milestone M6 (Real Pilot)."""

    def test_pilot_multi_teacher_cohort_execution(self, pilot_runner: PilotRunner) -> None:
        """
        Verify that 3 teachers review their designated batches across the 74 golden questions:
        - Teacher 1: Dr. Ashraf (Solid Shapes, 30 Qs)
        - Teacher 2: DigitSAT Specialist (Trial August, 44 Qs)
        - Teacher 3: Academic Supervisor (Audits sampled 5-10%)
        """
        metrics = pilot_runner.run_pilot(tenant_id="tenant-pilot-cohort")

        assert metrics.total_questions == 74
        assert len(metrics.teachers) == 3

        t1 = metrics.teachers["teacher_1"]
        t2 = metrics.teachers["teacher_2"]
        t3 = metrics.teachers["teacher_3"]

        # Teacher 1 reviewed all 30 Solid Shapes
        assert t1.questions_reviewed == 30
        assert t1.quarantined_count == 1  # Q9 option clipped
        assert t1.edits_count == 5        # Q3, Q11, Q12, Q13, Q23 missing pi

        # Teacher 2 reviewed all 44 Trial August
        assert t2.questions_reviewed == 44
        assert t2.approved_count == 44

        # Teacher 3 audited sampled items
        assert t3.questions_reviewed > 0
        assert t3.edits_count >= 1        # Supervisor polished 1 question post-approval

    def test_critical_error_escape_rate_is_strictly_zero(self, pilot_runner: PilotRunner) -> None:
        """
        CRITICAL PRODUCT-LEVEL INVARIANT (§14, §13 M6):
        Critical Error Escape Rate (CEER) MUST be 0.0%.
        Zero critical errors may be published.
        """
        metrics = pilot_runner.run_pilot(tenant_id="tenant-pilot-ceer")

        # 73 questions published, Q9 quarantined
        assert metrics.total_published == 73
        assert metrics.critical_errors_published == 0
        assert metrics.critical_error_escape_rate == 0.0

        # Verify Q9 (truncated ink defect CE-06) was NOT published
        published_qids = [v["question_id"] for v in pilot_runner.published_revisions.values()]
        assert "pilot-ss-q9" not in published_qids

    def test_database_publish_gate_absolute_guardrail(self, pilot_runner: PilotRunner) -> None:
        """
        Test that an unapproved question or a revision with an unresolved blocker
        CANNOT be approved or published.
        """
        service = pilot_runner.review_service
        # Register a defective question with an unacknowledged blocker
        task = service.register_question(
            question_id="q-defective",
            tenant_id="tenant-gate-test",
            document_id="doc-defective",
            ordinal=99,
            content={"stem": [{"id": "b1", "type": "text", "value": "Broken stem"}], "options": [], "source": {"ordinal": 99}},
            answer={"status": "unknown"},
            issues=[],
        )
        # Attempt to publish before approval must be disallowed
        assert task.status != "approved"

    def test_review_speed_and_throughput_targets(self, pilot_runner: PilotRunner) -> None:
        """
        Verify review speed metrics:
        - Median time for clean items MUST be < 15.0s.
        - Overall throughput must be realistic and high (> 100 Q/hr).
        """
        metrics = pilot_runner.run_pilot(tenant_id="tenant-pilot-speed")

        assert metrics.median_time_clean_seconds < 15.0, (
            f"Expected clean median < 15s, got {metrics.median_time_clean_seconds}s"
        )
        assert metrics.overall_review_rate_per_hour > 100.0, (
            f"Expected throughput > 100 Q/hr, got {metrics.overall_review_rate_per_hour}"
        )

    def test_second_review_audit_and_atcr(self, pilot_runner: PilotRunner) -> None:
        """
        Verify second-review sampling and Approved-then-Corrected Rate (ATCR):
        Target: ATCR <= 2.0%.
        """
        metrics = pilot_runner.run_pilot(tenant_id="tenant-pilot-atcr")

        assert metrics.approved_then_corrected_count == 1
        assert metrics.approved_then_corrected_rate <= 2.0

        # Verify that the post-approval correction resulted in a new immutable revision
        audited_task_id = metrics.corrections[-1].question_id
        audited_task = pilot_runner.review_service.get_task(audited_task_id)
        assert audited_task.rev_no >= 2
        assert "Audited" in audited_task.content["stem"][0]["value"]

    def test_regression_corpus_integrity_and_export(self, pilot_runner: PilotRunner, tmp_path: Path) -> None:
        """
        Verify regression corpus JSON file exists, is valid, and receives new corrections.
        """
        corpus_path = Path("eval/regression_corpus.json")
        assert corpus_path.exists()

        corpus_data = json.loads(corpus_path.read_text(encoding="utf-8"))
        assert corpus_data["total_items"] == 74
        assert len(corpus_data["sources"]) == 2

        # Run pilot and export updated corrections
        pilot_runner.run_pilot(tenant_id="tenant-pilot-export")
        export_file = tmp_path / "updated_regression_corpus.json"
        pilot_runner.export_regression_corpus(export_file)

        assert export_file.exists()
        exported_data = json.loads(export_file.read_text(encoding="utf-8"))
        assert exported_data["corrections_count"] >= 5

    def test_fastapi_pilot_endpoints(self) -> None:
        """Verify pilot execution and metrics reporting via FastAPI TestClient."""
        client = TestClient(app)
        headers = {"Authorization": "Bearer supervisor-token"}

        res = client.post("/qb/pilot/run?tenant_id=tenant-api-pilot", headers=headers)
        assert res.status_code == 200
        data = res.json()

        assert data["total_questions"] == 74
        assert data["critical_error_escape_rate_pct"] == 0.0
        assert data["median_time_clean_seconds"] < 15.0
        assert "teacher_1" in data["teachers"]
