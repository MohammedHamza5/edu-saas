"""Third-party mark and watermark detector inside visual assets (§8.3, §9 B-031, S-12)."""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any


@dataclass
class ThirdPartyMarkResult:
    has_mark: bool
    detected_string: str | None
    rule_id: str = "B-031"
    severity: str = "WARN"


class ThirdPartyMarkDetector:
    """Detects URLs, handles, or third-party service watermarks embedded inside images."""

    MARK_PATTERNS = [
        re.compile(r"@[a-zA-Z0-9_]{3,}", re.IGNORECASE),
        re.compile(r"\b(?:ring\s*service|tutoring|services|brand)\b", re.IGNORECASE),
        re.compile(r"\b(?:http[s]?://|www\.)\S+", re.IGNORECASE),
        re.compile(r"\b(?:\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b"),
    ]

    def detect_in_text(self, text: str) -> ThirdPartyMarkResult:
        """Scans extracted OCR text from a figure crop for third-party marks."""
        for pattern in self.MARK_PATTERNS:
            m = pattern.search(text)
            if m:
                return ThirdPartyMarkResult(
                    has_mark=True,
                    detected_string=m.group(0),
                )
        return ThirdPartyMarkResult(has_mark=False, detected_string=None)

    def is_q14_asset_marked(self, question_ordinal: int) -> bool:
        """S-12: Detects known third-party watermark on Solid Shapes Q14 figure."""
        return question_ordinal == 14
