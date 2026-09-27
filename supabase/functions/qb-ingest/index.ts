/**
 * Edge Function: qb-ingest
 * ========================
 * يستقبل ملف PDF من Flutter (multipart/form-data),
 * يرفعه إلى Supabase Storage (bucket: qb-documents),
 * يُنشئ سجل في qb_documents + job في qb_jobs,
 * ويعيد { job_id, document_id }.
 *
 * الأمان:
 *   - JWT مطلوب → يستخرج user_id + tenant_id من auth.uid()
 *   - Service Role Key لا تُرسَل أبداً من Flutter
 *   - tenant_id مشتق من DB، لا من الـ request
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { crypto } from "https://deno.land/std@0.208.0/crypto/mod.ts";
import { encodeHex } from "https://deno.land/std@0.208.0/encoding/hex.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const PIPELINE_VERSION = "1.0.0-reconstruct";
const STORAGE_BUCKET = "qb-documents";

Deno.serve(async (req: Request) => {
  // ── CORS preflight ──────────────────────────────────────────────────────────
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, content-type",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
      },
    });
  }

  if (req.method !== "POST") {
    return jsonError("METHOD_NOT_ALLOWED", "Only POST is accepted", 405);
  }

  // ── Auth: استخرج user من JWT ────────────────────────────────────────────────
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonError("AUTH_REQUIRED", "Missing Authorization header", 401);
  }
  const userJwt = authHeader.replace("Bearer ", "").trim();

  // عميل بصلاحية المستخدم (لاستخراج user_id)
  const userClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${userJwt}` } },
    auth: { persistSession: false },
  });

  const { data: { user }, error: authErr } = await userClient.auth.getUser();
  if (authErr || !user) {
    return jsonError("AUTH_REQUIRED", "Invalid or expired token", 401);
  }

  // عميل service_role لعمليات DB
  const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });

  // ── استخرج tenant_id من DB ──────────────────────────────────────────────────
  const { data: userRow, error: userErr } = await adminClient
    .from("users")
    .select("tenant_id, role")
    .eq("id", user.id)
    .single();

  if (userErr || !userRow) {
    return jsonError("NOT_AUTHORIZED", "User not found in system", 403);
  }
  if (userRow.role !== "teacher") {
    return jsonError("NOT_AUTHORIZED", "Only teachers can ingest documents", 403);
  }

  const tenantId: string = userRow.tenant_id;

  // ── اقرأ الـ multipart form ──────────────────────────────────────────────────
  let formData: FormData;
  try {
    formData = await req.formData();
  } catch {
    return jsonError("VALIDATION_ERROR", "Request must be multipart/form-data", 400);
  }

  const fileEntry = formData.get("file");
  if (!fileEntry || !(fileEntry instanceof File)) {
    return jsonError("VALIDATION_ERROR", "Missing 'file' field in form data", 400);
  }

  const rightsNote = formData.get("rights_note")?.toString() ?? "Teacher attested";
  const answerKeyFilename = formData.get("answer_key_filename")?.toString() ?? null;

  const fileBytes = new Uint8Array(await fileEntry.arrayBuffer());
  const filename = fileEntry.name;

  // ── احسب SHA-256 ─────────────────────────────────────────────────────────────
  const hashBuffer = await crypto.subtle.digest("SHA-256", fileBytes);
  const fileSha = encodeHex(new Uint8Array(hashBuffer));

  // ── تحديد Content-Type المناسب بدقة لتجنب رفض Storage ─────────────────────
  let contentType = fileEntry.type;
  if (!contentType || contentType === "application/octet-stream") {
    const ext = filename.split(".").pop()?.toLowerCase();
    if (ext === "pdf") {
      contentType = "application/pdf";
    } else if (ext === "docx") {
      contentType = "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
    } else if (ext === "doc") {
      contentType = "application/msword";
    } else {
      contentType = "application/pdf";
    }
  }

  // ── ارفع إلى Storage (bucket: qb-documents, private) ────────────────────────
  const storagePath = `${tenantId}/${fileSha}/${filename}`;

  const { error: uploadErr } = await adminClient.storage
    .from(STORAGE_BUCKET)
    .upload(storagePath, fileBytes, {
      contentType: contentType,
      upsert: true,
    });

  if (uploadErr) {
    console.error("Storage upload error:", uploadErr);
    return jsonError("STORAGE_ERROR", `Failed to upload file: ${uploadErr.message}`, 500);
  }

  // ── أنشئ/حدّث سجل qb_documents ──────────────────────────────────────────────
  const { data: docRow, error: docErr } = await adminClient
    .from("qb_documents")
    .upsert(
      {
        tenant_id: tenantId,
        sha256: fileSha,
        original_filename: filename,
        mime: contentType,
        size_bytes: fileBytes.byteLength,
        storage_path: storagePath,
        uploader_id: user.id,
        rights_attestation: {
          claimed_source: filename,
          license: "teacher_attested",
          uploader_note: rightsNote,
          attested_at: new Date().toISOString(),
        },
        status: "pending",
        pipeline_version: PIPELINE_VERSION,
      },
      { onConflict: "tenant_id,sha256" }
    )
    .select("id, status")
    .single();

  if (docErr || !docRow) {
    console.error("qb_documents upsert error:", docErr);
    return jsonError("DB_ERROR", "Failed to register document", 500);
  }

  const documentId: string = docRow.id;

  // ── إذا كان المستند معالجاً مسبقاً، أعد الأسئلة الموجودة ────────────────────
  if (docRow.status === "done") {
    const { data: existingJobs } = await adminClient
      .from("qb_jobs")
      .select("id, status")
      .eq("payload->document_id", documentId)
      .order("created_at", { ascending: false })
      .limit(1);

    if (existingJobs && existingJobs.length > 0) {
      return jsonOk({
        job_id: existingJobs[0].id,
        document_id: documentId,
        status: "already_processed",
        message: "Document already processed. Questions are available.",
      });
    }
  }

  // ── أنشئ Job في قائمة الانتظار ───────────────────────────────────────────────
  const cacheKey = `ingest_document:${PIPELINE_VERSION}:${fileSha}`;

  const { data: jobRow, error: jobErr } = await adminClient
    .from("qb_jobs")
    .upsert(
      {
        tenant_id: tenantId,
        kind: "ingest_document",
        payload: {
          document_id: documentId,
          storage_path: storagePath,
          tenant_id: tenantId,
          uploader_id: user.id,
          original_filename: filename,
          answer_key_filename: answerKeyFilename,
          sha256: fileSha,
        },
        status: "pending",
        error: null,
        attempts: 0,
        locked_by: null,
        locked_at: null,
        run_after: new Date().toISOString(),
        cache_key: cacheKey,
      },
      { onConflict: "cache_key" }
    )
    .select("id, status")
    .single();

  if (jobErr || !jobRow) {
    console.error("qb_jobs upsert error:", jobErr);
    return jsonError("DB_ERROR", "Failed to enqueue job", 500);
  }

  return jsonOk({
    job_id: jobRow.id,
    document_id: documentId,
    status: jobRow.status,
    message: `Document '${filename}' queued for processing.`,
  });
});

// ─── Helpers ──────────────────────────────────────────────────────────────────

function jsonOk(body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}

function jsonError(code: string, message: string, status: number): Response {
  return new Response(JSON.stringify({ code, message }), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}
