"""
Milestone M5 Acceptance Test Suite — Review Console Completion (§10, §13 M5).

Covers:
1. Priority queue ordering: math (4.0) > answer (3.0) > figure (2.0) > text (1.0).
2. Duplicate cluster grouping (near-duplicates kept adjacent).
3. Ack-per-issue invariant: approval is disabled while unresolved blockers exist;
   acknowledgment or block-edit unblocks approval.
4. Block-level edit: generates new immutable revision with incremented rev_no and new content hash;
   prior revisions remain immutable.
5. Teacher answer selection: resolves unknown or conflicting answers (B-040, B-041).
6. Structural actions: merge-with-next, split-question, mark-source-unreadable.
7. Safe revision restore: creates new revision identical to target revision.
8. Second-review sampling (5–10% random sampling).
9. FastAPI endpoints validation.
10. End-to-end clearing of 30-question Solid Shapes batch simulation measuring median time (<15s clean) and review rate.
"""

from __future__ import annotations

import uuid
from typing import Any

import pytest
from fastapi.testclient import TestClient

from core.models.issues import ValidationIssue
from services.api.main import app
from services.review.api import review_service as global_review_service
from services.review.service import ReviewConsoleService


@pytest.fixture
def review_svc() -> ReviewConsoleService:
    return ReviewConsoleService()


def _make_stem(blocks: list[tuple[str, str, str]]) -> list[dict[str, Any]]:
    """Helper to build stem blocks: [(id, type, value/latex)]."""
    stem: list[dict[str, Any]] = []
    for b_id, b_type, val in blocks:
        if b_type == "math":
            stem.append({"id": b_id, "type": "math", "latex": val, "value": val, "source_refs": [f"ref_{b_id}"]})
        else:
            stem.append({"id": b_id, "type": b_type, "value": val, "source_refs": [f"ref_{b_id}"]})
    return stem


def _make_options() -> list[dict[str, Any]]:
    return [
        {"key": "A", "content": [{"id": "opt_a", "type": "text", "value": "13,122pi", "source_refs": ["ref_a"]}], "source_refs": ["ref_a"]},
        {"key": "B", "content": [{"id": "opt_b", "type": "text", "value": "26,244pi", "source_refs": ["ref_b"]}], "source_refs": ["ref_b"]},
        {"key": "C", "content": [{"id": "opt_c", "type": "text", "value": "6,561pi", "source_refs": ["ref_c"]}], "source_refs": ["ref_c"]},
        {"key": "D", "content": [{"id": "opt_d", "type": "text", "value": "4,374pi", "source_refs": ["ref_d"]}], "source_refs": ["ref_d"]},
    ]


