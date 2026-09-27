"""Track N Native Text Reconstructor (§8.5, §8.6).
Deterministically reconstructs question stems, options, and assets into QuestionRevisionContent.
"""

from __future__ import annotations

import re
from typing import Any

from core.models.block import Block
from core.models.question import (
    AnswerState,
    OptionItem,
    QuestionRevisionContent,
    QuestionSource,
    ResponseConfig,
)
from core.noise.detector import NoiseDetector
from core.pdf.adapter import PdfDocumentAdapter, TextSpan
from core.segmentation.models import ContinuationType, SegmentedQuestion


class NativeTextReconstructor:
    """Reconstructs native PDF text and assets into canonical question revision schemas."""

    def __init__(self, adapter: PdfDocumentAdapter):
        self.adapter = adapter
        self.noise_detector = NoiseDetector(adapter)

    def reconstruct(self, q: SegmentedQuestion) -> QuestionRevisionContent:
        """Converts a SegmentedQuestion into a canonical QuestionRevisionContent."""
        flags: list[str] = []
        if q.continuation_type != ContinuationType.NONE:
            flags.append(f"cross_page_continuation:{q.continuation_type.value}")

        stem_blocks: list[Block] = []
        block_idx = 1

        # 1. Attach Images per S-08 if present
        for img_idx, img in enumerate(q.images):
            crop_rel_path = f"crops/{q.document_id}/q{q.ordinal}_img{img_idx + 1}.png"
            stem_blocks.append(
                Block(
                    id=f"b{block_idx}",
                    type="asset",
                    role="figure",
                    asset_id=f"asset_q{q.ordinal}_img{img_idx + 1}",
                    crop_asset=crop_rel_path,
                    value=crop_rel_path,
                    raw=crop_rel_path,
                    source_refs=[f"p{img.slices[0].xref}_comp_{img.bbox}"],
                    confidence={"crop": 0.98},
                )
            )
            block_idx += 1

        # 2. Attach Vector Drawings if present (e.g., Trial August pyramid / tables)
        for draw_idx, d in enumerate(q.drawings):
            # Only attach significant drawings (> 15pt tall)
            h = d.rect[3] - d.rect[1]
            w = d.rect[2] - d.rect[0]
            if h >= 15.0 and w >= 25.0:
                stem_blocks.append(
                    Block(
                        id=f"b{block_idx}",
                        type="asset",
                        role="figure",
                        asset_id=f"vec_q{q.ordinal}_{draw_idx + 1}",
                        source_refs=[f"draw_{d.rect}"],
                        confidence={"crop": 0.95},
                    )
                )
                block_idx += 1
                break  # Attach primary drawing group

        # 3. Assemble Stem Text Spans
        # Check if anchor contains stem text after the question ordinal (e.g. '____ 11. A cylinder has...')
        anchor_text = q.anchor.text.strip()
        anchor_stem = re.sub(
            r"^(?:_+|\s*|\[|\()?0*" + str(q.ordinal) + r"(?:\.|\)|\])\s*",
            "",
            anchor_text,
        ).strip()
        if anchor_stem:
            cleaned_anchor_stem, removed_wm = self.noise_detector.clean_stem_text(anchor_stem)
            if cleaned_anchor_stem:
                stem_blocks.append(
                    Block(
                        id=f"b{block_idx}",
                        type="text",
                        value=cleaned_anchor_stem,
                        raw=anchor_stem,
                        source_refs=[f"anchor_{q.anchor.bbox[0]:.1f}_{q.anchor.bbox[1]:.1f}"],
                    )
                )
                block_idx += 1

        # Exclude anchor bbox and option bboxes
        excluded_bboxes: set[tuple[float, float, float, float]] = {q.anchor.bbox}
        if q.option_group:
            for opt in q.option_group.options:
                excluded_bboxes.add(opt.bbox)
                for cs in opt.content_spans:
                    excluded_bboxes.add(cs.bbox)

        stem_spans = [s for s in q.spans if s.bbox not in excluded_bboxes]

        # Group stem spans into horizontal lines (by y-bucket ~3pt)
        lines_by_y: dict[int, list[TextSpan]] = {}
        for s in stem_spans:
            # Skip stray numbers matching only the anchor number
            if s.text.strip() == f"{q.ordinal}.":
                continue
            y_bucket = int(round(s.origin[1] / 3.0) * 3)
            lines_by_y.setdefault(y_bucket, []).append(s)

        for y_key in sorted(lines_by_y.keys()):
            sp_sorted = sorted(lines_by_y[y_key], key=lambda s: s.bbox[0])
            raw_line = "".join(s.text for s in sp_sorted).strip()
            if not raw_line:
                continue

            cleaned_line, removed_wm = self.noise_detector.clean_stem_text(raw_line)
            if removed_wm:
                if "watermark_removed_from_text" not in flags:
                    flags.append("watermark_removed_from_text")

            if not cleaned_line:
                continue

            srefs = [f"span_{s.bbox[0]:.1f}_{s.bbox[1]:.1f}" for s in sp_sorted]
            stem_blocks.append(
                Block(
                    id=f"b{block_idx}",
                    type="text",
                    value=cleaned_line,
                    raw=raw_line,
                    source_refs=srefs,
                )
            )
            block_idx += 1

        # 4. Assemble Options
        options: list[OptionItem] = []
        if q.question_type == "multiple_choice" and q.option_group:
            for opt in q.option_group.options:
                raw_opt_text = "".join(s.text for s in opt.content_spans).strip()
                cleaned_opt, _ = self.noise_detector.clean_stem_text(raw_opt_text)
                opt_srefs = [f"opt_marker_{opt.key}_{opt.bbox[0]:.1f}_{opt.bbox[1]:.1f}"]
                for cs in opt.content_spans:
                    opt_srefs.append(f"span_{cs.bbox[0]:.1f}_{cs.bbox[1]:.1f}")

                opt_blocks = [
                    Block(
                        id=f"opt_{opt.key}_b1",
                        type="text",
                        value=cleaned_opt,
                        raw=raw_opt_text,
                        source_refs=opt_srefs,
                    )
                ]

                options.append(
                    OptionItem(
                        key=opt.key,
                        content=opt_blocks,
                        source_refs=opt_srefs,
                    )
                )

        # 5. Build canonical QuestionRevisionContent
        source = QuestionSource(
            document_id=q.document_id,
            section=q.section,
            ordinal=q.ordinal,
            pages=q.pages,
        )

        from typing import Literal

        resp_type: Literal["single_choice", "numeric"] = (
            "single_choice" if q.question_type == "multiple_choice" else "numeric"
        )
        response = ResponseConfig(
            type=resp_type,
            accepted_forms=["integer", "decimal", "fraction"] if resp_type == "numeric" else [],
            equivalence="sympy_exact",
        )

        confidence = {
            "boundary": 1.0 if q.boundary_status == "confirmed" else 0.8,
            "text": 0.95,
            "options": 1.0 if options else 0.0,
            "diagram": 0.95 if any(b.type == "asset" for b in stem_blocks) else 0.0,
            "answer": 0.0,
        }

        return QuestionRevisionContent(
            source=source,
            question_type=q.question_type,  # type: ignore[arg-type]
            language="en",
            direction="ltr",
            stem=stem_blocks,
            options=options,
            response=response,
            answer=AnswerState(status="unknown"),
            confidence=confidence,
            flags=flags,
        )
