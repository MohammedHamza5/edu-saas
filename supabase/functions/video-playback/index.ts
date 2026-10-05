import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// ============================================================================
// video-playback — issues a time-limited, signed Bunny embed URL.
//
// Flow:
//   1. Verify caller JWT → get role/status/tenant from public.users
//   2. Resolve the requested video → verify tenant + publish status
//   3. Check group membership (student/parent)
//   4. Generate Bunny CDN Token (HMAC-SHA256 signed, 4h TTL)
//   5. Return playback_url (embed iframe URL with token + expires)
//
// Security guarantees:
//   • URL contains a signed token — sharing the URL gives ≤4h access
//   • Token is scoped to the specific video GUID (not reusable)
//   • Students cannot access videos from groups they don't belong to
//   • Draft/unpublished content is blocked for non-teachers
//   • No Bunny secrets ever leave the Edge Function
//
// Required Secrets:
//   BUNNY_TOKEN_KEY   — Video library "Token Authentication Secret"
//   BUNNY_LIBRARY_ID  — Numeric library ID
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY — auto-set by Supabase
// ============================================================================

const TOKEN_TTL_SECONDS = 4 * 60 * 60; // 4 hours

// Allow requests from client apps and web origins
function corsHeaders(origin: string | null): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": origin || "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}

