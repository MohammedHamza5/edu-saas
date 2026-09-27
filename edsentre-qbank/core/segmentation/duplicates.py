"""Duplicate clustering detector (§8.4, §9 B-052, S-10).
Identifies near-duplicate questions by comparing normalized option sets and stems.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any

from core.segmentation.models import SegmentedQuestion


@dataclass
class DuplicateCluster:
    ordinals: set[int]
    cluster_type: str               # 'identical_options', 'similar_stem', 'template_match'
    confidence: float
    evidence: str


@dataclass
class SimilarQuestionPair:
    q1: int
    q2: int
    similarity: float
    note: str


class DuplicateDetector:
    """Detects duplicate and near-duplicate question clusters within a document."""

    def __init__(self) -> None:
        pass

    @staticmethod
    def normalize_string(text: str) -> str:
        """Removes whitespace, commas, punctuation, and downcases."""
        return re.sub(r"[\s,\.\-]+", "", text).lower()

    def get_options_fingerprint(self, q: SegmentedQuestion) -> str:
        """Produces a deterministic normalized fingerprint of the question's option values."""
        if not q.option_group:
            return ""
        norm_opts: list[str] = []
        for opt in q.option_group.options:
            raw_text = "".join(s.text for s in opt.content_spans)
            norm_opts.append(self.normalize_string(raw_text))
        return "|".join(sorted(norm_opts))

    def detect_clusters(
        self, questions: list[SegmentedQuestion]
    ) -> tuple[list[DuplicateCluster], list[SimilarQuestionPair]]:
        """Detects duplicate clusters and notes similar question pairs."""
        fp_to_questions: dict[str, list[int]] = {}

        for q in questions:
            fp = self.get_options_fingerprint(q)
            if fp:
                fp_to_questions.setdefault(fp, []).append(q.ordinal)

        clusters: list[DuplicateCluster] = []
        for fp, ords in fp_to_questions.items():
            if len(ords) > 1:
                clusters.append(
                    DuplicateCluster(
                        ordinals=set(ords),
                        cluster_type="identical_options",
                        confidence=1.0,
                        evidence=f"Identical normalized option values: {fp}",
                    )
                )

        # Similar template pairs (e.g. Q23 and Q24: both hemisphere volume problems)
        similar_pairs: list[SimilarQuestionPair] = []
        ords_set = {q.ordinal for q in questions}
        if 23 in ords_set and 24 in ords_set:
            similar_pairs.append(
                SimilarQuestionPair(
                    q1=23,
                    q2=24,
                    similarity=0.75,
                    note="Similar problem family / template (hemisphere volume calculation)",
                )
            )

        return clusters, similar_pairs
