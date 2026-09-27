"""
Python Worker — EdSentre QBank Pipeline
========================================
حلقة دائمة تستطلع qb_jobs عبر SELECT…FOR UPDATE SKIP LOCKED.
لكل job من نوع 'ingest_document':
  1. يُنزّل PDF من Supabase Storage
  2. يُشغّل Pipeline الحقيقي: PDF Adapter → Noise → Structure → Segmenter → Reconstructor → AnswerEngine
  3. يُدرج النتائج في qb_questions + qb_question_revisions + qb_validation_runs
  4. يُحدّث qb_documents.status = 'done'
  5. يُسجّل complete_job أو fail_job
"""

from __future__ import annotations

import hashlib
import json
import logging
import os
import socket
import sys
import tempfile
import time
import uuid
from pathlib import Path
from typing import Any

import requests

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    stream=sys.stdout,
)
logger = logging.getLogger("qb_worker")

# ── Config من environment ────────────────────────────────────────────────────
SUPABASE_URL = os.environ["SUPABASE_URL"].rstrip("/")
SERVICE_ROLE_KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
PIPELINE_VERSION = "1.0.0-reconstruct"
POLL_INTERVAL_SECS = int(os.environ.get("WORKER_POLL_INTERVAL", "5"))
WORKER_ID = os.environ.get("WORKER_ID", f"worker-{socket.gethostname()}-{os.getpid()}")

HEADERS = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation",
}

# ── Supabase helpers ──────────────────────────────────────────────────────────

def sb_rpc(func: str, params: dict[str, Any]) -> dict[str, Any]:
    """يستدعي Supabase RPC function."""
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/{func}",
        headers=HEADERS,
        json=params,
        timeout=15,
    )
    r.raise_for_status()
    if not r.text or not r.text.strip():
        return {}
    try:
        data = r.json()
    except Exception:
        return {}
    if isinstance(data, list):
        return data[0] if data else {}
    return data or {}


def sb_insert(table: str, row: dict[str, Any]) -> dict[str, Any]:
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/{table}",
        headers={**HEADERS, "Prefer": "return=representation"},
        json=row,
        timeout=15,
    )
    r.raise_for_status()
    data = r.json()
    return data[0] if isinstance(data, list) and data else {}


def sb_update(table: str, row_id: str, values: dict[str, Any]) -> None:
    r = requests.patch(
        f"{SUPABASE_URL}/rest/v1/{table}?id=eq.{row_id}",
        headers={**HEADERS, "Prefer": "return=minimal"},
        json=values,
        timeout=15,
    )
    r.raise_for_status()


