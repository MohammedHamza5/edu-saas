"""Forensics models for document and page characterization."""

from typing import Literal

from pydantic import BaseModel, Field

PageClass = Literal[
    "native_vector",
    "hybrid_raster",
    "native_text_only",
    "scanned",
    "screenshot",
    "cover",
    "unknown",
]


class PageForensics(BaseModel):
    page_no: int
    width_pt: float
    height_pt: float
    rotation: int = 0
    n_chars: int = 0
    n_spans: int = 0
    fonts: list[str] = Field(default_factory=list)
    font_families: list[str] = Field(default_factory=list)
    n_embedded_images: int = 0
    image_dpi_min: float | None = None
    image_dpi_median: float | None = None
    n_drawings: int = 0
    rotated_text_span_count: int = 0
    has_answer_key_pattern: bool = False
    is_cover: bool = False
    page_class: PageClass = "unknown"
    text_trust: float = 1.0  # 0.0 to 1.0
    coverage_text: float = 0.0
    coverage_raster: float = 0.0


class DocumentForensics(BaseModel):
    document_path: str
    sha256: str
    page_count: int
    pages: list[PageForensics] = Field(default_factory=list)
    dominant_class: PageClass = "unknown"
