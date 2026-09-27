"""
FastAPI Router for Review Console (§10, §13 M5).
"""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Header, HTTPException, Query, status
from pydantic import BaseModel, Field

from services.review.service import ReviewConsoleService, ReviewTask

router = APIRouter(prefix="/qb", tags=["review"])

# Shared service instance for application routes
review_service = ReviewConsoleService()


# ─── Request / Response Schemas ───────────────────────────────────────────────


class AcknowledgeRequest(BaseModel):
    rule_id: str
    reason: str | None = None


class EditBlockRequest(BaseModel):
    block_id: str
    new_value: str
    reason: str = "teacher_edit"


class SelectAnswerRequest(BaseModel):
    selected_key: str


class SplitRequest(BaseModel):
    split_at_block_id: str


class UnreadableRequest(BaseModel):
    reason: str = "Source unreadable / truncated ink"


class RestoreRequest(BaseModel):
    target_revision_id: str


class ApproveRequest(BaseModel):
    pass


class TaskResponse(BaseModel):
    question_id: str
    source_label: str
    ordinal: int
    question_type: str
    status: str
    latest_revision_id: str
    rev_no: int
    content_hash: str
    priority_score: float
    has_unresolved_blockers: bool
    can_approve: bool
    duplicate_cluster_id: str | None = None
    requires_second_review: bool = False
    policy_state: str
    issues_count: int


def _require_auth(authorization: str | None) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "AUTH_REQUIRED", "message": "Missing Authorization header"},
        )
    return authorization.removeprefix("Bearer ").strip()


def _task_to_response(task: ReviewTask) -> TaskResponse:
    return TaskResponse(
        question_id=task.question_id,
        source_label=task.source_label,
        ordinal=task.ordinal,
        question_type=task.question_type,
        status=task.status,
        latest_revision_id=task.latest_revision_id,
        rev_no=task.rev_no,
        content_hash=task.content_hash,
        priority_score=task.priority_score,
        has_unresolved_blockers=task.has_unresolved_blockers,
        can_approve=task.can_approve,
        duplicate_cluster_id=task.duplicate_cluster_id,
        requires_second_review=task.requires_second_review,
        policy_state=task.policy_decision.policy_state,
        issues_count=len(task.issues),
    )


# ─── Endpoints ────────────────────────────────────────────────────────────────


@router.get("/review/tasks", response_model=list[TaskResponse])
async def list_tasks(
    sort_by_priority: bool = Query(default=True),
    cluster_duplicates: bool = Query(default=True),
    tenant_id: str = Query(default="tenant-default"),
    authorization: str | None = Header(default=None),
) -> list[TaskResponse]:
    """List review queue tasks ordered by priority score with duplicate clustering."""
    _require_auth(authorization)
    tasks = review_service.list_tasks(
        tenant_id=tenant_id,
        sort_by_priority=sort_by_priority,
        cluster_duplicates=cluster_duplicates,
    )
    return [_task_to_response(t) for t in tasks]


@router.post("/revisions/{revision_id}/ack")
async def acknowledge_issue(
    revision_id: str,
    body: AcknowledgeRequest,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    """Acknowledge a confirmable issue on a revision."""
    user_id = _require_auth(authorization)
    try:
        acks = review_service.acknowledge_issue(
            revision_id=revision_id,
            rule_id=body.rule_id,
            acknowledged_by=user_id,
            reason=body.reason,
        )
        return {"revision_id": revision_id, "acknowledged_rules": list(acks)}
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)) from e


@router.post("/revisions/{revision_id}/edit")
async def edit_block(
    revision_id: str,
    body: EditBlockRequest,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    """Edit a block in a revision, generating a new immutable revision."""
    user_id = _require_auth(authorization)
    try:
        new_rev = review_service.edit_block(
            revision_id=revision_id,
            block_id=body.block_id,
            new_value=body.new_value,
            reason=body.reason,
            edited_by=user_id,
        )
        return {
            "new_revision_id": new_rev.id,
            "rev_no": new_rev.rev_no,
            "content_hash": new_rev.content_hash,
            "created_via": new_rev.created_via,
        }
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)) from e


@router.post("/revisions/{revision_id}/select-answer")
async def select_answer(
    revision_id: str,
    body: SelectAnswerRequest,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    """Teacher confirms the correct answer, creating a new revision."""
    user_id = _require_auth(authorization)
    try:
        new_rev = review_service.select_answer(
            revision_id=revision_id,
            selected_key=body.selected_key,
            confirmed_by=user_id,
        )
        return {
            "new_revision_id": new_rev.id,
            "rev_no": new_rev.rev_no,
            "answer_status": new_rev.answer.get("status"),
            "content_hash": new_rev.content_hash,
        }
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)) from e


@router.post("/questions/{question_id}/merge-next")
async def merge_with_next(
    question_id: str,
    authorization: str | None = Header(default=None),
) -> dict[str, str]:
    """Merge cross-page or fragmented question with next sequential question."""
    user_id = _require_auth(authorization)
    try:
        review_service.merge_with_next(question_id=question_id, merged_by=user_id)
        return {"question_id": question_id, "status": "merged_with_next"}
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)) from e


@router.post("/questions/{question_id}/split")
async def split_question(
    question_id: str,
    body: SplitRequest,
    authorization: str | None = Header(default=None),
) -> dict[str, str]:
    """Split lumped question into two separate questions."""
    user_id = _require_auth(authorization)
    try:
        q1, q2 = review_service.split_question(
            question_id=question_id,
            split_at_block_id=body.split_at_block_id,
            split_by=user_id,
        )
        return {"question_id_1": q1, "question_id_2": q2}
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)) from e


@router.post("/questions/{question_id}/unreadable")
async def mark_unreadable(
    question_id: str,
    body: UnreadableRequest,
    authorization: str | None = Header(default=None),
) -> dict[str, str]:
    """Quarantine question because source ink is corrupted or truncated."""
    user_id = _require_auth(authorization)
    try:
        review_service.mark_source_unreadable(
            question_id=question_id,
            marked_by=user_id,
            reason=body.reason,
        )
        return {"question_id": question_id, "status": "source_unreadable"}
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)) from e


@router.post("/questions/{question_id}/restore")
async def restore_revision(
    question_id: str,
    body: RestoreRequest,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    """Safely restore a prior revision by generating a new revision matching it."""
    user_id = _require_auth(authorization)
    try:
        new_rev = review_service.restore_revision(
            question_id=question_id,
            target_revision_id=body.target_revision_id,
            restored_by=user_id,
        )
        return {
            "question_id": question_id,
            "new_revision_id": new_rev.id,
            "rev_no": new_rev.rev_no,
            "content_hash": new_rev.content_hash,
            "created_via": new_rev.created_via,
        }
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)) from e


@router.post("/questions/{question_id}/approve")
async def approve_question(
    question_id: str,
    body: ApproveRequest,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    """Approve question revision (fails if open blockers exist)."""
    user_id = _require_auth(authorization)
    try:
        approval = review_service.approve_question(question_id=question_id, teacher_id=user_id)
        return approval
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)) from e
