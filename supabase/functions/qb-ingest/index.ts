/**
 * Edge Function: qb-ingest  (v2 — Direct Extraction)
 * ====================================================
 * الفرق عن v1:
 *   v1: كانت تنشئ job فقط وتنتظر worker خارجي (لم يكن موجوداً)
 *   v2: ترفع الملف + تستخرج الأسئلة بـ Gemini Flash + تحفظها في DB + ترد فوراً
 *
 * التدفق:
 *   Flutter → POST multipart/form-data (file + rights_note)
 *     ↓
 *   1. Auth + tenant_id من DB
 *   2. SHA-256 للملف → تحقق من معالجة مسبقة (إن وُجدت أعد الأسئلة فوراً)
 *   3. رفع إلى Storage (qb-documents bucket)
 *   4. إنشاء/تحديث سجل qb_documents
 *   5. إرسال الملف إلى Gemini Flash 2.0 لاستخراج الأسئلة
 *   6. حفظ الأسئلة في qb_questions + qb_question_revisions
 *   7. تحديث qb_documents status → 'done'
 *   8. الرد بالأسئلة المستخرجة مباشرة
 *
 * الأمان:
 *   - JWT مطلوب → يستخرج user_id من auth.uid()
 *   - tenant_id مشتق من DB دائماً
 *   - GEMINI_API_KEY في Supabase Secrets فقط
 *   - Service Role Key لا تُرسل من Flutter أبداً
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { crypto } from "https://deno.land/std@0.208.0/crypto/mod.ts";
import { encodeHex } from "https://deno.land/std@0.208.0/encoding/hex.ts";
import { encodeBase64 } from "https://deno.land/std@0.208.0/encoding/base64.ts";
import { jsonrepair } from "https://esm.sh/jsonrepair@3.4.0";

// ── Environment Variables ────────────────────────────────────────────────────
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";

const PIPELINE_VERSION = "2.0.0-gemini-direct";
const STORAGE_BUCKET = "qb-documents";

// gemini-flash-latest — مجاني + يدعم الـ PDF مباشرة
const GEMINI_MODEL = "gemini-flash-latest";
const GEMINI_API_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`;

// ── Main Handler ─────────────────────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  // CORS preflight
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

  // ── 1. Auth: استخرج user من JWT ─────────────────────────────────────────────
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonError("AUTH_REQUIRED", "Missing Authorization header", 401);
  }
  const userJwt = authHeader.replace("Bearer ", "").trim();

  const userClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${userJwt}` } },
    auth: { persistSession: false },
  });

  const { data: { user }, error: authErr } = await userClient.auth.getUser();
  if (authErr || !user) {
    return jsonError("AUTH_REQUIRED", "Invalid or expired token", 401);
  }

  const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });

  // ── 2. استخرج tenant_id + تحقق من الدور ─────────────────────────────────────
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

  // ── 3. اقرأ الـ multipart form ───────────────────────────────────────────────
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

  // ── 4. احسب SHA-256 ──────────────────────────────────────────────────────────
  const hashBuffer = await crypto.subtle.digest("SHA-256", fileBytes);
  const fileSha = encodeHex(new Uint8Array(hashBuffer));

  // ── 5. تحديد Content-Type ───────────────────────────────────────────────────
  let contentType = fileEntry.type;
  if (!contentType || contentType === "application/octet-stream") {
    const ext = filename.split(".").pop()?.toLowerCase();
    contentType = ext === "pdf" ? "application/pdf"
      : ext === "docx" ? "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      : ext === "doc" ? "application/msword"
      : "application/pdf";
  }

  // ── 6. تحقق من معالجة مسبقة (نفس الملف برفع سابق) ─────────────────────────
  const { data: existingDoc } = await adminClient
    .from("qb_documents")
    .select("id, status")
    .eq("tenant_id", tenantId)
    .eq("sha256", fileSha)
    .maybeSingle();

  if (existingDoc?.status === "done") {
    // الملف معالج سابقاً — جلب الأسئلة الموجودة وإعادتها فوراً
    const { data: existingQs } = await adminClient
      .from("qb_questions")
      .select("*")
      .eq("document_id", existingDoc.id)
      .order("created_at", { ascending: true });

    return jsonOk({
      document_id: existingDoc.id,
      status: "already_processed",
      questions: existingQs ?? [],
      message: "Document already processed. Returning existing questions.",
    });
  }

  // ── 7. رفع إلى Storage ───────────────────────────────────────────────────────
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

  // ── 8. أنشئ/حدّث سجل qb_documents ───────────────────────────────────────────
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
        status: "processing",
        pipeline_version: PIPELINE_VERSION,
      },
      { onConflict: "tenant_id,sha256" }
    )
    .select("id")
    .single();

  if (docErr || !docRow) {
    console.error("qb_documents upsert error:", docErr);
    return jsonError("DB_ERROR", "Failed to register document", 500);
  }

  const documentId: string = docRow.id;

  if (!GEMINI_API_KEY) {
    await adminClient.from("qb_documents").update({ status: "pending" }).eq("id", documentId);
    return jsonError("CONFIG_ERROR", "GEMINI_API_KEY is not configured.", 500);
  }

  // ── 9. معالجة في الخلفية مع إعادة محاولة تلقائية (Auto-Retry) ──────────────
  const processBackground = async () => {
    let extractedQuestions: ExtractedQuestion[] = [];
    let success = false;
    let lastError = null;

    // محاولة الاستخراج حتى 4 مرات بين كل محاولة دقيقة (لتخطي أخطاء 503)
    for (let attempt = 1; attempt <= 4; attempt++) {
      try {
        extractedQuestions = await extractQuestionsWithGemini(fileBytes, filename, answerKeyFilename);
        success = true;
        break; // نجاح! اخرج من حلقة المحاولة
      } catch (err: any) {
        lastError = err;
        console.warn(`Extraction attempt ${attempt} failed:`, err.message);
        
        // إذا كان الخطأ 503 أو 429 (High Demand)، انتظر دقيقة وجرب مرة أخرى
        if (err.message.includes("503") || err.message.includes("429") || err.message.includes("UNAVAILABLE")) {
          if (attempt < 4) {
            console.log(`Waiting 60 seconds before attempt ${attempt + 1}...`);
            await new Promise(r => setTimeout(r, 60000));
          }
        } else {
          // إذا كان خطأ آخر غير الضغط على السيرفر (مثل JSON معطوب تماماً)، لا داعي للانتظار
          break;
        }
      }
    }

    if (!success) {
      console.error("All extraction attempts failed. Last error:", lastError);
      await adminClient.from("qb_documents").update({ status: "failed" }).eq("id", documentId);
      return;
    }

    if (extractedQuestions.length === 0) {
      await adminClient.from("qb_documents").update({ status: "failed" }).eq("id", documentId);
      return;
    }

    // ── 10. احفظ الأسئلة في DB ───────────────────────────────────────────────────
    const savedQuestions: Record<string, unknown>[] = [];
    for (let i = 0; i < extractedQuestions.length; i++) {
      const q = extractedQuestions[i];

      const { data: qRow, error: qErr } = await adminClient
        .from("qb_questions")
        .insert({
          tenant_id: tenantId,
          document_id: documentId,
          source_label: `Q${i + 1} — ${filename}`,
          question_type: q.questionType,
          status: "review_required",
          priority_score: q.confidence ?? 0.8,
          policy_state: "REVIEW_FAST",
        })
        .select("id")
        .single();

      if (qErr || !qRow) continue;
      const questionId: string = qRow.id;

      const stemBlocks = buildStemBlocks(q.stem);
      const optionsList = buildOptions(q.options);

      const content = {
        stem: stemBlocks,
        question_type: q.questionType,
        options: optionsList,
        language: detectLanguage(q.stem),
        direction: detectLanguage(q.stem) === "ar" ? "rtl" : "ltr",
      };

      const contentStr = JSON.stringify(content);
      const contentHashBuf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(contentStr));
      const contentHash = encodeHex(new Uint8Array(contentHashBuf));

      const answer = {
        status: q.answerStatus,
        raw: q.correctAnswer ?? null,
        normalized: q.correctAnswer ?? null,
        conflict: q.answerConflict ?? false,
        source_ref: answerKeyFilename ? "answer_key_file" : "extracted_from_exam",
      };

      const confidence = {
        boundary: q.confidence ?? 0.8,
        text: q.textConfidence ?? 0.9,
        answer: q.answerConfidence ?? (q.correctAnswer ? 0.9 : 0.3),
      };

      await adminClient.from("qb_question_revisions").insert({
        question_id: questionId,
        tenant_id: tenantId,
        rev_no: 1,
        content: content,
        answer: answer,
        confidence: confidence,
        provenance: {
          stage: "ai_extraction",
          model: GEMINI_MODEL,
          pipeline_version: PIPELINE_VERSION,
          source_file: filename,
        },
        content_hash: contentHash,
        created_by: user.id,
        created_via: "ai_ingest",
      });

      savedQuestions.push({ id: questionId });
    }

    // ── 11. حدّث qb_documents status → done ─────────────────────────────────────
    await adminClient.from("qb_documents").update({ status: "done" }).eq("id", documentId);

    // ── 12. أضف job سجلاً للمرجعية (اختياري) ──────────────────────────────────
    const cacheKey = `ingest_document:${PIPELINE_VERSION}:${fileSha}`;
    await adminClient.from("qb_jobs").upsert(
      {
        tenant_id: tenantId,
        kind: "ingest_document",
        payload: { document_id: documentId, storage_path: storagePath, sha256: fileSha },
        status: "done",
        attempts: 1,
        cache_key: cacheKey,
      },
      { onConflict: "cache_key" }
    );
  };

  // تمرير عملية الخلفية لتعمل بعد إرسال الرد السريع
  // @ts-ignore: EdgeRuntime is specific to Supabase Deno environment
  if (typeof EdgeRuntime !== 'undefined' && typeof EdgeRuntime.waitUntil === 'function') {
    EdgeRuntime.waitUntil(processBackground());
  } else {
    // Fallback for local development or unsupported environments
    processBackground().catch(console.error);
  }

  // ── الرد الفوري للتطبيق (Synchronous Return, Async Background) ───────────
  return jsonOk({
    document_id: documentId,
    status: "processing",
    message: "جاري معالجة الامتحان، سنرسل لك إشعاراً عند الانتهاء",
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// Gemini Extraction Logic
// ═══════════════════════════════════════════════════════════════════════════════

interface ExtractedQuestion {
  stem: string;
  questionType: "multiple_choice" | "true_false";
  options: Array<{ key: string; text: string }>;
  correctAnswer: string | null;
  answerStatus: "teacher_confirmed" | "missing" | "conflict";
  answerConflict: boolean;
  confidence: number;
  textConfidence: number;
  answerConfidence: number;
}

async function extractQuestionsWithGemini(
  fileBytes: Uint8Array,
  filename: string,
  _answerKeyFilename: string | null
): Promise<ExtractedQuestion[]> {
  const base64File = encodeBase64(fileBytes);
  const ext = filename.split(".").pop()?.toLowerCase() ?? "pdf";
  const mimeType = ext === "pdf" ? "application/pdf"
    : ext === "docx" ? "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    : "application/pdf";

  const prompt = `You are an expert exam question extractor for academic multiple-choice exams (SAT, ACT, EST style).

Analyze this document and extract ALL multiple-choice or true/false questions.

CRITICAL RULES:
1. Extract EVERY question — do not skip any.
2. For each question, identify:
   - The question stem (full text, including any math formulas — use LaTeX notation like $x^2$ for math)
   - All answer options (A, B, C, D or True/False)
   - The correct answer IF it appears in the document (e.g., answer key, marked answers)
3. If the answer is NOT in the document, set "correct_answer" to null.
4. Preserve the original language (Arabic or English) exactly.
5. For math: use LaTeX inside dollar signs, e.g., $\\frac{1}{2}$, $x^2 + y^2 = z^2$.

Return a JSON array with this exact structure (no markdown, pure JSON):
[
  {
    "stem": "The full question text here",
    "question_type": "multiple_choice",
    "options": [
      {"key": "A", "text": "First option"},
      {"key": "B", "text": "Second option"},
      {"key": "C", "text": "Third option"},
      {"key": "D", "text": "Fourth option"}
    ],
    "correct_answer": "A",
    "confidence": 0.95
  }
]

For true/false questions use question_type "true_false" with options [{"key":"True","text":"True"},{"key":"False","text":"False"}].
If no answer found, set "correct_answer": null and "confidence" lower (0.6-0.8).`;

  const requestBody = {
    contents: [
      {
        parts: [
          {
            inline_data: {
              mime_type: mimeType,
              data: base64File,
            },
          },
          { text: prompt },
        ],
      },
    ],
    generationConfig: {
      temperature: 0.1,
      topP: 0.8,
      maxOutputTokens: 8192,
      responseMimeType: "application/json",
    },
  };

  const geminiRes = await fetch(GEMINI_API_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(requestBody),
  });

  if (!geminiRes.ok) {
    const errText = await geminiRes.text();
    throw new Error(`Gemini API error ${geminiRes.status}: ${errText}`);
  }

  const geminiData = await geminiRes.json() as {
    candidates?: Array<{
      content?: { parts?: Array<{ text?: string }> };
    }>;
  };

  const rawText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text ?? "";

  if (!rawText) {
    throw new Error("Gemini returned empty response");
  }

  // استخرج الـ JSON من النص - في حال وجود Markdown
  let cleanJson = rawText.trim();
  if (cleanJson.startsWith('```json')) {
    cleanJson = cleanJson.replace(/^```json/, '').replace(/```$/, '').trim();
  } else if (cleanJson.startsWith('```')) {
    cleanJson = cleanJson.replace(/^```/, '').replace(/```$/, '').trim();
  }

  // محاولة تنظيف الأخطاء الشائعة في الـ JSON (مثل الفاصلة الزائدة في النهاية)
  cleanJson = cleanJson.replace(/,\s*([\]}])/g, '$1');

  let parsed: Array<{
    stem: string;
    question_type?: string;
    options?: Array<{ key: string; text: string }>;
    correct_answer?: string | null;
    confidence?: number;
  }>;

  try {
    parsed = JSON.parse(cleanJson);
  } catch (e) {
    console.warn(`Initial JSON parse failed: ${e}. Attempting jsonrepair...`);
    try {
      const repairedJson = jsonrepair(cleanJson);
      parsed = JSON.parse(repairedJson);
    } catch (repairErr) {
      throw new Error(`Failed to parse Gemini JSON (even after repair): ${e} | Repair error: ${repairErr}`);
    }
  }

  if (!Array.isArray(parsed) || parsed.length === 0) {
    throw new Error("Gemini returned empty questions array");
  }

  return parsed.map((q) => {
    const correctAnswer = q.correct_answer ?? null;
    const answerStatus: ExtractedQuestion["answerStatus"] = correctAnswer
      ? "teacher_confirmed"
      : "missing";

    return {
      stem: q.stem ?? "",
      questionType: q.question_type === "true_false" ? "true_false" : "multiple_choice",
      options: q.options ?? [],
      correctAnswer: correctAnswer,
      answerStatus,
      answerConflict: false,
      confidence: q.confidence ?? 0.8,
      textConfidence: q.confidence ?? 0.85,
      answerConfidence: correctAnswer ? (q.confidence ?? 0.85) : 0.2,
    };
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Content Builders
// ═══════════════════════════════════════════════════════════════════════════════

function buildStemBlocks(stemText: string): Array<Record<string, unknown>> {
  if (!stemText?.trim()) {
    return [{ id: "b1", type: "text", value: " ", source_refs: ["ai_ingest"] }];
  }

  // تقسيم الـ stem لكتل نص/رياضيات
  const blocks: Array<Record<string, unknown>> = [];
  let blockIdx = 1;

  // نمط للكشف عن LaTeX: $...$ أو $$...$$
  const parts = stemText.split(/(\$\$?[^$]+\$\$?)/g);

  for (const part of parts) {
    if (!part.trim()) continue;

    if (part.startsWith("$") && part.endsWith("$")) {
      const latex = part.replace(/^\$+|\$+$/g, "").trim();
      blocks.push({
        id: `b${blockIdx++}`,
        type: "math",
        latex: latex,
        value: latex,
        source_refs: ["ai_ingest"],
      });
    } else {
      blocks.push({
        id: `b${blockIdx++}`,
        type: "text",
        value: part,
        source_refs: ["ai_ingest"],
      });
    }
  }

  return blocks.length > 0
    ? blocks
    : [{ id: "b1", type: "text", value: stemText, source_refs: ["ai_ingest"] }];
}

function buildOptions(
  options: Array<{ key: string; text: string }> | undefined
): Array<Record<string, unknown>> {
  if (!options || options.length === 0) {
    return [
      { key: "A", content: [{ type: "text", value: "" }], source_refs: ["ai_ingest"] },
      { key: "B", content: [{ type: "text", value: "" }], source_refs: ["ai_ingest"] },
    ];
  }

  return options.map((opt) => ({
    key: opt.key,
    content: [{ type: "text", value: opt.text ?? opt.key }],
    source_refs: ["ai_ingest"],
  }));
}

function detectLanguage(text: string): "ar" | "en" {
  // تحقق من وجود أحرف عربية
  const arabicPattern = /[\u0600-\u06FF\u0750-\u077F]/;
  return arabicPattern.test(text) ? "ar" : "en";
}

// ═══════════════════════════════════════════════════════════════════════════════
// HTTP Helpers
// ═══════════════════════════════════════════════════════════════════════════════

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
