"""Validation issue models for the rule catalog (§9)."""

from pydantic import BaseModel


class ValidationIssue(BaseModel):
    rule_id: str  # 'B-001', 'B-020', etc.
    severity: str  # 'BLOCKER' | 'WARN' | 'INFO'
    block_ref: str | None = None
    message: dict[str, str]  # {'en': '...', 'ar': '...'}
    resolvable_by: str | None = None  # 'edit' | 'confirm' | 'none'
