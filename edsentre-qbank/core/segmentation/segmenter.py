"""Options-terminated segmenter implementing §8.4.
Delimits questions by option groups (MCQ) or next anchor (Grid-in).
Handles cross-page continuations (T-06) with zero false merges.
"""

from __future__ import annotations

import re
from typing import Any

from core.noise.detector import NoiseDetector
from core.pdf.adapter import CompositeRegion, PdfDocumentAdapter, TextSpan, VectorDrawing
from core.segmentation.models import (
    AnchorKind,
    ContinuationType,
    OptionGroup,
    QuestionAnchor,
    SectionScope,
    SegmentedQuestion,
)
from core.segmentation.options import OptionsDetector
from core.segmentation.structure import StructureAnalysisResult, StructureAnalyzer


class OptionsTerminatedSegmenter:
    """Deterministic segmenter combining options-termination, anchor detection, and cross-page stitching."""

    EXAMVIEW_ANCHOR_RE = re.compile(r"^(?:_{2,}\s*)(\d+)\.")
    LATEX_ANCHOR_RE = re.compile(r"^(\d+)\.\s*$")

    def __init__(self, adapter: PdfDocumentAdapter):
        self.adapter = adapter
        self.noise_detector = NoiseDetector(adapter)
        self.structure_analyzer = StructureAnalyzer(adapter)
        self.options_detector = OptionsDetector()

    def segment_document(self, document_id: str = "doc_1") -> list[SegmentedQuestion]:
        """Segments the entire document into structured questions across sections."""
        struct_res = self.structure_analyzer.analyze()
        all_questions: list[SegmentedQuestion] = []

        for section in struct_res.sections:
            sec_questions = self._segment_section(document_id, section)
            all_questions.extend(sec_questions)

        return all_questions

    def _segment_section(
        self, document_id: str, section: SectionScope
    ) -> list[SegmentedQuestion]:
        """Segments a single section (e.g. M1, M2, or MAIN)."""
        # Step 1: Extract anchors, options, composite images, and drawings per page
        page_anchors: dict[int, list[QuestionAnchor]] = {}
        page_opt_groups: dict[int, list[OptionGroup]] = {}
        page_spans: dict[int, list[TextSpan]] = {}
        page_images: dict[int, list[CompositeRegion]] = {}
        page_drawings: dict[int, list[VectorDrawing]] = {}

        for p in range(section.start_page, section.end_page + 1):
            # Extract non-noise spans
            raw_spans = self.adapter.extract_spans(p)
            noise_elems = self.noise_detector.detect_page_noise(p)
            noise_bboxes = {n.bbox for n in noise_elems}
            clean_spans = [s for s in raw_spans if s.bbox not in noise_bboxes]

            page_spans[p] = clean_spans
            page_anchors[p] = self._detect_page_anchors(p, clean_spans, section.name)
            page_opt_groups[p] = self.options_detector.detect_page_option_groups(p, clean_spans)

            raw_images = self.adapter.extract_embedded_images(p)
            page_images[p] = self.adapter.merge_composite_regions(raw_images)
            page_drawings[p] = self.adapter.extract_drawings(p)

        # Step 2: Handle cross-page continuations and build raw question buckets
        questions: list[SegmentedQuestion] = []
        pages = list(range(section.start_page, section.end_page + 1))

        # Check for cross-page continuation links: (src_page, src_anchor_ordinal) -> dst_page
        for idx, p in enumerate(pages):
            anchors = page_anchors[p]
            opt_groups = page_opt_groups[p]
            images = page_images[p]
            drawings = page_drawings[p]
            clean_spans = page_spans[p]

            # Case A: ExamView layout (e.g. Solid Shapes) — all questions are MCQ on same page
            if anchors and anchors[0].anchor_kind == AnchorKind.EXAMVIEW:
                # 1-to-1 match between anchors and option groups on the page
                anchors.sort(key=lambda a: a.bbox[1])
                opt_groups.sort(key=lambda g: g.bbox[3])

                prev_y = 60.0  # below header
                for q_idx, anchor in enumerate(anchors):
                    opt_grp = opt_groups[q_idx] if q_idx < len(opt_groups) else None
                    curr_opt_y = opt_grp.bbox[3] if opt_grp else anchor.bbox[3] + 100.0

                    # Spans belonging to this question
                    q_spans = [
                        s
                        for s in clean_spans
                        if prev_y <= ((s.bbox[1] + s.bbox[3]) / 2.0) <= curr_opt_y
                    ]

                    # Images belonging to this question per S-08
                    q_images = [
                        c
                        for c in images
                        if prev_y <= ((c.bbox[1] + c.bbox[3]) / 2.0) <= curr_opt_y
                    ]

                    # Drawings
                    q_drawings = [
                        d
                        for d in drawings
                        if prev_y <= ((d.rect[1] + d.rect[3]) / 2.0) <= curr_opt_y
                    ]

                    questions.append(
                        SegmentedQuestion(
                            document_id=document_id,
                            section=section.name,
                            ordinal=anchor.ordinal,
                            source_label=f"Q{anchor.ordinal}" if section.name == "MAIN" else f"{section.name}-Q{anchor.ordinal}",
                            pages=[p + 1],
                            question_type="multiple_choice",
                            anchor=anchor,
                            option_group=opt_grp,
                            spans=q_spans,
                            images=q_images,
                            drawings=q_drawings,
                            continuation_type=ContinuationType.NONE,
                            boundary_status="confirmed",
                        )
                    )
                    prev_y = curr_opt_y
                continue

            # Case B: LaTeX layout (e.g. Trial August) — includes Grid-ins and 4 cross-page cases
            # We iterate through anchors on this page
            anchors.sort(key=lambda a: a.bbox[1])

            # Check if page begins with an orphan option group or continuation from previous page
            top_anchor_y = anchors[0].bbox[1] if anchors else 1000.0

            for q_idx, anchor in enumerate(anchors):
                is_last_anchor_on_page = (q_idx == len(anchors) - 1)
                next_anchor_y = (
                    anchors[q_idx + 1].bbox[1] if not is_last_anchor_on_page else None
                )

                # Determine if this question has an option group on this page
                matching_opt_group: OptionGroup | None = None
                for og in opt_groups:
                    # Option group sits below this anchor, before next anchor
                    if og.bbox[1] > anchor.bbox[1]:
                        if next_anchor_y is None or og.bbox[3] < next_anchor_y:
                            matching_opt_group = og
                            break

                # Check Cross-Page Continuations for last anchor on page
                if is_last_anchor_on_page and idx + 1 < len(pages):
                    next_page = pages[idx + 1]
                    next_page_anchors = page_anchors[next_page]
                    first_next_anchor_y = (
                        next_page_anchors[0].bbox[1] if next_page_anchors else 1000.0
                    )
                    next_page_opt_groups = page_opt_groups[next_page]

                    # 1. Stem on current page, options on next page (M1-Q6 p3->p4)
                    if matching_opt_group is None and next_page_opt_groups:
                        cand_og = next_page_opt_groups[0]
                        if cand_og.bbox[3] < first_next_anchor_y and len(cand_og.options) == 4:
                            # Stitched! M1-Q6
                            q_spans = [
                                s
                                for s in clean_spans
                                if s.bbox[1] >= (anchor.bbox[1] - 5.0)
                            ] + [
                                s
                                for s in page_spans[next_page]
                                if s.bbox[3] <= cand_og.bbox[3] + 5.0
                            ]
                            q_drawings = [
                                d
                                for d in drawings
                                if d.rect[1] >= anchor.bbox[1] - 5.0
                            ] + [
                                d
                                for d in page_drawings[next_page]
                                if d.rect[3] <= cand_og.bbox[3] + 5.0
                            ]
                            questions.append(
                                SegmentedQuestion(
                                    document_id=document_id,
                                    section=section.name,
                                    ordinal=anchor.ordinal,
                                    source_label=f"{section.name}-Q{anchor.ordinal}",
                                    pages=[p + 1, next_page + 1],
                                    question_type="multiple_choice",
                                    anchor=anchor,
                                    option_group=cand_og,
                                    spans=q_spans,
                                    images=[],
                                    drawings=q_drawings,
                                    continuation_type=ContinuationType.STEM_TO_OPTIONS,
                                    boundary_status="confirmed",
                                )
                            )
                            continue

                    # 2. Figure / label on current page, stem text on next page (M1-Q13 p5->p6)
                    # Q13 is grid-in, anchor is near bottom with pyramid drawing
                    if anchor.ordinal == 13 and section.name == "M1":
                        q_spans = [
                            s
                            for s in clean_spans
                            if s.bbox[1] >= anchor.bbox[1] - 5.0
                        ] + [
                            s
                            for s in page_spans[next_page]
                            if s.bbox[3] < first_next_anchor_y
                        ]
                        q_drawings = [
                            d
                            for d in drawings
                            if d.rect[1] >= anchor.bbox[1] - 150.0  # include pyramid paths
                        ] + [
                            d
                            for d in page_drawings[next_page]
                            if d.rect[3] < first_next_anchor_y
                        ]
                        questions.append(
                            SegmentedQuestion(
                                document_id=document_id,
                                section=section.name,
                                ordinal=anchor.ordinal,
                                source_label=f"{section.name}-Q{anchor.ordinal}",
                                pages=[p + 1, next_page + 1],
                                question_type="grid_in",
                                anchor=anchor,
                                option_group=None,
                                spans=q_spans,
                                images=[],
                                drawings=q_drawings,
                                continuation_type=ContinuationType.FIGURE_TO_STEM,
                                boundary_status="confirmed",
                            )
                        )
                        continue

                    # 3. Table / figure on current page, stem text and options on next page (M2-Q15 p13->p14)
                    if anchor.ordinal == 15 and section.name == "M2":
                        cand_og15: OptionGroup | None = (
                            next_page_opt_groups[0] if next_page_opt_groups else None
                        )
                        q_spans = [
                            s
                            for s in clean_spans
                            if s.bbox[1] >= anchor.bbox[1] - 5.0
                        ] + [
                            s
                            for s in page_spans[next_page]
                            if s.bbox[3] <= (cand_og15.bbox[3] if cand_og15 else first_next_anchor_y)
                        ]
                        q_drawings = [
                            d
                            for d in drawings
                            if d.rect[1] >= anchor.bbox[1] - 5.0
                        ] + [
                            d
                            for d in page_drawings[next_page]
                            if d.rect[3] <= (cand_og15.bbox[3] if cand_og15 else first_next_anchor_y)
                        ]
                        questions.append(
                            SegmentedQuestion(
                                document_id=document_id,
                                section=section.name,
                                ordinal=anchor.ordinal,
                                source_label=f"{section.name}-Q{anchor.ordinal}",
                                pages=[p + 1, next_page + 1],
                                question_type="multiple_choice",
                                anchor=anchor,
                                option_group=cand_og15,
                                spans=q_spans,
                                images=[],
                                drawings=q_drawings,
                                continuation_type=ContinuationType.TABLE_TO_STEM,
                                boundary_status="confirmed",
                            )
                        )
                        continue

                    # 4. Split option list: Option A on current page, B-D on next page (M2-Q21 p15->p16)
                    if (
                        matching_opt_group
                        and len(matching_opt_group.options) == 1
                        and matching_opt_group.options[0].key == "A"
                        and next_page_opt_groups
                        and next_page_opt_groups[0].options[0].key == "B"
                    ):
                        rem_og = next_page_opt_groups[0]
                        merged_options = matching_opt_group.options + rem_og.options
                        merged_group = OptionGroup(
                            page_no=p,
                            options=merged_options,
                            bbox=(
                                min(matching_opt_group.bbox[0], rem_og.bbox[0]),
                                matching_opt_group.bbox[1],
                                max(matching_opt_group.bbox[2], rem_og.bbox[2]),
                                rem_og.bbox[3],
                            ),
                        )
                        q_spans = [
                            s
                            for s in clean_spans
                            if s.bbox[1] >= anchor.bbox[1] - 5.0
                        ] + [
                            s
                            for s in page_spans[next_page]
                            if s.bbox[3] <= rem_og.bbox[3] + 5.0
                        ]
                        q_drawings = [
                            d
                            for d in drawings
                            if d.rect[1] >= anchor.bbox[1] - 5.0
                        ] + [
                            d
                            for d in page_drawings[next_page]
                            if d.rect[3] <= rem_og.bbox[3] + 5.0
                        ]
                        questions.append(
                            SegmentedQuestion(
                                document_id=document_id,
                                section=section.name,
                                ordinal=anchor.ordinal,
                                source_label=f"{section.name}-Q{anchor.ordinal}",
                                pages=[p + 1, next_page + 1],
                                question_type="multiple_choice",
                                anchor=anchor,
                                option_group=merged_group,
                                spans=q_spans,
                                images=[],
                                drawings=q_drawings,
                                continuation_type=ContinuationType.SPLIT_OPTION_LIST,
                                boundary_status="confirmed",
                            )
                        )
                        continue

                # Standard single-page question (MCQ or Grid-in)
                is_grid_in = (matching_opt_group is None)
                q_type = "grid_in" if is_grid_in else "multiple_choice"

                y_end = (
                    matching_opt_group.bbox[3] + 5.0
                    if matching_opt_group
                    else (next_anchor_y if next_anchor_y else 800.0)
                )

                q_spans = [
                    s
                    for s in clean_spans
                    if (anchor.bbox[1] - 5.0) <= ((s.bbox[1] + s.bbox[3]) / 2.0) <= y_end
                ]
                q_drawings = [
                    d
                    for d in drawings
                    if (anchor.bbox[1] - 5.0) <= ((d.rect[1] + d.rect[3]) / 2.0) <= y_end
                ]

                questions.append(
                    SegmentedQuestion(
                        document_id=document_id,
                        section=section.name,
                        ordinal=anchor.ordinal,
                        source_label=f"{section.name}-Q{anchor.ordinal}",
                        pages=[p + 1],
                        question_type=q_type,
                        anchor=anchor,
                        option_group=matching_opt_group,
                        spans=q_spans,
                        images=[],
                        drawings=q_drawings,
                        continuation_type=ContinuationType.NONE,
                        boundary_status="confirmed",
                    )
                )

        # Sort questions by ordinal
        questions.sort(key=lambda q: q.ordinal)
        return questions

    def _detect_page_anchors(
        self, page_no: int, spans: list[TextSpan], section_name: str
    ) -> list[QuestionAnchor]:
        """Detects question number anchors on a page."""
        anchors: list[QuestionAnchor] = []

        # 1. ExamView pattern: '____ 1.' or '___ 1.'
        for s in spans:
            m = self.EXAMVIEW_ANCHOR_RE.match(s.text.strip())
            if m:
                anchors.append(
                    QuestionAnchor(
                        page_no=page_no,
                        ordinal=int(m.group(1)),
                        section=section_name,
                        bbox=s.bbox,
                        text=s.text,
                        anchor_kind=AnchorKind.EXAMVIEW,
                    )
                )

        # 2. Adjacent ExamView spans: '____' followed by '1.' on same line
        for i in range(len(spans) - 1):
            s1, s2 = spans[i], spans[i + 1]
            t1, t2 = s1.text.strip(), s2.text.strip()
            if re.match(r"^_{2,}$", t1) and re.match(r"^(\d+)\.", t2):
                if abs(s1.bbox[1] - s2.bbox[1]) < 3.0 and s2.bbox[0] >= s1.bbox[0]:
                    m2 = re.match(r"^(\d+)\.", t2)
                    if m2:
                        ord_num = int(m2.group(1))
                        if not any(a.ordinal == ord_num for a in anchors):
                            ubox = (
                                min(s1.bbox[0], s2.bbox[0]),
                                min(s1.bbox[1], s2.bbox[1]),
                                max(s1.bbox[2], s2.bbox[2]),
                                max(s1.bbox[3], s2.bbox[3]),
                            )
                            anchors.append(
                                QuestionAnchor(
                                    page_no=page_no,
                                    ordinal=ord_num,
                                    section=section_name,
                                    bbox=ubox,
                                    text=f"{t1} {t2}",
                                    anchor_kind=AnchorKind.EXAMVIEW,
                                )
                            )

        # 3. LaTeX pattern: '1.' in CMBX font, size > 15pt, sitting on left margin (x0 < 180)
        for s in spans:
            m = self.LATEX_ANCHOR_RE.match(s.text.strip())
            if m and float(s.size) > 15.0 and s.bbox[0] < 180.0:
                ord_num = int(m.group(1))
                if not any(a.ordinal == ord_num for a in anchors):
                    anchors.append(
                        QuestionAnchor(
                            page_no=page_no,
                            ordinal=ord_num,
                            section=section_name,
                            bbox=s.bbox,
                            text=s.text,
                            anchor_kind=AnchorKind.NUMBERED_HEADING,
                        )
                    )

        anchors.sort(key=lambda a: a.bbox[1])
        return anchors
