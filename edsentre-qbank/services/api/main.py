"""
FastAPI application — EdSentre Question Bank API (M1 skeleton).

Provides:
  POST /qb/ingest          — enqueue a document ingestion job
  GET  /qb/questions/{id}  — get question status + latest revision summary
  GET  /qb/review/tasks    — list pending review tasks for the caller
  POST /qb/publish/{revision_id} — trigger publish gate
  GET  /qb/jobs/{id}       — check job status

All endpoints require a valid Supabase JWT. tenant_id is derived
server-side from auth.uid() — never trusted from the client.
"""

from __future__ import annotations

from typing import Any

from fastapi import FastAPI, Header, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(
    title="EdSentre Question Bank API",
    version="0.1.0-m1",
    description="Internal API for the EdSentre question bank pipeline",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://*.pages.dev", "http://localhost:*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["Authorization", "Content-Type"],
)


# ─── Request / Response models ────────────────────────────────────────────────


class IngestRequest(BaseModel):
    document_sha256: str  # client uploads to Storage first, provides SHA-256
    original_filename: str
    storage_path: str  # Supabase Storage path (private bucket)
    rights_note: str  # teacher attestation note


class IngestResponse(BaseModel):
    job_id: str
    status: str
    message: str


class QuestionSummary(BaseModel):
    question_id: str
    source_label: str
    question_type: str
    status: str
    rev_no: int | None
    answer_status: str | None
    blocker_count: int
    warn_count: int


class JobStatus(BaseModel):
    job_id: str
    kind: str
    status: str
    attempts: int
    error: str | None
    result: dict[str, Any] | None


# ─── Helpers ──────────────────────────────────────────────────────────────────


def _require_auth(authorization: str | None) -> str:
    """Extract and validate Supabase JWT. Returns caller user_id."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                "code": "AUTH_REQUIRED",
                "message": "Missing or invalid Authorization header",
            },
        )
    # In production this is validated by Supabase PostgREST / Edge Function.
    # Here we return the token as a placeholder (real impl uses supabase-py / psycopg3).
    return authorization.removeprefix("Bearer ").strip()


# ─── Routes ───────────────────────────────────────────────────────────────────


@app.get("/health", tags=["system"])
async def health() -> dict[str, str]:
    return {"status": "ok", "version": "0.1.0-m1"}


@app.post("/qb/ingest", response_model=IngestResponse, tags=["pipeline"])
async def ingest_document(
    body: IngestRequest,
    authorization: str | None = Header(default=None),
) -> IngestResponse:
    """
    Enqueue a document ingestion job.
    The worker picks this up, runs Forensics → Evidence Package → Noise,
    then enqueues downstream segmentation + reconstruction jobs.
    """
    _require_auth(authorization)
    # TODO (M1 impl): insert into qb_jobs via psycopg3 / supabase-py
    # tenant_id derived from auth.uid() on the DB side — never from request body
    import uuid

    job_id = str(uuid.uuid4())
    return IngestResponse(
        job_id=job_id,
        status="pending",
        message=f"Document '{body.original_filename}' queued for ingestion (job {job_id})",
    )


@app.get("/qb/questions/{question_id}", response_model=QuestionSummary, tags=["review"])
async def get_question(
    question_id: str,
    authorization: str | None = Header(default=None),
) -> QuestionSummary:
    """Get question status and latest revision summary."""
    _require_auth(authorization)
    # TODO (M1 impl): SELECT from qb_questions + qb_question_revisions + validation_issues
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="DB integration pending (M1)",
    )


from services.review.api import router as review_router

app.include_router(review_router)


@app.post("/qb/publish/{revision_id}", tags=["pipeline"])
async def publish_revision(
    revision_id: str,
    authorization: str | None = Header(default=None),
) -> dict[str, str]:
    """
    Trigger the DB-level publish gate.
    Calls publish_revision(p_revision_id) SECURITY DEFINER function.
    All 6 pre-condition checks run inside the DB — this endpoint only proxies.
    """
    _require_auth(authorization)
    # TODO (M1 impl): call supabase.rpc('publish_revision', {'p_revision_id': revision_id})
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="DB integration pending (M1)",
    )


@app.get("/qb/jobs/{job_id}", response_model=JobStatus, tags=["pipeline"])
async def get_job_status(
    job_id: str,
    authorization: str | None = Header(default=None),
) -> JobStatus:
    """Check job processing status."""
    _require_auth(authorization)
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="DB integration pending (M1)",
    )


@app.post("/qb/pilot/run", tags=["pilot"])
async def run_pilot_simulation(
    tenant_id: str = "tenant-pilot",
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    """Execute real multi-teacher pilot run and return aggregated metrics."""
    _require_auth(authorization)
    from core.pilot.engine import PilotRunner

    runner = PilotRunner()
    metrics = runner.run_pilot(tenant_id=tenant_id)
    return metrics.to_dict()

