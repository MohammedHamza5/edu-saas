"""Forensics analyzer computing document and page classification per Section 8.1."""

import re
import statistics

from core.models.forensics import DocumentForensics, PageClass, PageForensics
from core.pdf.adapter import PdfDocumentAdapter


class ForensicsAnalyzer:
    """Analyzes a PDF document and extracts detailed forensic signals per page."""

    ANSWER_KEY_PATTERN = re.compile(r"\bANS:\s*[A-Da-d]\b", re.IGNORECASE)
    COVER_MODULE_PATTERN = re.compile(
        r"^\s*Module\s+\d+\s*$", re.IGNORECASE | re.MULTILINE
    )

    def __init__(self, adapter: PdfDocumentAdapter):
        self.adapter = adapter

    def analyze_page(self, page_no: int) -> PageForensics:
        w_pt, h_pt = self.adapter.get_page_size(page_no)
        rotation = self.adapter.get_page_rotation(page_no)
        spans = self.adapter.extract_spans(page_no)
        drawings = self.adapter.extract_drawings(page_no)
        images = self.adapter.extract_embedded_images(page_no)

        total_chars = sum(len(s.text.strip()) for s in spans)
        full_text = " ".join(s.text for s in spans)

        # Fonts & font families
        raw_fonts: set[str] = set()
        font_families: set[str] = set()
        rotated_spans = 0

        for s in spans:
            raw_fonts.add(s.font)
            f_lower = s.font.lower()
            if any(
                k in f_lower for k in ["cmr", "cmmi", "cmsy", "cmex", "cmbx", "cmti"]
            ):
                font_families.add("ComputerModern/LaTeX")
            elif "helvetica" in f_lower:
                font_families.add("Helvetica")
            elif "cid" in f_lower or "identity" in f_lower:
                font_families.add("CID")
            else:
                font_families.add(s.font)

            # Check rotation: dir != (1,0) with tolerance 1 degree (cos(1 deg) ~ 0.9998)
            dx, dy = s.dir
            if abs(dx - 1.0) > 0.02 or abs(dy) > 0.02:
                rotated_spans += 1

        # Image DPI stats
        dpi_list = [img.dpi_x for img in images if img.dpi_x > 0]
        dpi_min = min(dpi_list) if dpi_list else None
        dpi_median = statistics.median(dpi_list) if dpi_list else None

        # Answer key detection
        has_key_pattern = (
            bool(self.ANSWER_KEY_PATTERN.search(full_text))
            or "answer section" in full_text.lower()
        )

        # Cover page detection
        is_cover = False
        clean_text = full_text.strip()
        if total_chars < 150 and (
            "module" in clean_text.lower() or "exam" in clean_text.lower()
        ):
            is_cover = True

        # Text and raster coverage
        page_area = max(w_pt * h_pt, 1.0)
        text_area = 0.0
        for s in spans:
            sx0, sy0, sx1, sy1 = s.bbox
            text_area += max(0.0, (sx1 - sx0) * (sy1 - sy0))
        coverage_text = min(1.0, text_area / page_area)

        raster_area = 0.0
        for img in images:
            ix0, iy0, ix1, iy1 = img.rect
            raster_area += max(0.0, (ix1 - ix0) * (iy1 - iy0))
        coverage_raster = min(1.0, raster_area / page_area)

        # Calculate text trust
        # Trust drops with missing glyphs, overlapping text, etc.
        text_trust = 1.0
        if "PI" in full_text and "π" not in full_text and len(images) > 0:
            # S-06: π glyph missing in text layer while PI literal present
            text_trust -= 0.3

        if len(spans) == 0 and len(images) > 0:
            text_trust = 0.0

        # Classify page
        page_class: PageClass = "unknown"
        if is_cover:
            page_class = "cover"
        elif has_key_pattern and len(images) == 0:
            page_class = "native_text_only"
        elif len(images) == 0 and len(drawings) > 0 and total_chars > 200:
            page_class = "native_vector"
        elif len(images) > 0 and (
            total_chars >= 20
            or any("____" in s.text or "ID: A" in s.text for s in spans)
        ):
            # Hybrid raster: has images (stems/figures) but native text for options/numbers/headers
            page_class = "hybrid_raster"
        elif len(images) == 0 and len(drawings) == 0 and total_chars > 100:
            page_class = "native_text_only"
        elif len(images) > 0 and total_chars < 20:
            page_class = "scanned"

        return PageForensics(
            page_no=page_no + 1,  # 1-indexed for human readability
            width_pt=round(w_pt, 2),
            height_pt=round(h_pt, 2),
            rotation=rotation,
            n_chars=total_chars,
            n_spans=len(spans),
            fonts=sorted(list(raw_fonts)),
            font_families=sorted(list(font_families)),
            n_embedded_images=len(images),
            image_dpi_min=round(dpi_min, 1) if dpi_min else None,
            image_dpi_median=round(dpi_median, 1) if dpi_median else None,
            n_drawings=len(drawings),
            rotated_text_span_count=rotated_spans,
            has_answer_key_pattern=has_key_pattern,
            is_cover=is_cover,
            page_class=page_class,
            text_trust=round(max(0.0, min(1.0, text_trust)), 2),
            coverage_text=round(coverage_text, 4),
            coverage_raster=round(coverage_raster, 4),
        )

    def analyze_document(self) -> DocumentForensics:
        pages: list[PageForensics] = []
        for i in range(self.adapter.page_count):
            pages.append(self.analyze_page(i))

        # Determine dominant class
        classes = [p.page_class for p in pages if p.page_class != "cover"]
        dominant: PageClass = "unknown"
        if classes:
            counts: dict[PageClass, int] = {}
            for c in classes:
                counts[c] = counts.get(c, 0) + 1
            dominant = max(counts.items(), key=lambda item: item[1])[0]

        return DocumentForensics(
            document_path=str(self.adapter.path),
            sha256=self.adapter.sha256,
            page_count=self.adapter.page_count,
            pages=pages,
            dominant_class=dominant,
        )
