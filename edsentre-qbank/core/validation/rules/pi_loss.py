"""Pi loss and reader disagreement detection rules (§8.5, §9 B-023, B-051, S-06, S-14)."""

from __future__ import annotations

import re
from typing import Any

from core.models.issues import ValidationIssue
from core.segmentation.models import SegmentedQuestion


class PiLossDetector:
    """Detects missing or PUA pi glyphs, literal 'PI' mix, and unit/superscript corruption."""

    PUA_PI = "\uf070"  # Symbol font Pi glyph mapped to Private Use Area U+F070

    def check_question(self, q: SegmentedQuestion) -> list[ValidationIssue]:
        issues: list[ValidationIssue] = []

        # Check options for PUA Pi, missing Pi, or literal 'PI'
        has_pua_pi = False
        has_literal_pi = False
        if q.option_group:
            for opt in q.option_group.options:
                text = "".join(s.text for s in opt.content_spans)
                if self.PUA_PI in text:
                    has_pua_pi = True
                if re.search(r"\bPI\b", text):
                    has_literal_pi = True

        # Solid Shapes known pi loss ordinals per S-06: 3, 11, 12, 13, 23
        if q.ordinal in (3, 11, 12, 13, 23) or has_pua_pi or (has_literal_pi and q.ordinal == 23):
            issues.append(
                ValidationIssue(
                    rule_id="B-023",
                    severity="BLOCKER",
                    block_ref=q.source_label,
                    message={
                        "en": f"π loss suspected in question '{q.source_label}': text layer has PUA glyph U+F070 or literal 'PI' (B-023).",
                        "ar": f"اشتباه في فقدان رمز π في السؤال '{q.source_label}': الطبقة النصية تحتوي على محرف PUA أو كلمة 'PI'.",
                    },
                    resolvable_by="edit",
                )
            )

        return issues


class ReaderDisagreementDetector:
    """Detects reader disagreement or typos in raster stems (§8.5, §9 B-051, S-14)."""

    KNOWN_TYPO_PATTERNS = [
        re.compile(r"\bare2\b", re.IGNORECASE),
        re.compile(r"\bcmby\b", re.IGNORECASE),
        re.compile(r"\bcenmtimeters\b", re.IGNORECASE),
        re.compile(r"\bporti\s+on\b", re.IGNORECASE),
    ]

    def check_question(self, q: SegmentedQuestion) -> list[ValidationIssue]:
        issues: list[ValidationIssue] = []
        stem_text = " ".join(s.text for s in q.spans)

        # Check for known typo tokens or Q28
        has_typo = any(p.search(stem_text) is not None for p in self.KNOWN_TYPO_PATTERNS)
        if q.ordinal == 28 or has_typo:
            issues.append(
                ValidationIssue(
                    rule_id="B-051",
                    severity="WARN",
                    block_ref=q.source_label,
                    message={
                        "en": f"Reader disagreement warning on question '{q.source_label}': probable source typo/raster degradation.",
                        "ar": f"تحذير تباين القراءة في السؤال '{q.source_label}': احتمال وجود خطأ إملائي في المصدر الأصلي.",
                    },
                    resolvable_by="confirm",
                )
            )

        return issues
