"""Data models for structure analysis, anchor detection, and segmentation (§8.4)."""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Any

from core.pdf.adapter import CompositeRegion, TextSpan, VectorDrawing


class AnchorKind(str, Enum):
    NUMBERED_HEADING = "numbered_heading"  # e.g., '1.', 'Question 1.' (LaTeX / CMBX)
    EXAMVIEW = "examview"                  # e.g., '____  1.', '___ 1.'


class ContinuationType(str, Enum):
    NONE = "none"
    STEM_TO_OPTIONS = "stem_to_options"      # e.g., M1-Q6 (stem on p3 -> options on p4)
    FIGURE_TO_STEM = "figure_to_stem"        # e.g., M1-Q13 (label/figure on p5 -> stem on p6)
    TABLE_TO_STEM = "table_to_stem"          # e.g., M2-Q15 (table on p13 -> stem on p14)
    SPLIT_OPTION_LIST = "split_option_list"  # e.g., M2-Q21 (option A on p15 -> B-D on p16)


@dataclass
class SectionScope:
    name: str                       # 'M1', 'M2', 'MAIN'
    start_page: int                 # 0-indexed inclusive
    end_page: int                   # 0-indexed inclusive
    expected_count: int | None = None
    form_id: str | None = None


@dataclass
class QuestionAnchor:
    page_no: int                    # 0-indexed
    ordinal: int
    section: str
    bbox: tuple[float, float, float, float]
    text: str
    anchor_kind: AnchorKind


@dataclass
class OptionMarker:
    key: str                        # 'A', 'B', 'C', 'D'
    page_no: int                    # 0-indexed
    bbox: tuple[float, float, float, float]
    text: str
    content_spans: list[TextSpan] = field(default_factory=list)


@dataclass
class OptionGroup:
    page_no: int                    # 0-indexed
    options: list[OptionMarker]     # Sorted A, B, C, D
    bbox: tuple[float, float, float, float]  # Union bounding box


@dataclass
class SegmentedQuestion:
    document_id: str
    section: str
    ordinal: int
    source_label: str               # e.g. 'M1-Q6', 'M2-Q21', 'Q1'
    pages: list[int]                # 1-indexed for display / canonical schema
    question_type: str              # 'multiple_choice' | 'grid_in'
    anchor: QuestionAnchor
    option_group: OptionGroup | None
    spans: list[TextSpan] = field(default_factory=list)
    images: list[CompositeRegion] = field(default_factory=list)
    drawings: list[VectorDrawing] = field(default_factory=list)
    continuation_type: ContinuationType = ContinuationType.NONE
    boundary_status: str = "confirmed"  # 'confirmed' | 'probable' | 'ambiguous'
    confidence: float = 1.0
