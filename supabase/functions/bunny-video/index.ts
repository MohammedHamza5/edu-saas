import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// ============================================================================
// bunny-video — Bunny Stream gateway (API key never leaves the server)
//   action: "create-upload"  → teacher only. Creates the Bunny video object,
//                              upserts the public.videos row and returns
//                              presigned TUS credentials (SHA256 signature).
//   action: "create-bank-upload" → teacher only. Creates a Bunny video object,
//                                  inserts a row in public.video_library and returns
//                                  presigned TUS credentials.
//   action: "sync-status"    → any active user of the video's tenant. Reads the
//                              real encoding status from Bunny and moves the
//                              row forward (uploading → processing → ready/failed).
// Secrets (Edge Function Secrets only): BUNNY_API_KEY, BUNNY_LIBRARY_ID,
//   BUNNY_CDN_HOSTNAME  (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are built-in).
// ============================================================================

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const BUNNY_API = "https://video.bunnycdn.com";
const TUS_ENDPOINT = "https://video.bunnycdn.com/tusupload";
const UPLOAD_WINDOW_SECONDS = 6 * 60 * 60; // presigned upload valid for 6h

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(input),
  );
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// Bunny API video status → our videos.status
// 0 created, 1 uploaded, 2 processing, 3 transcoding, 4 finished,
// 5 error, 6 upload failed, 7 jit segmenting, 8 jit playlists created
function mapBunnyStatus(
  status: number,
  availableResolutions: string | null | undefined,
): "uploading" | "processing" | "ready" | "failed" {
  if (status === 4) return "ready";
  if (status === 3 && (availableResolutions ?? "").trim().length > 0) {
    return "ready"; // first rendition is already playable
  }
  if (status === 5 || status === 6) return "failed";
  if (status === 0) return "uploading";
  return "processing";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "METHOD_NOT_ALLOWED" }, 405);
  }

  try {
    const bunnyKey = Deno.env.get("BUNNY_API_KEY") ?? "";
    const libraryId = Deno.env.get("BUNNY_LIBRARY_ID") ?? "";
    const cdnHost = Deno.env.get("BUNNY_CDN_HOSTNAME") ?? "";
    if (!bunnyKey || !libraryId) {
      return json({ error: "BUNNY_NOT_CONFIGURED" }, 500);
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "AUTH_REQUIRED" }, 401);

    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // 1. Identity comes from the JWT only — never from the request body.
    const jwt = authHeader.replace("Bearer ", "").trim();
    const { data: userData, error: authError } = await admin.auth.getUser(jwt);
    if (authError || !userData?.user) {
      return json({ error: "AUTH_REQUIRED" }, 401);
    }

    const { data: caller } = await admin
      .from("users")
      .select("role, status, tenant_id")
      .eq("id", userData.user.id)
      .maybeSingle();
    if (!caller || caller.status !== "active") {
      return json({ error: "NOT_AUTHORIZED" }, 403);
    }

    const { data: tenant } = await admin
      .from("tenants")
      .select("status, video_provider")
      .eq("id", caller.tenant_id)
      .maybeSingle();
    if (!tenant || tenant.status !== "active") {
      return json({ error: "TENANT_SUSPENDED" }, 403);
    }

    const body = await req.json().catch(() => ({}));
    const action = String(body?.action ?? "");

    // ───────────────────────── create-bank-upload ─────────────────────────
    if (action === "create-bank-upload") {
      if (caller.role !== "teacher") return json({ error: "NOT_AUTHORIZED" }, 403);
      if (tenant.video_provider !== "bunny") {
        return json({ error: "PROVIDER_NOT_BUNNY" }, 403);
      }

      const folderId = body?.folder_id ? String(body.folder_id) : null;
      const title = String(body?.title ?? "").trim().slice(0, 200) || "Video Library Asset";

      if (folderId) {
        const { data: folder } = await admin
          .from("video_folders")
          .select("id, tenant_id")
          .eq("id", folderId)
          .maybeSingle();
        if (!folder || folder.tenant_id !== caller.tenant_id) {
          return json({ error: "NOT_AUTHORIZED" }, 403);
        }
      }

      // Create the video object inside the Bunny library.
      const createRes = await fetch(`${BUNNY_API}/library/${libraryId}/videos`, {
        method: "POST",
        headers: {
          AccessKey: bunnyKey,
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify({ title }),
      });
      if (!createRes.ok) {
        return json({ error: "BUNNY_CREATE_FAILED", status: createRes.status }, 502);
      }
      const created = await createRes.json();
      const guid = String(created?.guid ?? "");
      if (!guid) return json({ error: "BUNNY_CREATE_FAILED" }, 502);

      const thumbnailUrl = cdnHost ? `https://${cdnHost}/${guid}/thumbnail.jpg` : null;

      const { data: inserted, error } = await admin
        .from("video_library")
        .insert({
          tenant_id: caller.tenant_id,
          folder_id: folderId,
          title: title,
          provider: "bunny",
          provider_video_id: guid,
          status: "uploading",
          thumbnail_url: thumbnailUrl,
        })
        .select("id")
        .single();
      
      if (error || !inserted) {
        return json({ error: "DB_ERROR", details: error?.message }, 500);
      }

      const expire = Math.floor(Date.now() / 1000) + UPLOAD_WINDOW_SECONDS;
      const signature = await sha256Hex(`${libraryId}${bunnyKey}${expire}${guid}`);

      return json({
        library_video_id: inserted.id,
        video_guid: guid,
        library_id: libraryId,
        tus_endpoint: TUS_ENDPOINT,
        expire,
        signature,
        thumbnail_url: thumbnailUrl,
      });
    }

    // ───────────────────────── create-upload ─────────────────────────
    if (action === "create-upload") {
      if (caller.role !== "teacher") return json({ error: "NOT_AUTHORIZED" }, 403);
      if (tenant.video_provider !== "bunny") {
        return json({ error: "PROVIDER_NOT_BUNNY" }, 403);
      }

      const contentId = String(body?.content_id ?? "");
      const title = String(body?.title ?? "").trim().slice(0, 200) || "Lecture";
      if (!contentId) return json({ error: "VALIDATION_ERROR" }, 400);

      const { data: content } = await admin
        .from("content")
        .select("id, tenant_id")
        .eq("id", contentId)
        .maybeSingle();
      if (!content || content.tenant_id !== caller.tenant_id) {
        return json({ error: "NOT_AUTHORIZED" }, 403);
      }

      // Create the video object inside the Bunny library.
      const createRes = await fetch(`${BUNNY_API}/library/${libraryId}/videos`, {
        method: "POST",
        headers: {
          AccessKey: bunnyKey,
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify({ title }),
      });
      if (!createRes.ok) {
        return json({ error: "BUNNY_CREATE_FAILED", status: createRes.status }, 502);
      }
      const created = await createRes.json();
      const guid = String(created?.guid ?? "");
      if (!guid) return json({ error: "BUNNY_CREATE_FAILED" }, 502);

      const thumbnailUrl = cdnHost ? `https://${cdnHost}/${guid}/thumbnail.jpg` : null;
      const now = new Date().toISOString();

      const { data: existing } = await admin
        .from("videos")
        .select("id")
        .eq("content_id", contentId)
        .maybeSingle();

      let videoRowId: string;
      if (existing?.id) {
        const { error } = await admin
          .from("videos")
          .update({
            provider: "bunny",
            provider_video_id: guid,
            status: "uploading",
            thumbnail_url: thumbnailUrl,
            duration: null,
            updated_at: now,
          })
          .eq("id", existing.id);
        if (error) return json({ error: "DB_ERROR", details: error.message }, 500);
        videoRowId = existing.id as string;
      } else {
        const { data: inserted, error } = await admin
          .from("videos")
          .insert({
            content_id: contentId,
            provider: "bunny",
            provider_video_id: guid,
            status: "uploading",
            thumbnail_url: thumbnailUrl,
          })
          .select("id")
          .single();
        if (error || !inserted) {
          return json({ error: "DB_ERROR", details: error?.message }, 500);
        }
        videoRowId = inserted.id as string;
      }

      const expire = Math.floor(Date.now() / 1000) + UPLOAD_WINDOW_SECONDS;
      const signature = await sha256Hex(`${libraryId}${bunnyKey}${expire}${guid}`);

      return json({
        video_id: videoRowId,
        video_guid: guid,
        library_id: libraryId,
        tus_endpoint: TUS_ENDPOINT,
        expire,
        signature,
        thumbnail_url: thumbnailUrl,
      });
    }

    // ────────────────────────── sync-status ──────────────────────────
    if (action === "sync-status") {
      const ref = String(body?.video_id ?? "");
      if (!ref) return json({ error: "VALIDATION_ERROR" }, 400);

      let video: any = null;
      let tableName = "videos";
      
      // Try 'videos' first
      const { data: v1 } = await admin
        .from("videos")
        .select("id, provider, provider_video_id, status, content:content!inner(tenant_id)")
        .or(`id.eq.${ref},content_id.eq.${ref}`)
        .limit(1)
        .maybeSingle();

      if (v1) {
        video = {
          ...v1,
          tenant_id: v1.content?.tenant_id,
        };
      } else {
        // Try 'video_library'
        const { data: v2 } = await admin
          .from("video_library")
          .select("id, provider, provider_video_id, status, tenant_id")
          .eq("id", ref)
          .maybeSingle();
        
        if (v2) {
          video = v2;
          tableName = "video_library";
        }
      }

      if (!video) return json({ error: "VIDEO_NOT_FOUND" }, 404);

      if (video.tenant_id !== caller.tenant_id) {
        return json({ error: "NOT_AUTHORIZED" }, 403);
      }

      // Nothing to sync for non-Bunny videos or already-final rows.
      if (
        video.provider !== "bunny" || !video.provider_video_id ||
        video.status === "ready" || video.status === "deleted"
      ) {
        return json({ status: video.status });
      }

      const infoRes = await fetch(
        `${BUNNY_API}/library/${libraryId}/videos/${video.provider_video_id}`,
        { headers: { AccessKey: bunnyKey, Accept: "application/json" } },
      );
      if (!infoRes.ok) {
        return json({ status: video.status, synced: false });
      }
      const info = await infoRes.json();
      const next = mapBunnyStatus(
        Number(info?.status ?? 0),
        info?.availableResolutions,
      );

      const patch: Record<string, unknown> = {
        status: next,
        updated_at: new Date().toISOString(),
      };
      const length = Math.round(Number(info?.length ?? 0));
      if (next === "ready" && length > 0) patch.duration = length;

      const { error } = await admin.from(tableName).update(patch).eq("id", video.id);
      if (error) return json({ error: "DB_ERROR", details: error.message }, 500);

      // If we synced a video_library row, we might also want to cascade to linked videos, 
      // but they will poll/sync on their own if needed, or we just rely on webhook for full cascade.

      return json({ status: next, duration: patch.duration ?? null, synced: true });
    }

    return json({ error: "VALIDATION_ERROR", details: "unknown action" }, 400);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    return json({ error: "INTERNAL_ERROR", details: msg }, 500);
  }
});