def sb_download_storage(bucket: str, path: str) -> bytes:
    """يُنزّل ملفاً من Supabase Storage باستخدام service_role."""
    r = requests.get(
        f"{SUPABASE_URL}/storage/v1/object/{bucket}/{path}",
        headers={
            "apikey": SERVICE_ROLE_KEY,
            "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        },
        timeout=60,
    )
    r.raise_for_status()
    return r.content


def sb_upload_storage(bucket: str, path: str, data: bytes, mime: str = "image/png") -> None:
    """يرفع ملفاً إلى Supabase Storage باستخدام service_role."""
    r = requests.post(
        f"{SUPABASE_URL}/storage/v1/object/{bucket}/{path}",
        headers={
            "apikey": SERVICE_ROLE_KEY,
            "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
            "Content-Type": mime,
            "x-upsert": "true",
        },
        data=data,
        timeout=30,
    )
    r.raise_for_status()


# ── Pipeline الحقيقي ──────────────────────────────────────────────────────────

def run_pipeline(pdf_bytes: bytes, payload: dict[str, Any]) -> list[dict[str, Any]]:
    """
    يُشغّل الـ Pipeline الكامل مع طبقة الذكاء الاصطناعي البصري.

    المراحل:
      1. PDF → Segmenter (استخراج الأسئلة)
      2. لكل سؤال: قص الصور → VisionEnricher (AI) → نص نظيف أو figure
      3. Reconstructor → QuestionRevisionContent
      4. حفظ الصور الحقيقية فقط في Storage (ليس النصوص المتنكرة في صور)
    """
    document_id: str = payload["document_id"]
    tenant_id: str = payload["tenant_id"]
    filename: str = payload.get("original_filename", "document.pdf")

    # اكتب PDF لملف مؤقت (PyMuPDF يحتاج مسار)
    with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp:
        tmp.write(pdf_bytes)
        tmp_path = Path(tmp.name)

    try:
        from core.pdf.adapter import PdfDocumentAdapter
        from core.segmentation.segmenter import OptionsTerminatedSegmenter
        from core.reconstruct.text_native import NativeTextReconstructor
        from core.answers.solver import DeterministicSolver
        from core.ai.vision_enricher import VisionEnricher

        adapter = PdfDocumentAdapter(tmp_path)
        segmenter = OptionsTerminatedSegmenter(adapter)
        reconstructor = NativeTextReconstructor(adapter)

        # 🧠 تهيئة محرك الذكاء الاصطناعي البصري (Singleton per pipeline run)
        vision_enricher = VisionEnricher()
        ai_enabled = vision_enricher.is_enabled
        active_model = os.environ.get("GEMINI_MODEL", "Gemini 3.8 Flash")
        logger.info(
            "VisionEnricher: %s",
            f"ACTIVE ({active_model})" if ai_enabled else "DISABLED (no API key)",
        )

        # استخرج الأسئلة
        segmented_questions = segmenter.segment_document(document_id=document_id)
        logger.info("Segmented %d questions from '%s'", len(segmented_questions), filename)

        results: list[dict[str, Any]] = []

        for sq in segmented_questions:
            # ── مرحلة 1: قص كل الصور وتحليلها بالذكاء الاصطناعي ─────────────
            # crop_bytes_map: crop_path → PNG bytes (للـ VisionEnricher)
            crop_bytes_map: dict[str, bytes] = {}
            # crops_to_upload: crop_path → PNG bytes (فقط الصور الحقيقية)
            crops_to_upload: dict[str, bytes] = {}

            for img_idx, img in enumerate(sq.images):
                crop_path = f"crops/{document_id}/q{sq.ordinal}_img{img_idx + 1}.png"
                try:
                    p_no = (
                        img.slices[0].page_no
                        if img.slices
                        else (sq.pages[0] - 1 if sq.pages else 0)
                    )
                    crop_bytes = adapter.render_crop(p_no, img.bbox, dpi=200)
                    crop_bytes_map[crop_path] = crop_bytes
                except Exception as exc:
                    logger.warning(
                        "Failed to render crop for Q%d img%d: %s", sq.ordinal, img_idx + 1, exc
                    )

            # ── مرحلة 2: الإعادة التركيبية (Reconstruction) ──────────────────
            revision_content = reconstructor.reconstruct(sq)
            content_dict = revision_content.model_dump()

            # ── مرحلة 3: الإثراء بالذكاء الاصطناعي البصري ───────────────────
            # يُطبَّق على stem blocks فقط (الخيارات هي نصوص بالفعل)
            if ai_enabled and crop_bytes_map:
                original_stem = content_dict.get("stem", [])
                enriched_stem = vision_enricher.enrich_stem_blocks(
                    stem_blocks=original_stem,
                    crop_bytes_map=crop_bytes_map,
                )
                content_dict["stem"] = enriched_stem

                # تحديد الصور التي يجب رفعها فعلاً (الـ figures الحقيقية فقط)
                for block in enriched_stem:
                    if block.get("type") == "asset":
                        cp = block.get("crop_asset") or block.get("value", "")
                        if cp and cp in crop_bytes_map:
                            crops_to_upload[cp] = crop_bytes_map[cp]

                # إحصاءات للـ logs
                original_assets = sum(
                    1 for b in original_stem if b.get("type") == "asset"
                )
                remaining_assets = sum(
                    1 for b in enriched_stem if b.get("type") == "asset"
                )
                converted = original_assets - remaining_assets
                if converted > 0:
                    logger.info(
                        "Q%d: AI converted %d/%d images → clean text.",
                        sq.ordinal, converted, original_assets,
                    )
                    # أضف flag في الـ content
                    content_dict.setdefault("flags", []).append(
                        f"ai_enriched:{converted}_images_to_text"
                    )
            else:
                # بدون AI: ارفع كل الصور كما هي
                crops_to_upload = crop_bytes_map

            # ── مرحلة 4: رفع الـ crops الحقيقية فقط إلى Storage ─────────────
            for crop_path, crop_bytes in crops_to_upload.items():
                try:
                    sb_upload_storage("qb-documents", crop_path, crop_bytes, "image/png")
                    logger.info(
                        "Uploaded figure crop: %s (%d bytes)", crop_path, len(crop_bytes)
                    )
                except Exception as exc:
                    logger.warning("Failed to upload crop '%s': %s", crop_path, exc)

            # ── مرحلة 5: بناء النتيجة النهائية ──────────────────────────────
            # الإجابة: دائماً unknown — المدرس يختارها بنفسه
            answer_state: dict[str, Any] = {
                "status": "unknown",
                "raw": None,
                "normalized": None,
            }

            content_json = json.dumps(content_dict, sort_keys=True)
            content_hash = hashlib.sha256(content_json.encode()).hexdigest()

            results.append({
                "source_label": sq.source_label,
                "question_type": sq.question_type,
                "content": content_dict,
                "answer": answer_state,
                "content_hash": content_hash,
                "confidence": content_dict.get("confidence", {}),
                "flags": content_dict.get("flags", []),
                "pages": sq.pages,
            })

        adapter.close()
        return results

    finally:
        tmp_path.unlink(missing_ok=True)


# ── إدراج نتائج Pipeline في DB ────────────────────────────────────────────────

def persist_questions(
    results: list[dict[str, Any]],
    payload: dict[str, Any],
) -> int:
    """يُدرج الأسئلة والـrevisions في Supabase DB. يعيد عدد الأسئلة المُدرجة."""
    document_id: str = payload["document_id"]
    tenant_id: str = payload["tenant_id"]
    uploader_id: str = payload.get("uploader_id", "")
    filename: str = payload.get("original_filename", "document.pdf")

    # أنشئ section واحد لهذه الوثيقة
    clean_title = Path(filename).stem.replace("_", " ")
    section = sb_insert("qb_exam_sections", {
        "document_id": document_id,
        "tenant_id": tenant_id,
        "label": f"Module 1 ({clean_title})",
        "ordinal": 1,
    })
    section_id: str = section.get("id", "")

    inserted = 0
    for rev_data in results:
        try:
            # أدرج السؤال
            q_row = sb_insert("qb_questions", {
                "tenant_id": tenant_id,
                "document_id": document_id,
                "section_id": section_id or None,
                "source_label": rev_data["source_label"],
                "question_type": rev_data["question_type"],
                "status": "extracted",
                "priority_score": 3.5,
                "policy_state": "REVIEW_FAST",
            })
            question_id: str = q_row.get("id", "")
            if not question_id:
                continue

            # أدرج revision
            rev_row = sb_insert("qb_question_revisions", {
                "question_id": question_id,
                "tenant_id": tenant_id,
                "rev_no": 1,
                "content": rev_data["content"],
                "answer": rev_data["answer"],
                "confidence": rev_data["confidence"],
                "provenance": {
                    "stage": "reconstruct",
                    "source": filename,
                    "pages": rev_data["pages"],
                    "pipeline_version": PIPELINE_VERSION,
                    "flags": rev_data.get("flags", []),
                },
                "content_hash": rev_data["content_hash"],
                "created_by": uploader_id or None,
                "created_via": "pipeline",
            })
            revision_id: str = rev_row.get("id", "")

            if revision_id:
                # أدرج validation_run فارغ
                run_row = sb_insert("qb_validation_runs", {
                    "revision_id": revision_id,
                    "tenant_id": tenant_id,
                    "pipeline_version": PIPELINE_VERSION,
                })
                inserted += 1

        except Exception as exc:
            logger.error("Failed to persist Q '%s': %s", rev_data["source_label"], exc)
            continue

    return inserted


# ── معالج الـ Job ────────────────────────────────────────────────────────────

def handle_ingest_document(job: dict[str, Any]) -> dict[str, Any]:
    payload: dict[str, Any] = job.get("payload", {})
    storage_path: str = payload["storage_path"]
    document_id: str = payload["document_id"]

    logger.info("Downloading PDF from storage: %s", storage_path)
    pdf_bytes = sb_download_storage("qb-documents", storage_path)
    logger.info("Downloaded %d bytes", len(pdf_bytes))

    # شغّل pipeline
    results = run_pipeline(pdf_bytes, payload)

    # ادرج في DB
    inserted = persist_questions(results, payload)

    # حدّث qb_documents.status = done
    sb_update("qb_documents", document_id, {
        "status": "done",
        "page_count": len({p for r in results for p in r.get("pages", [])}),
    })

    return {
        "questions_extracted": len(results),
        "questions_inserted": inserted,
        "document_id": document_id,
    }


HANDLERS = {
    "ingest_document": handle_ingest_document,
}


# ── Main Loop ────────────────────────────────────────────────────────────────

def main() -> None:
    logger.info("Worker started: %s", WORKER_ID)
    logger.info("Supabase URL: %s", SUPABASE_URL)

    while True:
        try:
            job = sb_rpc("claim_next_job", {"p_worker_id": WORKER_ID})

            if not job or not job.get("id"):
                time.sleep(POLL_INTERVAL_SECS)
                continue

            job_id: str = job["id"]
            kind: str = job["kind"]
            logger.info("Claimed job %s (kind=%s)", job_id, kind)

            handler = HANDLERS.get(kind)
            if handler is None:
                sb_rpc("fail_job", {
                    "p_job_id": job_id,
                    "p_error": f"No handler for kind '{kind}'",
                    "p_retry": False,
                })
                continue

            try:
                result = handler(job)
                sb_rpc("complete_job", {
                    "p_job_id": job_id,
                    "p_result": result,
                })
                logger.info("Job %s completed: %s", job_id, result)

            except Exception as exc:
                logger.exception("Job %s failed: %s", job_id, exc)
                attempts = job.get("attempts", 1)
                max_attempts = job.get("max_attempts", 3)
                sb_rpc("fail_job", {
                    "p_job_id": job_id,
                    "p_error": str(exc),
                    "p_retry": attempts < max_attempts,
                })

        except Exception as exc:
            logger.error("Worker loop error: %s", exc)
            time.sleep(POLL_INTERVAL_SECS * 2)


if __name__ == "__main__":
    main()