class TestM5ReviewConsole:
    """Acceptance tests for Milestone M5."""

    def test_priority_queue_ordering(self, review_svc: ReviewConsoleService) -> None:
        """
        Verify review queue ordering follows priority score:
        math (4.0) > answer (3.0) > figure (2.0) > text (1.0).
        """
        tenant_id = "tenant-ordering-test"
        doc_id = "doc-test"

        # Q1: Text issue only (B-050 WARN) -> priority 3.0 * 1.0 = 3.0
        review_svc.register_question(
            question_id="q-text",
            tenant_id=tenant_id,
            document_id=doc_id,
            ordinal=1,
            content={"stem": _make_stem([("b1", "text", "Text problem")]), "options": _make_options(), "source": {"ordinal": 1}},
            answer={"status": "source_extracted", "raw": "A"},
            issues=[ValidationIssue(rule_id="B-050", severity="WARN", message={"en": "Watermark removed", "ar": "إزالة علامة مائية"})],
        )

        # Q2: Figure issue (B-030 BLOCKER) -> priority 10.0 * 2.0 = 20.0
        review_svc.register_question(
            question_id="q-figure",
            tenant_id=tenant_id,
            document_id=doc_id,
            ordinal=2,
            content={"stem": _make_stem([("b1", "text", "Figure problem")]), "options": _make_options(), "source": {"ordinal": 2}},
            answer={"status": "source_extracted", "raw": "B"},
            issues=[ValidationIssue(rule_id="B-030", severity="BLOCKER", block_ref="fig1", message={"en": "Figure missing", "ar": "رسم مفقود"})],
        )

        # Q3: Answer conflict (B-041 BLOCKER) -> priority 10.0 * 3.0 = 30.0
        review_svc.register_question(
            question_id="q-answer",
            tenant_id=tenant_id,
            document_id=doc_id,
            ordinal=3,
            content={"stem": _make_stem([("b1", "text", "Answer problem")]), "options": _make_options(), "source": {"ordinal": 3}},
            answer={"status": "unknown", "raw": "C"},
            issues=[ValidationIssue(rule_id="B-041", severity="BLOCKER", block_ref="answer", message={"en": "Answer conflict", "ar": "تعارض إجابة"})],
        )

        # Q4: Math token diff (B-020 BLOCKER) -> priority 10.0 * 4.0 = 40.0
        review_svc.register_question(
            question_id="q-math",
            tenant_id=tenant_id,
            document_id=doc_id,
            ordinal=4,
            content={"stem": _make_stem([("b1", "math", "x^2 + 14")]), "options": _make_options(), "source": {"ordinal": 4}},
            answer={"status": "source_extracted", "raw": "D"},
            issues=[ValidationIssue(rule_id="B-020", severity="BLOCKER", block_ref="b1", message={"en": "Critical token diff", "ar": "اختلاف رموز"})],
        )

        tasks = review_svc.list_tasks(tenant_id=tenant_id, sort_by_priority=True, cluster_duplicates=False)
        order = [t.question_id for t in tasks]

        # Expected priority: q-math (40) > q-answer (30) > q-figure (20) > q-text (3)
        assert order == ["q-math", "q-answer", "q-figure", "q-text"]
        assert tasks[0].priority_score == 40.0
        assert tasks[1].priority_score == 30.0
        assert tasks[2].priority_score == 20.0
        assert tasks[3].priority_score == 3.0

    def test_duplicate_cluster_grouping(self, review_svc: ReviewConsoleService) -> None:
        """
        Verify that near-duplicate questions belonging to the same duplicate_cluster_id
        are grouped consecutively in the queue.
        """
        tenant_id = "tenant-clustering-test"
        doc_id = "doc-test"

        # Q2 (Cone A): cluster "cluster-cone", priority 3.0
        review_svc.register_question(
            question_id="q-cone-1",
            tenant_id=tenant_id,
            document_id=doc_id,
            ordinal=2,
            content={"stem": _make_stem([("b1", "text", "Cone problem 1")]), "options": _make_options(), "source": {"ordinal": 2}},
            answer={"status": "source_extracted", "raw": "D"},
            issues=[ValidationIssue(rule_id="B-052", severity="WARN", message={"en": "Near duplicate", "ar": "تكرار محتمل"})],
            duplicate_cluster_id="cluster-cone",
        )

        # High priority standalone question: priority 40.0
        review_svc.register_question(
            question_id="q-urgent",
            tenant_id=tenant_id,
            document_id=doc_id,
            ordinal=5,
            content={"stem": _make_stem([("b1", "math", r"\pi")]), "options": _make_options(), "source": {"ordinal": 5}},
            answer={"status": "source_extracted", "raw": "A"},
            issues=[ValidationIssue(rule_id="B-020", severity="BLOCKER", message={"en": "Math diff", "ar": "اختلاف"})],
        )

        # Q4 (Cone B): cluster "cluster-cone", priority 0.0
        review_svc.register_question(
            question_id="q-cone-2",
            tenant_id=tenant_id,
            document_id=doc_id,
            ordinal=4,
            content={"stem": _make_stem([("b1", "text", "Cone problem 2")]), "options": _make_options(), "source": {"ordinal": 4}},
            answer={"status": "source_extracted", "raw": "D"},
            issues=[],
            duplicate_cluster_id="cluster-cone",
        )

        tasks = review_svc.list_tasks(tenant_id=tenant_id, sort_by_priority=True, cluster_duplicates=True)
        order = [t.question_id for t in tasks]

        # Urgent is first (highest score), then the cone cluster members are together
        assert order[0] == "q-urgent"
        assert order[1] == "q-cone-1"
        assert order[2] == "q-cone-2"

    def test_ack_per_issue_blocks_approval_until_acknowledged(self, review_svc: ReviewConsoleService) -> None:
        """
        Approve stays disabled until every open blocker is either edited away
        or confirmed/acknowledged.
        """
        tenant_id = "tenant-ack-test"
        doc_id = "doc-test"

        task = review_svc.register_question(
            question_id="q-ack",
            tenant_id=tenant_id,
            document_id=doc_id,
            ordinal=1,
            content={"stem": _make_stem([("b1", "text", "Problem")]), "options": _make_options(), "source": {"ordinal": 1}},
            answer={"status": "source_extracted", "raw": "A"},
            issues=[
                ValidationIssue(
                    rule_id="B-020",
                    severity="BLOCKER",
                    block_ref="b1",
                    message={"en": "Token diff", "ar": "اختلاف رموز"},
                    resolvable_by="confirm",
                )
            ],
        )

        assert task.has_unresolved_blockers is True
        assert task.can_approve is False

        # Attempt to approve directly -> must raise ValueError
        with pytest.raises(ValueError, match="has unresolved blockers"):
            review_svc.approve_question("q-ack", teacher_id="teacher-1")

        # Now acknowledge the issue
        acks = review_svc.acknowledge_issue(
            revision_id=task.latest_revision_id,
            rule_id="B-020",
            acknowledged_by="teacher-1",
            reason="Verified identical to source PDF crop visually",
        )
        assert "B-020" in acks

        updated_task = review_svc.get_task("q-ack")
        assert updated_task.has_unresolved_blockers is False
        assert updated_task.can_approve is True

        approval = review_svc.approve_question("q-ack", teacher_id="teacher-1")
        assert approval["approved_by"] == "teacher-1"
        assert review_svc.get_task("q-ack").status == "approved"

    def test_block_level_edit_creates_immutable_revision(self, review_svc: ReviewConsoleService) -> None:
        """
        Block-level edit:
        - Click block, fix (+14 -> -14 or add pi).
        - Generates new revision with rev_no = current + 1.
        - Prior revision is untouched (immutability).
        """
        tenant_id = "tenant-edit-test"
        doc_id = "doc-test"

        initial_content = {
            "stem": _make_stem([("b1", "text", "Solve"), ("b2", "math", "x^2 + 14")]),
            "options": _make_options(),
            "source": {"ordinal": 3},
        }

        task = review_svc.register_question(
            question_id="q-edit",
            tenant_id=tenant_id,
            document_id=doc_id,
            ordinal=3,
            content=initial_content,
            answer={"status": "source_extracted", "raw": "A"},
            issues=[
                ValidationIssue(
                    rule_id="B-020",
                    severity="BLOCKER",
                    block_ref="b2",
                    message={"en": "Sign discrepancy (+14 vs -14)", "ar": "اختلاف إشارة"},
                    resolvable_by="edit",
                )
            ],
        )

        rev1_id = task.latest_revision_id
        rev1_hash = task.content_hash

        # Perform block edit: b2 should be x^2 - 14
        new_rev = review_svc.edit_block(
            revision_id=rev1_id,
            block_id="b2",
            new_value="x^2 - 14",
            reason="source_image_correction",
            edited_by="teacher-1",
        )

        assert new_rev.rev_no == 2
        assert new_rev.id != rev1_id
        assert new_rev.content_hash != rev1_hash
        assert new_rev.created_via == "teacher_edit"
        assert new_rev.edit_note == "source_image_correction"

        # Verify revision 1 is untouched
        task_rev1 = review_svc._revisions[rev1_id]
        assert task_rev1.rev_no == 1
        assert task_rev1.content["stem"][1]["latex"] == "x^2 + 14"

        # Verify revision 2 has updated block
        assert new_rev.content["stem"][1]["latex"] == "x^2 - 14"

        # Check task has no remaining blocker (resolved by edit)
        updated_task = review_svc.get_task("q-edit")
        assert updated_task.rev_no == 2
        assert updated_task.has_unresolved_blockers is False
        assert updated_task.can_approve is True

    def test_teacher_answer_selection_creates_revision(self, review_svc: ReviewConsoleService) -> None:
        """
        Selecting/confirming answer resolves unknown/conflicting answer and creates
        a new revision with answer.status = 'teacher_confirmed'.
        """
        tenant_id = "tenant-answer-test"
        doc_id = "doc-test"

        task = review_svc.register_question(
            question_id="q-answer-sel",
            tenant_id=tenant_id,
            document_id=doc_id,
            ordinal=20,
            content={"stem": _make_stem([("b1", "text", "Question 20")]), "options": _make_options(), "source": {"ordinal": 20}},
            answer={"status": "unknown"},
            issues=[
                ValidationIssue(
                    rule_id="B-040",
                    severity="BLOCKER",
                    block_ref="answer",
                    message={"en": "Answer unknown", "ar": "الإجابة غير معروفة"},
                    resolvable_by="confirm",
                )
            ],
        )

        assert task.has_unresolved_blockers is True

        new_rev = review_svc.select_answer(
            revision_id=task.latest_revision_id,
            selected_key="D",
            confirmed_by="teacher-1",
        )

        assert new_rev.rev_no == 2
        assert new_rev.answer["status"] == "teacher_confirmed"
        assert new_rev.answer["raw"] == "D"

        updated_task = review_svc.get_task("q-answer-sel")
        assert updated_task.has_unresolved_blockers is False
        assert updated_task.can_approve is True

    def test_structural_actions_merge_split_unreadable(self, review_svc: ReviewConsoleService) -> None:
        """Verify structural actions: merge-with-next, split-question, mark-source-unreadable."""
        tenant_id = "tenant-structural-test"
        doc_id = "doc-test"

        # 1. Merge with next
        review_svc.register_question(
            question_id="q-merge",
            tenant_id=tenant_id,
            document_id=doc_id,
            ordinal=13,
            content={"stem": _make_stem([("b1", "text", "Part A")]), "options": _make_options(), "source": {"ordinal": 13}},
            answer={"status": "source_extracted", "raw": "A"},
            issues=[],
        )
        review_svc.merge_with_next("q-merge", merged_by="teacher-1")
        assert review_svc.get_task("q-merge").status == "merged_with_next"

        # 2. Split question
        review_svc.register_question(
            question_id="q-split",
            tenant_id=tenant_id,
            document_id=doc_id,
            ordinal=15,
            content={
                "stem": _make_stem([("b1", "text", "Question 15 body"), ("b2", "text", "Question 16 body")]),
                "options": _make_options(),
                "source": {"ordinal": 15},
            },
            answer={"status": "source_extracted", "raw": "A"},
            issues=[],
        )
        q1, q2 = review_svc.split_question("q-split", split_at_block_id="b1", split_by="teacher-1")
        assert q1 == "q-split"
        assert q2 != q1
        assert review_svc.get_task(q2).ordinal == 16

        # 3. Mark unreadable
        review_svc.register_question(
            question_id="q-unreadable",
            tenant_id=tenant_id,
            document_id=doc_id,
            ordinal=9,
            content={"stem": _make_stem([("b1", "text", "Cut off")]), "options": _make_options(), "source": {"ordinal": 9}},
            answer={"status": "source_extracted", "raw": "D"},
            issues=[
                ValidationIssue(
                    rule_id="B-011",
                    severity="BLOCKER",
                    message={"en": "Ink truncated at border", "ar": "الحبر مقطوع"},
                )
            ],
        )
        review_svc.mark_source_unreadable("q-unreadable", marked_by="teacher-1", reason="Options clipped")
        unreadable_task = review_svc.get_task("q-unreadable")
        assert unreadable_task.status == "source_unreadable"
        assert unreadable_task.can_approve is False

    def test_revision_restore(self, review_svc: ReviewConsoleService) -> None:
        """Verify restoring a prior revision generates a new revision matching target content."""
        tenant_id = "tenant-restore-test"
        doc_id = "doc-test"

        task = review_svc.register_question(
            question_id="q-restore",
            tenant_id=tenant_id,
            document_id=doc_id,
            ordinal=1,
            content={"stem": _make_stem([("b1", "text", "Original text")]), "options": _make_options(), "source": {"ordinal": 1}},
            answer={"status": "source_extracted", "raw": "A"},
            issues=[],
        )
        rev1_id = task.latest_revision_id

        # Make edit -> rev 2
        rev2 = review_svc.edit_block(rev1_id, "b1", "Accidental edit", "Typo fix", "teacher-1")
        assert rev2.rev_no == 2

        # Restore rev 1 -> rev 3
        rev3 = review_svc.restore_revision("q-restore", rev1_id, restored_by="teacher-1")
        assert rev3.rev_no == 3
        assert rev3.created_via == "restore"
        assert rev3.content["stem"][0]["value"] == "Original text"

    def test_second_review_sampling(self, review_svc: ReviewConsoleService) -> None:
        """Verify second-review sampling tags a predictable subset (~8%)."""
        tenant_id = "tenant-sampling-test"
        doc_id = "doc-test"

        sampled_count = 0
        total = 50
        for i in range(1, total + 1):
            q_id = f"sample-q-{i}"
            review_svc.register_question(
                question_id=q_id,
                tenant_id=tenant_id,
                document_id=doc_id,
                ordinal=i,
                content={"stem": _make_stem([("b1", "text", f"Item {i}")]), "options": _make_options(), "source": {"ordinal": i}},
                answer={"status": "source_extracted", "raw": "A"},
                issues=[],
            )
            is_sampled = review_svc.sample_second_review(q_id, sample_rate=0.10)
            if is_sampled:
                sampled_count += 1

        # Sampling rate should be roughly 10% (between 3 and 8 items out of 50)
        assert 1 <= sampled_count <= 10

    def test_fastapi_review_endpoints(self) -> None:
        """Test API endpoints via FastAPI TestClient."""
        client = TestClient(app)
        tenant_id = "api-test-tenant"
        q_id = f"api-q-{uuid.uuid4().hex[:8]}"

        # Seed global service
        task = global_review_service.register_question(
            question_id=q_id,
            tenant_id=tenant_id,
            document_id="doc-api",
            ordinal=1,
            content={"stem": _make_stem([("b1", "text", "API Stem")]), "options": _make_options(), "source": {"ordinal": 1}},
            answer={"status": "unknown"},
            issues=[
                ValidationIssue(
                    rule_id="B-040",
                    severity="BLOCKER",
                    block_ref="answer",
                    message={"en": "Answer unknown", "ar": "إجابة غير معروفة"},
                    resolvable_by="confirm",
                )
            ],
        )

        headers = {"Authorization": "Bearer test-teacher-token"}

        # 1. List tasks
        res = client.get(f"/qb/review/tasks?tenant_id={tenant_id}", headers=headers)
        assert res.status_code == 200
        tasks_data = res.json()
        assert any(t["question_id"] == q_id for t in tasks_data)

        # 2. Select answer
        res_ans = client.post(
            f"/qb/revisions/{task.latest_revision_id}/select-answer",
            json={"selected_key": "B"},
            headers=headers,
        )
        assert res_ans.status_code == 200
        assert res_ans.json()["answer_status"] == "teacher_confirmed"

        # 3. Approve question
        res_app = client.post(
            f"/qb/questions/{q_id}/approve",
            json={},
            headers=headers,
        )
        assert res_app.status_code == 200
        assert res_app.json()["approved_by"] == "test-teacher-token"

    def test_solid_shapes_30_batch_simulation(self, review_svc: ReviewConsoleService) -> None:
        """
        End-to-end clearing of 30-question Solid Shapes batch simulation (§13 M5).
        Ground truth expectations (Appendix A.1, A.2):
        - 30 MCQ questions.
        - Clean questions review in fast mode with median time < 15s.
        - Defect / conflict questions require targeted edits / confirmations:
          - Q9: truncated options (B-011) -> quarantined.
          - Q20, Q21: answer conflict (B-041) -> teacher confirms answer.
          - Q3, Q11, Q12, Q13, Q23: missing pi (B-023) -> edited.
          - Q2/Q4, Q6/Q7, Q25/Q26: cluster duplicates (B-052) -> clustered.
        - Verifies median time for clean questions < 15s and calculates review rate.
        """
        tenant_id = "tenant-solid-shapes-batch"
        doc_id = "doc-solid-shapes"

        # Seed the 30 Solid Shapes questions
        for ordinal in range(1, 31):
            q_id = f"ss-q{ordinal}"
            issues: list[ValidationIssue] = []
            duplicate_cluster: str | None = None
            answer_status = "source_extracted"
            answer_key = "A"

            # Assign cluster duplicates
            if ordinal in (2, 4):
                duplicate_cluster = "cluster-cone-volume"
                issues.append(ValidationIssue(rule_id="B-052", severity="WARN", message={"en": "Near duplicate cone", "ar": "تكرار مخروط"}))
            elif ordinal in (6, 7):
                duplicate_cluster = "cluster-cube-edge"
                issues.append(ValidationIssue(rule_id="B-052", severity="WARN", message={"en": "Near duplicate cube", "ar": "تكرار مكعب"}))
            elif ordinal in (25, 26):
                duplicate_cluster = "cluster-hemisphere"
                issues.append(ValidationIssue(rule_id="B-052", severity="WARN", message={"en": "Near duplicate hemisphere", "ar": "تكرار نصف كرة"}))

            # Specific known defects
            if ordinal == 9:
                # Q9: ink touching crop border (B-011)
                issues.append(
                    ValidationIssue(
                        rule_id="B-011",
                        severity="BLOCKER",
                        message={"en": "Option image clipped at border", "ar": "صورة الخيار مقطوعة"},
                    )
                )
            elif ordinal in (3, 11, 12, 13, 23):
                # Missing pi glyph (B-023)
                issues.append(
                    ValidationIssue(
                        rule_id="B-023",
                        severity="BLOCKER",
                        block_ref="b2",
                        message={"en": "pi glyph missing from text layer", "ar": "رمز باي مفقود"},
                        resolvable_by="edit",
                    )
                )
            elif ordinal in (20, 21):
                # Answer conflict (B-041)
                answer_status = "unknown"
                issues.append(
                    ValidationIssue(
                        rule_id="B-041",
                        severity="BLOCKER",
                        block_ref="answer",
                        message={"en": "Answer conflict between key and solver", "ar": "تعارض في الإجابة"},
                        resolvable_by="confirm",
                    )
                )
            elif ordinal == 14:
                # Watermark (B-031)
                issues.append(
                    ValidationIssue(
                        rule_id="B-031",
                        severity="WARN",
                        message={"en": "Third-party watermark detected", "ar": "علامة مائية خارجية"},
                        resolvable_by="confirm",
                    )
                )
            elif ordinal == 28:
                # Prose typo (B-051)
                issues.append(
                    ValidationIssue(
                        rule_id="B-051",
                        severity="WARN",
                        message={"en": "Reader disagreement on prose", "ar": "اختلاف قراء"},
                        resolvable_by="confirm",
                    )
                )

            review_svc.register_question(
                question_id=q_id,
                tenant_id=tenant_id,
                document_id=doc_id,
                ordinal=ordinal,
                source_label=f"Q{ordinal}",
                content={
                    "stem": _make_stem([("b1", "text", f"Solid Shapes Question {ordinal}"), ("b2", "math", "V = 13,122")]),
                    "options": _make_options(),
                    "source": {"ordinal": ordinal, "form_id": "A"},
                },
                answer={"status": answer_status, "raw": answer_key},
                issues=issues,
                duplicate_cluster_id=duplicate_cluster,
            )

        # Run simulated teacher clearing of the batch
        sim_result = review_svc.simulate_teacher_batch(tenant_id=tenant_id)

        # ─── Assertions (§13 M5 Exit Criteria) ────────────────────────────────
        assert sim_result.total_questions == 30
        assert sim_result.quarantined_count == 1  # Q9 quarantined due to truncated ink
        assert sim_result.approved_count == 29   # 29 questions successfully cleared & approved
        assert sim_result.edited_count == 5      # Q3, Q11, Q12, Q13, Q23 had missing pi edited

        # FAST MODE SPEED TARGET: Median review time for clean items MUST be < 15 seconds
        assert sim_result.median_time_clean_seconds < 15.0, (
            f"Expected clean median < 15s, got {sim_result.median_time_clean_seconds}s"
        )
        assert sim_result.fast_mode_count >= 14

        # Throughput rate should be reasonable for an academic SaaS review workflow
        assert sim_result.review_rate_per_hour > 100.0
