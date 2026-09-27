"""
Pilot metrics data models and mathematical calculations (§13 M6, §14).
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass
class CorrectionRecord:
    question_id: str
    document_id: str
    ordinal: int
    defect_type: str  # CE-01 (wrong answer), CE-02 (altered math/symbol), CE-06 (truncated ink), etc.
    original_revision_id: str
    corrected_revision_id: str
    corrected_by: str
    reason: str
    old_value: str | None = None
    new_value: str | None = None
    timestamp: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "question_id": self.question_id,
            "document_id": self.document_id,
            "ordinal": self.ordinal,
            "defect_type": self.defect_type,
            "original_revision_id": self.original_revision_id,
            "corrected_revision_id": self.corrected_revision_id,
            "corrected_by": self.corrected_by,
            "reason": self.reason,
            "old_value": self.old_value,
            "new_value": self.new_value,
            "timestamp": self.timestamp,
        }


@dataclass
class TeacherMetrics:
    teacher_id: str
    name: str
    questions_reviewed: int
    approved_count: int
    quarantined_count: int
    edits_count: int
    total_seconds_spent: float
    review_rate_per_hour: float

    def to_dict(self) -> dict[str, Any]:
        return {
            "teacher_id": self.teacher_id,
            "name": self.name,
            "questions_reviewed": self.questions_reviewed,
            "approved_count": self.approved_count,
            "quarantined_count": self.quarantined_count,
            "edits_count": self.edits_count,
            "total_seconds_spent": round(self.total_seconds_spent, 1),
            "review_rate_per_hour": round(self.review_rate_per_hour, 1),
        }


@dataclass
class PilotMetrics:
    total_questions: int
    total_published: int
    critical_errors_published: int
    critical_error_escape_rate: float  # Must be 0.0%
    approved_then_corrected_count: int
    approved_then_corrected_rate: float
    median_time_clean_seconds: float
    median_time_overall_seconds: float
    overall_review_rate_per_hour: float
    teachers: dict[str, TeacherMetrics] = field(default_factory=dict)
    corrections: list[CorrectionRecord] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "total_questions": self.total_questions,
            "total_published": self.total_published,
            "critical_errors_published": self.critical_errors_published,
            "critical_error_escape_rate_pct": self.critical_error_escape_rate,
            "approved_then_corrected_count": self.approved_then_corrected_count,
            "approved_then_corrected_rate_pct": self.approved_then_corrected_rate,
            "median_time_clean_seconds": self.median_time_clean_seconds,
            "median_time_overall_seconds": self.median_time_overall_seconds,
            "overall_review_rate_per_hour": self.overall_review_rate_per_hour,
            "teachers": {k: v.to_dict() for k, v in self.teachers.items()},
            "corrections_count": len(self.corrections),
            "corrections": [c.to_dict() for c in self.corrections],
        }
