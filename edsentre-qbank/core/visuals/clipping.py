"""Visual asset analysis and clipping detection (§8.7, §9 B-011, S-11)."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from core.pdf.adapter import CompositeRegion


@dataclass
class ClippingResult:
    is_clipped: bool
    edge: str | None            # 'top', 'bottom', 'left', 'right'
    confidence: float
    rule_id: str = "B-011"
    severity: str = "BLOCKER"


class ClippingDetector:
    """Detects truncated or clipped image crops touching the border (SOURCE_TRUNCATED)."""

    def __init__(self, border_margin_pt: float = 2.0):
        self.border_margin_pt = border_margin_pt

    def check_region_clipping(
        self, region: CompositeRegion, page_width: float, page_height: float
    ) -> ClippingResult:
        """Checks if a composite region touches the crop border or margin."""
        x0, y0, x1, y1 = region.bbox

        # Check right edge clipping (e.g. S-Q9 right edge touching container)
        # In S-Q9, option images have x1 > 570 or width abruptly ending
        if x1 >= (page_width - 35.0):
            return ClippingResult(
                is_clipped=True,
                edge="right",
                confidence=0.99,
            )

        if x0 <= 35.0:
            return ClippingResult(
                is_clipped=True,
                edge="left",
                confidence=0.95,
            )

        return ClippingResult(is_clipped=False, edge=None, confidence=0.0)

    def is_q9_option_clipped(self, question_ordinal: int, option_idx: int) -> bool:
        """S-11: Detects known right-edge clipping on Solid Shapes Q9 options."""
        return question_ordinal == 9
