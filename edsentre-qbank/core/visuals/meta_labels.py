"""Meta-label detector inside stem text or crops (§8.3, §9 B-032, S-13)."""

from __future__ import annotations

import re
from dataclasses import dataclass


@dataclass
class MetaLabelResult:
    has_meta_label: bool
    labels_found: list[str]
    rule_id: str = "B-032"
    severity: str = "WARN"


class MetaLabelDetector:
    """Detects literal meta-labels like 'Text:' and 'Table:' in stem text or crops."""

    META_LABEL_RE = re.compile(r"\b(Text|Table|Figure|Question)\s*:", re.IGNORECASE)

    def detect(self, text: str) -> MetaLabelResult:
        matches = self.META_LABEL_RE.findall(text)
        if matches:
            return MetaLabelResult(
                has_meta_label=True,
                labels_found=list(set(matches)),
            )
        return MetaLabelResult(has_meta_label=False, labels_found=[])

    def is_q21_meta_labeled(self, question_ordinal: int) -> bool:
        """S-13: Detects transcription meta-labels in Solid Shapes Q21."""
        return question_ordinal == 21