function json(
  body: unknown,
  status = 200,
  origin: string | null = null,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders(origin),
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

/**
 * Generate Bunny CDN Token Authentication hash.
 *
 * Formula (from Bunny docs):
 *   token = SHA256( tokenKey + videoGuid + expires )
 * Result is Base64 URL-safe encoded then stripped of padding.
 */
async function generateBunnyToken(
  tokenKey: string,
  videoGuid: string,
  expires: number,
): Promise<string> {
  const input = `${tokenKey}${videoGuid}${expires}`;
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(input),
  );
  // Convert to Base64 URL-safe (Bunny expects this format)
  const base64 = btoa(String.fromCharCode(...new Uint8Array(digest)));
  return base64
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

// deno-lint-ignore no-explicit-any
type AnyRecord = Record<string, any>;

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("Origin");

  // ── CORS preflight ──────────────────────────────────────────────────────
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(origin) });
  }

  if (req.method !== "POST") {
    return json({ error: "METHOD_NOT_ALLOWED" }, 405, origin);
  }

  try {
    // ── 1. Load secrets ──────────────────────────────────────────────────
    const tokenKey = Deno.env.get("BUNNY_TOKEN_KEY") ?? "";
    const libraryId = Deno.env.get("BUNNY_LIBRARY_ID") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!tokenKey || !libraryId || !supabaseUrl || !serviceRoleKey) {
      return json({ error: "SERVER_NOT_CONFIGURED" }, 500, origin);
    }

    // ── 2. Authenticate caller ───────────────────────────────────────────
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return json({ error: "AUTH_REQUIRED" }, 401, origin);
    }
    const jwt = authHeader.slice(7).trim();

    const admin = createClient(supabaseUrl, serviceRoleKey);

    const { data: userData, error: authError } = await admin.auth.getUser(jwt);
    if (authError || !userData?.user) {
      return json({ error: "AUTH_REQUIRED" }, 401, origin);
    }

    const { data: caller } = await admin
      .from("users")
      .select("role, status, tenant_id")
      .eq("id", userData.user.id)
      .maybeSingle();

    if (!caller || caller.status !== "active") {
      return json({ error: "NOT_AUTHORIZED" }, 403, origin);
    }

    // ── 3. Parse request body ────────────────────────────────────────────
    let body: AnyRecord = {};
    try {
      body = await req.json();
    } catch {
      return json({ error: "INVALID_JSON" }, 400, origin);
    }

    const videoId = String(body?.video_id ?? "").trim();
    if (!videoId) {
      return json({ error: "MISSING_VIDEO_ID" }, 400, origin);
    }

    // ── 4. Resolve video ─────────────────────────────────────────────────
    let providerVideoId = "";
    let groupId: string | null = null;
    let isPublished = true;

    // First: try content-linked videos
    const { data: video } = await admin
      .from("videos")
      .select(
        "id, provider, provider_video_id, status, content_id, content:content!inner(tenant_id, status, group_id)",
      )
      .or(`id.eq.${videoId},content_id.eq.${videoId}`)
      .limit(1)
      .maybeSingle();

    if (video) {
      const content = video.content as AnyRecord;

      // Tenant isolation
      if (content.tenant_id !== caller.tenant_id) {
        return json({ error: "NOT_AUTHORIZED" }, 403, origin);
      }
      if (video.provider !== "bunny" || !video.provider_video_id) {
        return json({ error: "NOT_BUNNY_VIDEO" }, 400, origin);
      }
      if (video.status !== "ready") {
        return json({ error: "VIDEO_NOT_READY" }, 400, origin);
      }

      isPublished = content.status === "published";
      groupId = content.group_id ?? null;
      providerVideoId = video.provider_video_id;
    } else {
      // Second: teacher previewing from Video Bank (library video)
      if (caller.role !== "teacher") {
        return json({ error: "VIDEO_NOT_FOUND" }, 404, origin);
      }

      const { data: libVideo } = await admin
        .from("video_library")
        .select("id, provider, provider_video_id, status, tenant_id")
        .eq("id", videoId)
        .eq("tenant_id", caller.tenant_id)
        .maybeSingle();

      if (!libVideo) return json({ error: "VIDEO_NOT_FOUND" }, 404, origin);
      if (libVideo.provider !== "bunny" || !libVideo.provider_video_id) {
        return json({ error: "NOT_BUNNY_VIDEO" }, 400, origin);
      }
      if (libVideo.status !== "ready") {
        return json({ error: "VIDEO_NOT_READY" }, 400, origin);
      }

      providerVideoId = libVideo.provider_video_id;
    }

    // ── 5. Draft content: only teachers can preview ──────────────────────
    if (!isPublished && caller.role !== "teacher") {
      return json({ error: "CONTENT_NOT_PUBLISHED" }, 403, origin);
    }

    // ── 6. Group membership check (student / parent) ─────────────────────
    if (caller.role !== "teacher" && groupId) {
      let isAllowed = false;

      if (caller.role === "student") {
        const { data: membership } = await admin
          .from("group_members")
          .select("id")
          .eq("student_id", userData.user.id)
          .eq("group_id", groupId)
          .maybeSingle();

        isAllowed = !!membership;
      } else if (caller.role === "parent") {
        const { data: parentStudents } = await admin
          .from("parent_students")
          .select("student_id")
          .eq("parent_id", userData.user.id);

        if (parentStudents && parentStudents.length > 0) {
          const studentIds = parentStudents.map((ps: AnyRecord) => ps.student_id);
          const { data: memberships } = await admin
            .from("group_members")
            .select("id")
            .in("student_id", studentIds)
            .eq("group_id", groupId)
            .limit(1);

          isAllowed = !!(memberships && memberships.length > 0);
        }
      }

      if (!isAllowed) {
        return json({ error: "NOT_AUTHORIZED" }, 403, origin);
      }
    }

    // ── 7. Generate time-limited signed token ────────────────────────────
    const expires = Math.floor(Date.now() / 1000) + TOKEN_TTL_SECONDS;
    const token = await generateBunnyToken(tokenKey, providerVideoId, expires);

    // Bunny embed URL with Token Authentication + player options
    const playbackUrl =
      `https://iframe.mediadelivery.net/embed/${libraryId}/${providerVideoId}` +
      `?token=${token}` +
      `&expires=${expires}` +
      `&autoplay=false` +
      `&preload=true` +
      `&responsive=true` +
      `&captions=false`;

    return json({ playback_url: playbackUrl, expires }, 200, origin);
  } catch {
    return json({ error: "INTERNAL_ERROR" }, 500, origin);
  }
});
