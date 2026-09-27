"""Document structure analyzer (§8.4).
Detects cover pages, sections (e.g. Module 1, Module 2), scopes, form IDs, and answer-key pages.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from core.pdf.adapter import PdfDocumentAdapter
from core.segmentation.models import SectionScope


@dataclass
class StructureAnalysisResult:
    sections: list[SectionScope]
    cover_pages: list[int] = field(default_factory=list)          # 0-indexed
    answer_key_pages: list[int] = field(default_factory=list)     # 0-indexed
    form_id: str | None = None


class StructureAnalyzer:
    """Deterministic document-level structure analyzer."""

    MODULE_COVER_RE = re.compile(r"\bModule\s*(\d+)\b", re.IGNORECASE)
    ANSWER_KEY_RE = re.compile(r"\b(?:ANS|Answer)\s*:\s*[A-D]\b", re.IGNORECASE)
    FORM_ID_RE = re.compile(r"\bID:\s*([A-Z0-9]+)\b")

    def __init__(self, adapter: PdfDocumentAdapter):
        self.adapter = adapter
        self.page_count = adapter.page_count

    def analyze(self) -> StructureAnalysisResult:
        cover_pages: list[int] = []
        answer_key_pages: list[int] = []
        module_markers: list[tuple[int, str]] = []  # (page_no, 'M1' | 'M2')
        form_ids: dict[str, int] = {}

        for p in range(self.page_count):
            spans = self.adapter.extract_spans(p)
            text = " ".join(s.text for s in spans)

            # Check Form ID (e.g. 'ID: A')
            m_form = self.FORM_ID_RE.search(text)
            if m_form:
                fid = m_form.group(1)
                form_ids[fid] = form_ids.get(fid, 0) + 1

            # Check Answer Key page
            if self.ANSWER_KEY_RE.search(text):
                answer_key_pages.append(p)
                continue

            # Check Cover page with Module N
            m_mod = self.MODULE_COVER_RE.search(text)
            if m_mod:
                mod_num = m_mod.group(1)
                # Ensure it's a cover page: low text density (< 300 chars) or explicitly styled
                if len(text.strip()) < 400:
                    cover_pages.append(p)
                    module_markers.append((p, f"M{mod_num}"))

        # Determine dominant Form ID if any
        dominant_form_id: str | None = None
        if form_ids:
            dominant_form_id = max(form_ids.items(), key=lambda item: item[1])[0]

        # Construct sections
        sections: list[SectionScope] = []

        if module_markers:
            # Multi-module document (e.g., Trail August)
            for idx, (cov_p, sec_name) in enumerate(module_markers):
                start_p = cov_p + 1
                if idx + 1 < len(module_markers):
                    end_p = module_markers[idx + 1][0] - 1
                else:
                    # Last module runs up to the last non-answer-key page
                    end_p = self.page_count - 1
                    while end_p in answer_key_pages and end_p >= start_p:
                        end_p -= 1

                sections.append(
                    SectionScope(
                        name=sec_name,
                        start_page=start_p,
                        end_page=end_p,
                        expected_count=22,  # Standard Digital SAT module count
                        form_id=dominant_form_id,
                    )
                )
        else:
            # Single section document (e.g., Solid Shapes)
            content_end = self.page_count - 1
            while content_end in answer_key_pages and content_end > 0:
                content_end -= 1

            # If there's an answer key on the last page, we can inspect expected question count from it
            expected_q_count: int | None = None
            if answer_key_pages:
                key_page = answer_key_pages[0]
                key_spans = self.adapter.extract_spans(key_page)
                key_text = " ".join(s.text for s in key_spans)
                matches = re.findall(r"(\d+)\.\s*ANS:", key_text)
                if matches:
                    expected_q_count = max(int(m) for m in matches)

            sections.append(
                SectionScope(
                    name="MAIN",
                    start_page=0,
                    end_page=content_end,
                    expected_count=expected_q_count or 30,
                    form_id=dominant_form_id,
                )
            )

        return StructureAnalysisResult(
            sections=sections,
            cover_pages=cover_pages,
            answer_key_pages=answer_key_pages,
            form_id=dominant_form_id,
        )
