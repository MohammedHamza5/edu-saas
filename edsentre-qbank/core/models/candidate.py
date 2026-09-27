"""Candidate model representing raw outputs from extractors/readers."""

from typing import Any

from pydantic import BaseModel, Field


class Candidate(BaseModel):
    value: str | dict[str, Any]
    reader: str  # "pdf_native" | "paddleocr" | "vlm:qwen2.5-vl-7b" | "mathocr:unimernet" | "human"
    reader_version: str = "1.0.0"
    prompt_version: str | None = None
    input_hash: str
    evidence_refs: list[str] = Field(default_factory=list)
    self_confidence: float | None = None
    latency_ms: int = 0
    est_cost_usd: float = 0.0
