"""Document-level validation rules (§9 B-001, B-002, B-003, B-042)."""

from __future__ import annotations

from typing import Any

from core.models.issues import ValidationIssue
from core.segmentation.models import SegmentedQuestion
from core.segmentation.structure import StructureAnalysisResult


class DocumentValidator:
    """Validates entire document structure, question ordinals, counts, and boundary statuses."""

    def validate_document(
        self,
        questions: list[SegmentedQuestion],
        structure: StructureAnalysisResult,
        key_count: int | None = None,
    ) -> list[ValidationIssue]:
        issues: list[ValidationIssue] = []

        # 1. B-001: Boundary status != 'confirmed'
        for q in questions:
            if q.boundary_status != "confirmed":
                issues.append(
                    ValidationIssue(
                        rule_id="B-001",
                        severity="BLOCKER",
                        block_ref=q.source_label,
                        message={
                            "en": f"Boundary status for '{q.source_label}' is '{q.boundary_status}', not 'confirmed'.",
                            "ar": f"حدود السؤال '{q.source_label}' غير مؤكدة.",
                        },
                        resolvable_by="confirm",
                    )
                )

        # 2. B-002: Question left open at EOF / section end
        # Checked if any question has unresolved continuation or empty elements
        for q in questions:
            if not q.spans and not q.images:
                issues.append(
                    ValidationIssue(
                        rule_id="B-002",
                        severity="BLOCKER",
                        block_ref=q.source_label,
                        message={
                            "en": f"Question '{q.source_label}' is empty or was left unclosed at EOF.",
                            "ar": f"السؤال '{q.source_label}' فارغ أو لم يتم إغلاقه عند نهاية المستند.",
                        },
                        resolvable_by="edit",
                    )
                )

        # 3. B-003: Ordinal gap/repeat inside section, or count != expected
        questions_by_section: dict[str, list[SegmentedQuestion]] = {}
        for q in questions:
            questions_by_section.setdefault(q.section, []).append(q)

        for sec in structure.sections:
            sec_qs = questions_by_section.get(sec.name, [])
            ordinals = [q.ordinal for q in sec_qs]

            # Check repeats
            if len(ordinals) != len(set(ordinals)):
                issues.append(
                    ValidationIssue(
                        rule_id="B-003",
                        severity="BLOCKER",
                        block_ref=sec.name,
                        message={
                            "en": f"Repeated ordinals found in section '{sec.name}': {ordinals}",
                            "ar": f"تكرار في أرقام الأسئلة داخل القسم '{sec.name}'.",
                        },
                        resolvable_by="edit",
                    )
                )

            # Check contiguous 1..N
            if ordinals:
                expected_seq = list(range(1, len(ordinals) + 1))
                if sorted(ordinals) != expected_seq:
                    issues.append(
                        ValidationIssue(
                            rule_id="B-003",
                            severity="BLOCKER",
                            block_ref=sec.name,
                            message={
                                "en": f"Ordinal gap in section '{sec.name}': expected 1..{len(ordinals)}, got {sorted(ordinals)}",
                                "ar": f"فجوة في تسلسل أرقام الأسئلة داخل القسم '{sec.name}'.",
                            },
                            resolvable_by="edit",
                        )
                    )

            # Check expected count if declared
            if sec.expected_count is not None and len(sec_qs) != sec.expected_count:
                issues.append(
                    ValidationIssue(
                        rule_id="B-003",
                        severity="BLOCKER",
                        block_ref=sec.name,
                        message={
                            "en": f"Section '{sec.name}' has {len(sec_qs)} questions, expected {sec.expected_count}.",
                            "ar": f"عدد الأسئلة في القسم '{sec.name}' ({len(sec_qs)}) لا يطابق المتوقع ({sec.expected_count}).",
                        },
                        resolvable_by="edit",
                    )
                )

        # 4. B-042: Key page count != question count
        if key_count is not None and key_count != len(questions):
            issues.append(
                ValidationIssue(
                    rule_id="B-042",
                    severity="BLOCKER",
                    block_ref="answer_key",
                    message={
                        "en": f"Answer key has {key_count} entries, but {len(questions)} questions found.",
                        "ar": f"عدد إجابات مفتاح الحل ({key_count}) لا يطابق عدد الأسئلة ({len(questions)}).",
                    },
                    resolvable_by="edit",
                )
            )

        return issues
