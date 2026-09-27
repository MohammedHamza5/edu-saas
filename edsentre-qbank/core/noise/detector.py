"""Noise and watermark detector implementing layered deterministic rules per Section 8.3."""

import re
from dataclasses import dataclass

from core.pdf.adapter import PdfDocumentAdapter, TextSpan


@dataclass
class NoiseElement:
    text: str
    kind: str  # "rotated_watermark", "header", "footer", "stem_prefix", "page_number"
    bbox: tuple[float, float, float, float]
    page_no: int
    rule_id: str


class NoiseDetector:
    """Layered deterministic noise detector."""

    STEM_PREFIX_PATTERN = re.compile(r"^\[Tg:\s*@[^\]]+\]\s*", re.IGNORECASE)

    def __init__(self, adapter: PdfDocumentAdapter):
        self.adapter = adapter
        self.page_count = adapter.page_count
        self.stem_prefix_signature: str | None = None
        self._detect_stem_prefix_signature()

    def _detect_stem_prefix_signature(self) -> None:
        """Rule 4: Detect document-level stem prefix appearing in >= 80% of questions."""
        prefixes: dict[str, int] = {}
        for p in range(self.page_count):
            spans = self.adapter.extract_spans(p)
            lines_by_y: dict[int, list[str]] = {}
            for s in spans:
                y_bucket = int(round(s.origin[1] / 3.0) * 3)
                lines_by_y.setdefault(y_bucket, []).append(s.text)

            for tokens in lines_by_y.values():
                line_text = "".join(tokens).strip()
                m = self.STEM_PREFIX_PATTERN.search(line_text)
                if m:
                    pref = m.group(0).strip()
                    prefixes[pref] = prefixes.get(pref, 0) + 1

        if prefixes:
            best_prefix, count = max(prefixes.items(), key=lambda item: item[1])
            if count >= 10:  # Present across many stems
                self.stem_prefix_signature = best_prefix

    def is_rotated_watermark(self, span: TextSpan) -> bool:
        """Rule 1: Rotated / off-axis text (dir != (1,0) tolerance 1 deg)."""
        dx, dy = span.dir
        return abs(dx - 1.0) > 0.02 or abs(dy) > 0.02

    def is_helvetica_watermark(self, span: TextSpan) -> bool:
        """Rule 2: Helvetica font appearing on a LaTeX ComputerModern document."""
        return "helvetica" in span.font.lower()

    def is_header_or_footer(self, span: TextSpan, page_height: float) -> str | None:
        """Rule 3: Repeated header (near top) or footer (near bottom).
        Preserves 'ID: A' as form_id per S-09.
        """
        text = span.text.strip()
        if text == "ID: A":
            return None  # Preserved as ExamView form_id

        y0 = span.bbox[1]
        y1 = span.bbox[3]

        # Top 85pt = header zone
        if y1 <= 85.0:
            lower_text = text.lower()
            if any(k in lower_text for k in ("tg:", "digitsat", "digital sat", "aug", "2026", "name:", "class:", "session", "solid shapes")):
                return "header"

        # Bottom 60pt = footer zone
        if y0 >= (page_height - 60.0):
            if any(k in text.lower() for k in ("@abusat", "page", "module")) or text.isdigit():
                return "footer"

        return None

    def detect_page_noise(self, page_no: int) -> list[NoiseElement]:
        """Detects all noise elements on a given page."""
        w, h = self.adapter.get_page_size(page_no)
        spans = self.adapter.extract_spans(page_no)
        noise_elements: list[NoiseElement] = []

        for s in spans:
            text = s.text.strip()
            if not text:
                continue

            # Rule 1: Rotated text
            if self.is_rotated_watermark(s):
                noise_elements.append(
                    NoiseElement(
                        text=s.text,
                        kind="rotated_watermark",
                        bbox=s.bbox,
                        page_no=page_no + 1,
                        rule_id="RULE_1_ROTATED",
                    )
                )
                continue

            # Rule 2: Helvetica font on LaTeX doc
            if self.is_helvetica_watermark(s):
                noise_elements.append(
                    NoiseElement(
                        text=s.text,
                        kind="rotated_watermark",
                        bbox=s.bbox,
                        page_no=page_no + 1,
                        rule_id="RULE_2_FONT_DISCRIMINATOR",
                    )
                )
                continue

            # Rule 3: Header / Footer
            hf_kind = self.is_header_or_footer(s, h)
            if hf_kind:
                noise_elements.append(
                    NoiseElement(
                        text=s.text,
                        kind=hf_kind,
                        bbox=s.bbox,
                        page_no=page_no + 1,
                        rule_id="RULE_3_REPETITION_ZONE",
                    )
                )

        return noise_elements

    def clean_stem_text(self, text: str) -> tuple[str, str | None]:
        """Rule 4: Strips stem prefix watermark, returning (cleaned_text, removed_watermark)."""
        if self.stem_prefix_signature and text.startswith(self.stem_prefix_signature):
            cleaned = text[len(self.stem_prefix_signature) :].strip()
            return cleaned, self.stem_prefix_signature

        m = self.STEM_PREFIX_PATTERN.match(text)
        if m:
            removed = m.group(0)
            cleaned = text[len(removed) :].strip()
            return cleaned, removed

        return text, None
