"""Figure reference and asset binding validation (§8.7, §9 B-030)."""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any

from core.models.block import Block
from core.models.issues import ValidationIssue


class FigureReferenceValidator:
    """Validates that stem references to figures, graphs, or tables have bound visual assets."""

    FIGURE_REF_PATTERNS = [
        re.compile(r"\b(?:the\s+)?(?:figure|diagram|graph|table|scatterplot|histogram)\s*(?:shown|above|below)?\b", re.IGNORECASE),
        re.compile(r"\bshown\s+in\s+the\s+(?:figure|diagram|table|graph)\b", re.IGNORECASE),
        re.compile(r"\baccording\s+to\s+the\s+(?:table|graph|data|figure)\b", re.IGNORECASE),
    ]

    def has_figure_reference(self, stem_text: str) -> bool:
        """Returns True if the stem text refers to a figure, diagram, table, or graph."""
        return any(p.search(stem_text) is not None for p in self.FIGURE_REF_PATTERNS)

    def validate(self, stem_blocks: list[Block]) -> list[ValidationIssue]:
        """Checks if a stem referring to a visual asset actually has an asset bound."""
        text_content = " ".join(b.value or "" for b in stem_blocks if b.type == "text")
        has_ref = self.has_figure_reference(text_content)

        if not has_ref:
            return []

        # Check if an asset or figure block is bound
        has_bound_asset = any(b.type == "asset" for b in stem_blocks)
        if not has_bound_asset:
            return [
                ValidationIssue(
                    rule_id="B-030",
                    severity="BLOCKER",
                    message={
                        "en": "Stem refers to a figure/table/diagram ('shown above/figure') but no visual asset is bound (FIGURE_MISSING).",
                        "ar": "نص السؤال يشير إلى رسم أو جدول أو شكل بياني ولكن لا يوجد رسم مرفق بالسؤال.",
                    },
                    resolvable_by="edit",
                )
            ]
        return []
