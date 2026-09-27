"""Question and revision schema models per Section 7.1."""

from typing import Any, Literal

from pydantic import BaseModel, Field

from core.models.block import Block

AnswerStatus = Literal[
    "unknown",
    "ai_proposed",
    "source_extracted",
    "solver_verified",
    "source_and_solver_agree",
    "teacher_confirmed",
]


class OptionItem(BaseModel):
    key: str
    content: list[Block] = Field(default_factory=list)
    source_refs: list[str] = Field(default_factory=list)


class ResponseConfig(BaseModel):
    type: Literal["single_choice", "numeric", "boolean"]
    accepted_forms: list[str] = Field(default_factory=list)
    equivalence: str = "sympy_exact"
    tolerance: float | None = None


class AnswerState(BaseModel):
    status: AnswerStatus = "unknown"
    raw: str | None = None
    normalized: str | None = None
    accepted_equivalents: list[str] = Field(default_factory=list)
    candidates: list[dict[str, Any]] = Field(default_factory=list)
    source_ref: str | None = None


class QuestionSource(BaseModel):
    document_id: str
    section: str | None = None
    ordinal: int
    pages: list[int] = Field(default_factory=list)
    form_id: str | None = None


class QuestionRevisionContent(BaseModel):
    source: QuestionSource
    question_type: Literal["multiple_choice", "grid_in", "true_false"]
    language: str = "en"
    direction: Literal["ltr", "rtl"] = "ltr"
    stem: list[Block] = Field(default_factory=list)
    options: list[OptionItem] = Field(default_factory=list)
    response: ResponseConfig
    answer: AnswerState = Field(default_factory=AnswerState)
    taxonomy: list[dict[str, Any]] = Field(default_factory=list)
    difficulty: dict[str, Any] = Field(default_factory=dict)
    confidence: dict[str, float] = Field(default_factory=dict)
    flags: list[str] = Field(default_factory=list)
