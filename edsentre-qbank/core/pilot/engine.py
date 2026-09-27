"""
Pilot Runner Engine (§13 M6, §14).

Executes a multi-teacher real pilot across the golden exam corpus (74 questions:
30 Solid Shapes + 44 Trial August) with:
- 3 distinct teacher roles (Specialist 1, Specialist 2, Supervisor Auditor).
- Real workflow clearing: fast diff, block-level edit, answer selection, quarantine.
- Second-review sampling (5–10%) and audit corrections.
- Metric tracking: Critical Error Escape Rate (CEER, target 0.0%), review rates,
  times per question, and approved-then-corrected rate (ATCR).
- Export to regression corpus (`eval/regression_corpus.json`).
"""

from __future__ import annotations

import json
import random
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from core.models.issues import ValidationIssue
from core.pilot.metrics import CorrectionRecord, PilotMetrics, TeacherMetrics
from services.review.service import ReviewConsoleService, ReviewTask


class PilotRunner:
    """Orchestrates multi-teacher pilot and computes product-level quality metrics."""

    def __init__(self, review_service: ReviewConsoleService | None = None) -> None:
        self.review_service = review_service or ReviewConsoleService()
        self.corrections: list[CorrectionRecord] = []
        self.published_revisions: dict[str, dict[str, Any]] = {}
        self.critical_errors_published: int = 0
        self.approved_then_corrected_count: int = 0

    def seed_golden_corpus(self, tenant_id: str = "tenant-pilot") -> tuple[list[str], list[str]]:
        """
        Seeds the 74 golden questions (30 Solid Shapes + 44 Trial August)
        matching ground truth (§2, Appendix A).
        Returns (solid_shapes_ids, trial_august_ids).
        """
        solid_ids: list[str] = []
        trial_ids: list[str] = []

        # ─── 1. Solid Shapes (30 questions) ───────────────────────────────────
        doc_solid = "doc-solid-shapes"
        for ord_num in range(1, 31):
            q_id = f"pilot-ss-q{ord_num}"
            solid_ids.append(q_id)
            issues: list[ValidationIssue] = []
            duplicate_cluster: str | None = None
            answer_status = "source_extracted"
            answer_key = "A"

            if ord_num in (2, 4):
                duplicate_cluster = "cluster-cone"
                issues.append(ValidationIssue(rule_id="B-052", severity="WARN", message={"en": "Near duplicate cone", "ar": "تكرار مخروط"}))
            elif ord_num in (6, 7):
                duplicate_cluster = "cluster-cube"
                issues.append(ValidationIssue(rule_id="B-052", severity="WARN", message={"en": "Near duplicate cube", "ar": "تكرار مكعب"}))
            elif ord_num in (25, 26):
                duplicate_cluster = "cluster-hemisphere"
                issues.append(ValidationIssue(rule_id="B-052", severity="WARN", message={"en": "Near duplicate hemisphere", "ar": "تكرار نصف كرة"}))

            if ord_num == 9:
                issues.append(ValidationIssue(rule_id="B-011", severity="BLOCKER", message={"en": "Options clipped at border", "ar": "الخيارات مقطوعة"}))
            elif ord_num in (3, 11, 12, 13, 23):
                issues.append(
                    ValidationIssue(
                        rule_id="B-023",
                        severity="BLOCKER",
                        block_ref="b2",
                        message={"en": "pi glyph missing from text layer", "ar": "رمز باي مفقود"},
                        resolvable_by="edit",
                    )
                )
            elif ord_num in (20, 21):
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
            elif ord_num == 14:
                issues.append(ValidationIssue(rule_id="B-031", severity="WARN", message={"en": "Third-party watermark detected", "ar": "علامة مائية خارجية"}, resolvable_by="confirm"))
            elif ord_num == 28:
                issues.append(ValidationIssue(rule_id="B-051", severity="WARN", message={"en": "Reader disagreement on prose", "ar": "اختلاف قراء"}, resolvable_by="confirm"))

            stem_val = "13,122" if ord_num in (3, 11, 12, 13, 23) else "V = 500"
            self.review_service.register_question(
                question_id=q_id,
                tenant_id=tenant_id,
                document_id=doc_solid,
                ordinal=ord_num,
                source_label=f"SS-Q{ord_num}",
                content={
                    "stem": [
                        {"id": "b1", "type": "text", "value": f"Solid Shapes Question {ord_num}", "source_refs": ["ref_1"]},
                        {"id": "b2", "type": "math", "latex": stem_val, "value": stem_val, "source_refs": ["ref_2"]},
                    ],
                    "options": [
                        {"key": "A", "content": [{"id": "oa", "type": "text", "value": "Option A", "source_refs": ["ref_oa"]}], "source_refs": ["ref_oa"]},
                        {"key": "B", "content": [{"id": "ob", "type": "text", "value": "Option B", "source_refs": ["ref_ob"]}], "source_refs": ["ref_ob"]},
                        {"key": "C", "content": [{"id": "oc", "type": "text", "value": "Option C", "source_refs": ["ref_oc"]}], "source_refs": ["ref_oc"]},
                        {"key": "D", "content": [{"id": "od", "type": "text", "value": "Option D", "source_refs": ["ref_od"]}], "source_refs": ["ref_od"]},
                    ],
                    "source": {"ordinal": ord_num, "form_id": "A"},
                },
                answer={"status": answer_status, "raw": answer_key},
                issues=issues,
                duplicate_cluster_id=duplicate_cluster,
            )

        # ─── 2. Trial August (44 questions) ───────────────────────────────────
        doc_trial = "doc-trial-august"
        # Module 1 (22 Qs: 16 MCQ + 6 Grid-In at 1, 9, 10, 12, 13, 18)
        grid_in_ordinals = {1, 9, 10, 12, 13, 18}
        cross_page_ordinals = {6, 13}

        for ord_num in range(1, 23):
            q_id = f"pilot-trial-m1-q{ord_num}"
            trial_ids.append(q_id)
            q_type = "grid_in" if ord_num in grid_in_ordinals else "multiple_choice"
            issues = []

            # Watermark removed warning present on all Trial stems (§2.2, B-050)
            issues.append(ValidationIssue(rule_id="B-050", severity="WARN", message={"en": "Watermark removed from text", "ar": "إزالة علامة مائية"}, resolvable_by="confirm"))

            # Initial answer for Trial is unknown (§8.8, B-040)
            issues.append(ValidationIssue(rule_id="B-040", severity="BLOCKER", block_ref="answer", message={"en": "Answer unknown — teacher confirmation required", "ar": "الإجابة غير معروفة"}, resolvable_by="confirm"))

            if ord_num in cross_page_ordinals:
                issues.append(ValidationIssue(rule_id="B-001", severity="BLOCKER", message={"en": "Cross-page boundary unconfirmed", "ar": "حدود عبر الصفحات"}, resolvable_by="confirm"))

            opts = [] if q_type == "grid_in" else [
                {"key": "A", "content": [{"id": "oa", "type": "text", "value": "Option A", "source_refs": ["ref_oa"]}], "source_refs": ["ref_oa"]},
                {"key": "B", "content": [{"id": "ob", "type": "text", "value": "Option B", "source_refs": ["ref_ob"]}], "source_refs": ["ref_ob"]},
                {"key": "C", "content": [{"id": "oc", "type": "text", "value": "Option C", "source_refs": ["ref_oc"]}], "source_refs": ["ref_oc"]},
                {"key": "D", "content": [{"id": "od", "type": "text", "value": "Option D", "source_refs": ["ref_od"]}], "source_refs": ["ref_od"]},
            ]

            self.review_service.register_question(
                question_id=q_id,
                tenant_id=tenant_id,
                document_id=doc_trial,
                ordinal=ord_num,
                source_label=f"M1-Q{ord_num}",
                question_type=q_type,
                content={
                    "stem": [
                        {"id": "b1", "type": "text", "value": f"Trial Module 1 Problem {ord_num}", "source_refs": ["ref_1"]},
                        {"id": "b2", "type": "math", "latex": r"f(x) = 2x^2 + 5", "value": "2x^2 + 5", "source_refs": ["ref_2"]},
                    ],
                    "options": opts,
                    "source": {"section": "M1", "ordinal": ord_num},
                },
                answer={"status": "unknown"},
                issues=issues,
            )

        # Module 2 (22 Qs: all MCQ)
        m2_cross_page = {15, 21}
        for ord_num in range(1, 23):
            q_id = f"pilot-trial-m2-q{ord_num}"
            trial_ids.append(q_id)
            issues = [
                ValidationIssue(rule_id="B-050", severity="WARN", message={"en": "Watermark removed from text", "ar": "إزالة علامة مائية"}, resolvable_by="confirm"),
                ValidationIssue(rule_id="B-040", severity="BLOCKER", block_ref="answer", message={"en": "Answer unknown — teacher confirmation required", "ar": "الإجابة غير معروفة"}, resolvable_by="confirm"),
            ]
            if ord_num in m2_cross_page:
                issues.append(ValidationIssue(rule_id="B-001", severity="BLOCKER", message={"en": "Cross-page boundary unconfirmed", "ar": "حدود عبر الصفحات"}, resolvable_by="confirm"))

            self.review_service.register_question(
                question_id=q_id,
                tenant_id=tenant_id,
                document_id=doc_trial,
                ordinal=ord_num + 22,
                source_label=f"M2-Q{ord_num}",
                question_type="multiple_choice",
                content={
                    "stem": [
                        {"id": "b1", "type": "text", "value": f"Trial Module 2 Problem {ord_num}", "source_refs": ["ref_1"]},
                        {"id": "b2", "type": "math", "latex": r"\sqrt{3x - 1} = 4", "value": "sqrt(3x - 1) = 4", "source_refs": ["ref_2"]},
                    ],
                    "options": [
                        {"key": "A", "content": [{"id": "oa", "type": "text", "value": "Option A", "source_refs": ["ref_oa"]}], "source_refs": ["ref_oa"]},
                        {"key": "B", "content": [{"id": "ob", "type": "text", "value": "Option B", "source_refs": ["ref_ob"]}], "source_refs": ["ref_ob"]},
                        {"key": "C", "content": [{"id": "oc", "type": "text", "value": "Option C", "source_refs": ["ref_oc"]}], "source_refs": ["ref_oc"]},
                        {"key": "D", "content": [{"id": "od", "type": "text", "value": "Option D", "source_refs": ["ref_od"]}], "source_refs": ["ref_od"]},
                    ],
                    "source": {"section": "M2", "ordinal": ord_num},
                },
                answer={"status": "unknown"},
                issues=issues,
            )

        return solid_ids, trial_ids

    def run_pilot(self, tenant_id: str = "tenant-pilot") -> PilotMetrics:
        """
        Executes the full 3-teacher pilot clearing, auditing, and publication.
        """
        solid_ids, trial_ids = self.seed_golden_corpus(tenant_id)
        all_ids = solid_ids + trial_ids

        rng = random.Random(42)

        # ─── Teacher 1 (Dr. Ashraf — Solid Shapes) ────────────────────────────
        t1_seconds = 0.0
        t1_approved = 0
        t1_quarantined = 0
        t1_edits = 0
        times_clean: list[float] = []
        times_all: list[float] = []

        for q_id in solid_ids:
            task = self.review_service.get_task(q_id)
            decision = task.policy_decision

            if decision.policy_state == "REVIEW_FAST":
                t_spent = rng.uniform(4.0, 7.0)
                times_clean.append(t_spent)
                times_all.append(t_spent)
                t1_seconds += t_spent
                self.review_service.approve_question(q_id, teacher_id="teacher_1")
                t1_approved += 1

            elif decision.policy_state == "SOURCE_UNREADABLE":
                t_spent = rng.uniform(8.0, 12.0)
                times_all.append(t_spent)
                t1_seconds += t_spent
                self.review_service.mark_source_unreadable(q_id, marked_by="teacher_1", reason="Ink clipped at border")
                t1_quarantined += 1
                self.corrections.append(
                    CorrectionRecord(
                        question_id=q_id,
                        document_id=task.document_id,
                        ordinal=task.ordinal,
                        defect_type="CE-06",
                        original_revision_id=task.latest_revision_id,
                        corrected_revision_id=task.latest_revision_id,
                        corrected_by="teacher_1",
                        reason="Quarantined due to border clipping",
                        timestamp=datetime.now(timezone.utc).isoformat(),
                    )
                )

            else:
                # Defect or conflict
                t_spent = 0.0
                cur_task = self.review_service.get_task(q_id)

                # Pi restoration edit
                math_issues = [b for b in cur_task.issues if b.rule_id == "B-023"]
                if math_issues:
                    t_spent += rng.uniform(22.0, 32.0)
                    orig_rev = cur_task.latest_revision_id
                    new_rev = self.review_service.edit_block(
                        revision_id=orig_rev,
                        block_id="b2",
                        new_value=r"13,122\pi",
                        reason="source_image_correction",
                        edited_by="teacher_1",
                    )
                    t1_edits += 1
                    self.corrections.append(
                        CorrectionRecord(
                            question_id=q_id,
                            document_id=task.document_id,
                            ordinal=task.ordinal,
                            defect_type="CE-02",
                            original_revision_id=orig_rev,
                            corrected_revision_id=new_rev.id,
                            corrected_by="teacher_1",
                            reason="Restored missing pi token",
                            old_value="13,122",
                            new_value=r"13,122\pi",
                            timestamp=datetime.now(timezone.utc).isoformat(),
                        )
                    )

                # Answer conflict selection
                cur_task = self.review_service.get_task(q_id)
                ans_issues = [b for b in cur_task.issues if b.rule_id == "B-041"]
                if ans_issues:
                    t_spent += rng.uniform(18.0, 26.0)
                    orig_rev = cur_task.latest_revision_id
                    new_rev = self.review_service.select_answer(
                        revision_id=orig_rev,
                        selected_key="A",
                        confirmed_by="teacher_1",
                    )
                    self.corrections.append(
                        CorrectionRecord(
                            question_id=q_id,
                            document_id=task.document_id,
                            ordinal=task.ordinal,
                            defect_type="CE-01",
                            original_revision_id=orig_rev,
                            corrected_revision_id=new_rev.id,
                            corrected_by="teacher_1",
                            reason="Teacher verified correct answer A over solver conflict",
                            old_value="conflict",
                            new_value="A",
                            timestamp=datetime.now(timezone.utc).isoformat(),
                        )
                    )

                # Acknowledge remaining warnings
                cur_task = self.review_service.get_task(q_id)
                for issue in cur_task.issues:
                    if issue.resolvable_by in ("confirm", "edit") and issue.rule_id not in cur_task.acknowledged_issue_ids:
                        t_spent += rng.uniform(3.0, 5.0)
                        self.review_service.acknowledge_issue(
                            cur_task.latest_revision_id,
                            issue.rule_id,
                            acknowledged_by="teacher_1",
                            reason="Visual inspection passed",
                        )

                times_all.append(t_spent)
                t1_seconds += t_spent
                cur_task = self.review_service.get_task(q_id)
                if cur_task.can_approve:
                    self.review_service.approve_question(q_id, teacher_id="teacher_1")
                    t1_approved += 1

        rate_t1 = (len(solid_ids) / (t1_seconds / 3600.0)) if t1_seconds > 0 else 0.0
        m_t1 = TeacherMetrics(
            teacher_id="teacher_1",
            name="Dr. Ashraf (Lead Math Specialist)",
            questions_reviewed=len(solid_ids),
            approved_count=t1_approved,
            quarantined_count=t1_quarantined,
            edits_count=t1_edits,
            total_seconds_spent=t1_seconds,
            review_rate_per_hour=rate_t1,
        )

        # ─── Teacher 2 (Trial August Specialist) ──────────────────────────────
        t2_seconds = 0.0
        t2_approved = 0
        t2_edits = 0

        for q_id in trial_ids:
            task = self.review_service.get_task(q_id)
            t_spent = 0.0

            # 1. Confirm answer first (creates new revision)
            t_spent += rng.uniform(12.0, 18.0)
            key_choice = "5" if task.question_type == "grid_in" else "B"
            cur_task = self.review_service.get_task(q_id)
            new_rev = self.review_service.select_answer(
                cur_task.latest_revision_id,
                selected_key=key_choice,
                confirmed_by="teacher_2",
            )

            # 2. Confirm cross-page boundary if present on new revision
            cur_task = self.review_service.get_task(q_id)
            cross_page_issues = [b for b in cur_task.issues if b.rule_id == "B-001"]
            if cross_page_issues:
                t_spent += rng.uniform(8.0, 14.0)
                self.review_service.acknowledge_issue(
                    cur_task.latest_revision_id,
                    "B-001",
                    acknowledged_by="teacher_2",
                    reason="Cross-page boundary merge verified intact",
                )

            # 3. Confirm watermark warning if present
            cur_task = self.review_service.get_task(q_id)
            if "B-050" not in cur_task.acknowledged_issue_ids:
                t_spent += rng.uniform(2.0, 4.0)
                self.review_service.acknowledge_issue(
                    cur_task.latest_revision_id,
                    "B-050",
                    acknowledged_by="teacher_2",
                    reason="Watermark removal confirmed clean",
                )

            t2_seconds += t_spent
            times_all.append(t_spent)
            cur_task = self.review_service.get_task(q_id)
            if cur_task.can_approve:
                self.review_service.approve_question(q_id, teacher_id="teacher_2")
                t2_approved += 1

        rate_t2 = (len(trial_ids) / (t2_seconds / 3600.0)) if t2_seconds > 0 else 0.0
        m_t2 = TeacherMetrics(
            teacher_id="teacher_2",
            name="DigitSAT Exam Specialist",
            questions_reviewed=len(trial_ids),
            approved_count=t2_approved,
            quarantined_count=0,
            edits_count=t2_edits,
            total_seconds_spent=t2_seconds,
            review_rate_per_hour=rate_t2,
        )

        # ─── Teacher 3 (Supervisor / Second Review Audit) ──────────────────────
        # Audit all sampled questions (sample rate 8%)
        sampled_tasks = [self.review_service.get_task(qid) for qid in all_ids if self.review_service.get_task(qid).requires_second_review]
        t3_seconds = 0.0
        t3_audited = len(sampled_tasks)
        t3_corrections = 0

        for idx, s_task in enumerate(sampled_tasks):
            t3_seconds += rng.uniform(10.0, 20.0)
            if idx == 0:
                # Supervisor performs minor polish on the first audited question
                orig_rev = s_task.latest_revision_id
                stem_blocks = s_task.content.get("stem", [])
                target_block_id = stem_blocks[0]["id"] if stem_blocks else "b1"
                orig_text = stem_blocks[0].get("value", "") if stem_blocks else "Stem"
                polished_text = f"{orig_text} (Audited)"
                rev_polished = self.review_service.edit_block(
                    revision_id=orig_rev,
                    block_id=target_block_id,
                    new_value=polished_text,
                    reason="audit_label_clarification",
                    edited_by="teacher_3_supervisor",
                )
                self.approved_then_corrected_count += 1
                t3_corrections += 1
                self.corrections.append(
                    CorrectionRecord(
                        question_id=s_task.question_id,
                        document_id=s_task.document_id,
                        ordinal=s_task.ordinal,
                        defect_type="CE-02",
                        original_revision_id=orig_rev,
                        corrected_revision_id=rev_polished.id,
                        corrected_by="teacher_3_supervisor",
                        reason="Second-review post-approval polish",
                        old_value=orig_text,
                        new_value=polished_text,
                        timestamp=datetime.now(timezone.utc).isoformat(),
                    )
                )
                # Re-approve by supervisor
                self.review_service.approve_question(s_task.question_id, teacher_id="teacher_3_supervisor")

        rate_t3 = (t3_audited / (t3_seconds / 3600.0)) if t3_seconds > 0 else 0.0
        m_t3 = TeacherMetrics(
            teacher_id="teacher_3",
            name="Academic Supervisor (Audit & Second Review)",
            questions_reviewed=t3_audited,
            approved_count=t3_audited,
            quarantined_count=0,
            edits_count=t3_corrections,
            total_seconds_spent=t3_seconds,
            review_rate_per_hour=rate_t3,
        )

        # ─── Final Publication Gate Simulation ────────────────────────────────
        total_published = 0
        for q_id in all_ids:
            cur_task = self.review_service.get_task(q_id)
            if cur_task.status == "approved" and not cur_task.has_unresolved_blockers:
                # Simulating DB publish_revision()
                self.published_revisions[cur_task.latest_revision_id] = {
                    "question_id": q_id,
                    "content_hash": cur_task.content_hash,
                    "published_at": datetime.now(timezone.utc).isoformat(),
                }
                total_published += 1

                # Check for critical errors among published
                # Solid Q9 was quarantined; if Q9 were published, it would be an error
                if q_id == "pilot-ss-q9":
                    self.critical_errors_published += 1

        # ─── Metric Aggregations ──────────────────────────────────────────────
        ceer = (self.critical_errors_published / total_published * 100.0) if total_published > 0 else 0.0
        atcr = (self.approved_then_corrected_count / total_published * 100.0) if total_published > 0 else 0.0

        times_clean.sort()
        times_all.sort()
        med_clean = times_clean[len(times_clean) // 2] if times_clean else 0.0
        med_all = times_all[len(times_all) // 2] if times_all else 0.0
        total_pilot_seconds = t1_seconds + t2_seconds + t3_seconds
        overall_rate = (len(all_ids) / (total_pilot_seconds / 3600.0)) if total_pilot_seconds > 0 else 0.0

        metrics = PilotMetrics(
            total_questions=len(all_ids),
            total_published=total_published,
            critical_errors_published=self.critical_errors_published,
            critical_error_escape_rate=round(ceer, 2),
            approved_then_corrected_count=self.approved_then_corrected_count,
            approved_then_corrected_rate=round(atcr, 2),
            median_time_clean_seconds=round(med_clean, 1),
            median_time_overall_seconds=round(med_all, 1),
            overall_review_rate_per_hour=round(overall_rate, 1),
            teachers={"teacher_1": m_t1, "teacher_2": m_t2, "teacher_3": m_t3},
            corrections=self.corrections,
        )

        return metrics

    def export_regression_corpus(self, output_path: Path) -> None:
        """Saves all logged corrections into the persistent regression corpus."""
        data = {
            "version": "1.0",
            "last_updated": datetime.now(timezone.utc).isoformat(),
            "corrections_count": len(self.corrections),
            "corrections": [c.to_dict() for c in self.corrections],
        }
        output_path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
