"""Block models representing atomic elements of a reconstructed question."""

from typing import Any, Literal

from pydantic import BaseModel, Field

BlockType = Literal["text", "math", "asset", "table", "label"]


class Block(BaseModel):
    id: str
    type: BlockType
    value: str | None = None
    latex: str | None = None
    asset_id: str | None = None
    role: str | None = None  # "figure" | "table" | "formula"
    raw: str | None = None
    raw_readers: dict[str, str] = Field(default_factory=dict)
    crop_asset: str | None = None
    source_refs: list[str] = Field(default_factory=list)
    lang: str = "en"
    direction: Literal["ltr", "rtl"] = "ltr"
    confidence: dict[str, float] = Field(default_factory=dict)
    uncertain: list[dict[str, Any]] = Field(default_factory=list)
