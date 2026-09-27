"""Option detection and spatial clustering (§8.4).
Supports multi-column and single-column layouts, ExamView ('a.') and LaTeX ('A)') formats.
"""

from __future__ import annotations

import re
from typing import Any

from core.pdf.adapter import TextSpan
from core.segmentation.models import OptionGroup, OptionMarker


class OptionsDetector:
    """Detects and clusters option markers and associated content on a page."""

    EXAMVIEW_OPT_RE = re.compile(r"^([a-dA-D])\.\s*$")
    LATEX_OPT_RE = re.compile(r"^([a-dA-D])\)\s*$")

    def __init__(self) -> None:
        pass

    def detect_markers(self, page_no: int, spans: list[TextSpan]) -> list[OptionMarker]:
        """Extracts candidate option markers from text spans."""
        markers: list[OptionMarker] = []
        for s in spans:
            t = s.text.strip()
            m_ev = self.EXAMVIEW_OPT_RE.match(t)
            m_lt = self.LATEX_OPT_RE.match(t)

            if m_ev:
                key = m_ev.group(1).upper()
                markers.append(
                    OptionMarker(
                        key=key,
                        page_no=page_no,
                        bbox=s.bbox,
                        text=s.text,
                    )
                )
            elif m_lt and s.bbox[0] < 200.0:  # LaTeX options sit on left margin
                key = m_lt.group(1).upper()
                markers.append(
                    OptionMarker(
                        key=key,
                        page_no=page_no,
                        bbox=s.bbox,
                        text=s.text,
                    )
                )
        return markers

    def detect_page_option_groups(
        self, page_no: int, spans: list[TextSpan]
    ) -> list[OptionGroup]:
        """Clusters option markers on a page into OptionGroups with content spans."""
        markers = self.detect_markers(page_no, spans)
        if not markers:
            return []

        # Determine if page uses a two-column option layout (e.g., Solid Shapes: x~90 and x~301)
        right_col_markers = [m for m in markers if m.bbox[0] > 200.0]
        is_two_column = len(right_col_markers) > 0

        groups: list[OptionGroup] = []

        if is_two_column:
            # ExamView 2-column layout:
            # Markers appear in order: A (left row 1), C (right row 1), B (left row 2), D (right row 2)
            i = 0
            while i < len(markers):
                chunk = markers[i : i + 4]
                if len(chunk) == 4 and {m.key for m in chunk} == {"A", "B", "C", "D"}:
                    sorted_options = sorted(chunk, key=lambda m: m.key)
                    # Associate content spans for each option
                    self._attach_content_spans_2col(sorted_options, spans)
                    ubbox = self._compute_union_bbox(sorted_options)
                    groups.append(
                        OptionGroup(
                            page_no=page_no,
                            options=sorted_options,
                            bbox=ubbox,
                        )
                    )
                    i += 4
                else:
                    i += 1
        else:
            # Single-column layout (e.g., Trial August):
            # Sort markers vertically
            sorted_markers = sorted(markers, key=lambda m: m.bbox[1])
            i = 0
            n = len(sorted_markers)
            while i < n:
                # Check for full A, B, C, D group
                if i + 4 <= n:
                    chunk = sorted_markers[i : i + 4]
                    if [m.key for m in chunk] == ["A", "B", "C", "D"]:
                        self._attach_content_spans_1col(chunk, spans, next_anchor_y=None)
                        ubbox = self._compute_union_bbox(chunk)
                        groups.append(
                            OptionGroup(
                                page_no=page_no,
                                options=chunk,
                                bbox=ubbox,
                            )
                        )
                        i += 4
                        continue

                # Check for partial options at start of page (e.g. B, C, D on p16)
                if i == 0 and sorted_markers[0].key == "B":
                    partial_end = i
                    expected_keys = ["B", "C", "D"]
                    k_idx = 0
                    while (
                        partial_end < n
                        and k_idx < len(expected_keys)
                        and sorted_markers[partial_end].key == expected_keys[k_idx]
                    ):
                        partial_end += 1
                        k_idx += 1
                    chunk = sorted_markers[i:partial_end]
                    self._attach_content_spans_1col(chunk, spans, next_anchor_y=None)
                    ubbox = self._compute_union_bbox(chunk)
                    groups.append(
                        OptionGroup(
                            page_no=page_no,
                            options=chunk,
                            bbox=ubbox,
                        )
                    )
                    i = partial_end
                    continue

                # Check for partial options at end of page (e.g. only A on p15)
                remaining = sorted_markers[i:]
                if remaining and remaining[0].key == "A":
                    self._attach_content_spans_1col(remaining, spans, next_anchor_y=None)
                    ubbox = self._compute_union_bbox(remaining)
                    groups.append(
                        OptionGroup(
                            page_no=page_no,
                            options=remaining,
                            bbox=ubbox,
                        )
                    )
                    break
                i += 1

        return groups

    def _attach_content_spans_2col(
        self, options: list[OptionMarker], page_spans: list[TextSpan]
    ) -> None:
        """Attaches text spans to options in a 2-column layout."""
        # options are sorted A, B, C, D
        # A: left row 1, B: left row 2
        # C: right row 1, D: right row 2
        opt_dict = {m.key: m for m in options}
        a, b, c, d = opt_dict["A"], opt_dict["B"], opt_dict["C"], opt_dict["D"]

        y_row1_top = min(a.bbox[1], c.bbox[1]) - 2.0
        y_row1_bot = max(a.bbox[3], c.bbox[3]) + 4.0
        y_row2_top = min(b.bbox[1], d.bbox[1]) - 2.0
        y_row2_bot = max(b.bbox[3], d.bbox[3]) + 10.0

        col_mid_x = (a.bbox[0] + c.bbox[0]) / 2.0

        for s in page_spans:
            # Skip marker spans themselves
            if s.text.strip() in ("a.", "b.", "c.", "d.", "A.", "B.", "C.", "D."):
                continue

            sy_mid = (s.bbox[1] + s.bbox[3]) / 2.0
            sx0 = s.bbox[0]

            if y_row1_top <= sy_mid <= y_row1_bot:
                if a.bbox[2] <= sx0 < col_mid_x:
                    a.content_spans.append(s)
                elif c.bbox[2] <= sx0:
                    c.content_spans.append(s)
            elif y_row2_top <= sy_mid <= y_row2_bot:
                if b.bbox[2] <= sx0 < col_mid_x:
                    b.content_spans.append(s)
                elif d.bbox[2] <= sx0:
                    d.content_spans.append(s)

    def _attach_content_spans_1col(
        self,
        options: list[OptionMarker],
        page_spans: list[TextSpan],
        next_anchor_y: float | None,
    ) -> None:
        """Attaches text spans to options in a single-column layout."""
        for idx, opt in enumerate(options):
            y_start = opt.bbox[1] - 2.0
            if idx + 1 < len(options):
                y_end = options[idx + 1].bbox[1] - 1.0
            else:
                y_end = next_anchor_y if next_anchor_y else (opt.bbox[3] + 25.0)

            for s in page_spans:
                if re.match(r"^[A-D]\)\s*$", s.text.strip()) and s.bbox == opt.bbox:
                    continue
                sy_mid = (s.bbox[1] + s.bbox[3]) / 2.0
                if y_start <= sy_mid < y_end and s.bbox[0] >= opt.bbox[0]:
                    opt.content_spans.append(s)

    def _compute_union_bbox(
        self, markers: list[OptionMarker]
    ) -> tuple[float, float, float, float]:
        all_x0: list[float] = []
        all_y0: list[float] = []
        all_x1: list[float] = []
        all_y1: list[float] = []

        for m in markers:
            all_x0.append(m.bbox[0])
            all_y0.append(m.bbox[1])
            all_x1.append(m.bbox[2])
            all_y1.append(m.bbox[3])
            for cs in m.content_spans:
                all_x0.append(cs.bbox[0])
                all_y0.append(cs.bbox[1])
                all_x1.append(cs.bbox[2])
                all_y1.append(cs.bbox[3])

        return (min(all_x0), min(all_y0), max(all_x1), max(all_y1))
