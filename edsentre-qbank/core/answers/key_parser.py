"""ExamView answer key parser per Section 8.8."""

import re
from dataclasses import dataclass

from core.pdf.adapter import PdfDocumentAdapter


@dataclass
class AnswerKeyEntry:
    question_no: int
    answer_key: str  # A, B, C, D (normalized uppercase)
    points: float | None = None
    form_id: str | None = None
    bbox: tuple[float, float, float, float] | None = None


class ExamViewKeyParser:
    """Parses ExamView 'Answer Section' pages."""

    # Matches lines like:
    # "1. ANS: D PTS: 1" or "____ 1. ANS: D"
    KEY_REGEX = re.compile(
        r"(?:_{2,}\s*)?(\d{1,3})\.\s*ANS:\s*([A-Da-d])(?:\s+PTS:\s*(\d+))?",
        re.IGNORECASE,
    )
    FORM_ID_REGEX = re.compile(r"\bID:\s*([A-Z0-9]+)\b", re.IGNORECASE)

    def __init__(self, adapter: PdfDocumentAdapter):
        self.adapter = adapter

    def parse_page(self, page_no: int) -> dict[int, AnswerKeyEntry]:
        """Parses answer key entries from a single page."""
        spans = self.adapter.extract_spans(page_no)
        full_text = "\n".join(s.text for s in spans)

        # Detect form ID (e.g. "ID: A")
        form_id: str | None = None
        form_match = self.FORM_ID_REGEX.search(full_text)
        if form_match:
            form_id = form_match.group(1).upper()

        entries: dict[int, AnswerKeyEntry] = {}

        # Also search line by line across spans or reconstructed text
        # Since ExamView can place tokens in multiple spans, let's reconstruct full text lines
        # Group spans by line y-coord
        lines_by_y: dict[int, list[str]] = {}
        for s in spans:
            y_bucket = int(round(s.origin[1] / 3.0) * 3)  # cluster within 3pt
            lines_by_y.setdefault(y_bucket, []).append(s.text)

        reconstructed_lines = [" ".join(tokens) for tokens in lines_by_y.values()]

        for line in reconstructed_lines:
            for match in self.KEY_REGEX.finditer(line):
                q_num = int(match.group(1))
                key = match.group(2).upper()
                pts = float(match.group(3)) if match.group(3) else None
                entries[q_num] = AnswerKeyEntry(
                    question_no=q_num,
                    answer_key=key,
                    points=pts,
                    form_id=form_id,
                )

        return entries

    def parse_all_keys(self) -> dict[int, AnswerKeyEntry]:
        """Scans all pages having an answer key pattern and merges entries."""
        all_entries: dict[int, AnswerKeyEntry] = {}
        for p in range(self.adapter.page_count):
            spans = self.adapter.extract_spans(p)
            text = " ".join(s.text for s in spans)
            if "answer section" in text.lower() or "ans:" in text.lower():
                page_entries = self.parse_page(p)
                all_entries.update(page_entries)
        return all_entries
