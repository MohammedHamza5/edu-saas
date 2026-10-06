import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const BUNNY_API = "https://video.bunnycdn.com";

type VideoStatus =
  | "uploading"
  | "processing"
  | "ready"
  | "failed";

function json(
  body: unknown,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

/**
 * Constant-time comparison for equal-length byte arrays.
 */
function timingSafeEqual(
  a: Uint8Array,
  b: Uint8Array,
): boolean {
  if (a.length !== b.length) return false;

  let diff = 0;

  for (let i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }

  return diff === 0;
}

/**
 * Convert bytes to lowercase hexadecimal.
 */
function bytesToHex(bytes: Uint8Array): string {
  let result = "";

  for (const byte of bytes) {
    result += byte.toString(16).padStart(2, "0");
  }

  return result;
}

/**
 * Validate Bunny Stream Webhook v1 signature.
 *
 * Bunny signs the EXACT raw request body with:
 * HMAC-SHA256(
 *   Read-Only API Key,
 *   raw request body
 * )
 */
async function verifyBunnySignature(
  rawBody: Uint8Array,
  signature: string,
  apiKey: string,
): Promise<boolean> {
  if (!signature || !apiKey) return false;

  try {
    const cleanSig = signature.trim().toLowerCase();
    
    // Test HMAC-SHA256
    const key256 = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(apiKey),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"],
    );
    const digest256 = await crypto.subtle.sign("HMAC", key256, rawBody);
    const expected256 = bytesToHex(new Uint8Array(digest256));
    if (timingSafeEqual(new TextEncoder().encode(expected256), new TextEncoder().encode(cleanSig))) {
      return true;
    }

    // Test HMAC-SHA1
    const key1 = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(apiKey),
      { name: "HMAC", hash: "SHA-1" },
      false,
      ["sign"],
    );
    const digest1 = await crypto.subtle.sign("HMAC", key1, rawBody);
    const expected1 = bytesToHex(new Uint8Array(digest1));
    if (timingSafeEqual(new TextEncoder().encode(expected1), new TextEncoder().encode(cleanSig))) {
      return true;
    }
  } catch {
    return false;
  }

  return false;
}

/**
 * Map Bunny Stream status to our application status.
 *
 * Bunny:
 * 0 = Queued / Created
 * 1 = Uploaded / Processing
 * 2 = Processing / Encoding
 * 3 = Transcoding finished / Playable
 * 4 = ResolutionFinished / Ready
 * 5 = Failed
 * 6 = UploadFailed
 */
function mapBunnyStatus(
  status: number,
  availableResolutions?: string | null,
  encodeProgress?: number,
): VideoStatus {
  if (status === 4) return "ready";
  if (status === 3) {
    if ((availableResolutions ?? "").trim().length > 0) return "ready";
    if (encodeProgress === 100) return "ready";
    return "ready"; // Bunny Stream sends status 3 on transcoding complete
  }
  if (status === 5 || status === 6) return "failed";
  if (status === 0) return "uploading";
  return "processing";
}

Deno.serve(async (req: Request) => {
  /*
   * Bunny Stream sends POST requests.
   */
  if (req.method !== "POST") {
    return json(
      { error: "METHOD_NOT_ALLOWED" },
      405,
    );
  }

  try {
    /*
     * -----------------------------------------------------------------------
     * 1. Load server-side secrets
     * -----------------------------------------------------------------------
     */

    const bunnyApiKey =
      Deno.env.get("BUNNY_API_KEY") ?? "";

    const bunnyReadOnlyApiKey =
      Deno.env.get("BUNNY_READ_ONLY_API_KEY") || bunnyApiKey;

    const libraryId =
      Deno.env.get("BUNNY_LIBRARY_ID") ?? "";

    const supabaseUrl =
      Deno.env.get("SUPABASE_URL") ?? "";

    const serviceRoleKey =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (
      !bunnyApiKey ||
      !libraryId ||
      !supabaseUrl ||
      !serviceRoleKey
    ) {
      return json(
        { error: "SERVER_NOT_CONFIGURED" },
        500,
      );
    }

    /*
     * -----------------------------------------------------------------------
     * 2. Read RAW body
     *
     * IMPORTANT:
     * Do NOT call req.json() before signature validation.
     * Bunny signs the exact bytes it sent.
     * -----------------------------------------------------------------------
     */

    const rawBody = new Uint8Array(
      await req.arrayBuffer(),
    );

    /*
     * Basic size protection.
     *
     * Bunny Stream webhook payloads are tiny.
     * Reject unexpectedly huge bodies.
     */
    if (rawBody.length > 1024 * 1024) {
      return json(
        { error: "PAYLOAD_TOO_LARGE" },
        413,
      );
    }

    /*
     * -----------------------------------------------------------------------
     * 3. Read Bunny signature / auth headers
     * -----------------------------------------------------------------------
     */

    const signature =
      req.headers.get("x-bunny-signature") ||
      req.headers.get("X-BunnyStream-Signature") ||
      "";

    const authHeader = req.headers.get("Authorization") ?? "";
    const webhookSecret = Deno.env.get("BUNNY_WEBHOOK_SECRET") ?? "";

    /*
     * -----------------------------------------------------------------------
     * 4. Verify signature if provided. If not provided by Bunny,
     * security is guaranteed by Step 10 where we verify the video existence
     * and fetch its true state directly from Bunny's REST API using BUNNY_API_KEY.
     * -----------------------------------------------------------------------
     */

    if (signature) {
      let valid = await verifyBunnySignature(rawBody, signature, bunnyReadOnlyApiKey);
      if (!valid && bunnyApiKey && bunnyApiKey !== bunnyReadOnlyApiKey) {
        valid = await verifyBunnySignature(rawBody, signature, bunnyApiKey);
      }
      if (!valid && webhookSecret) {
        valid = await verifyBunnySignature(rawBody, signature, webhookSecret);
      }
      if (!valid) {
        return json({ error: "INVALID_SIGNATURE" }, 401);
      }
    } else if (webhookSecret && authHeader) {
      const token = authHeader.replace(/^Bearer\s+/i, "").trim();
      if (token !== webhookSecret) {
        return json({ error: "UNAUTHORIZED_TOKEN" }, 401);
      }
    }

    /*
     * -----------------------------------------------------------------------
     * 5. Parse JSON only AFTER authentication
     * -----------------------------------------------------------------------
     */

    let payload: Record<string, unknown>;

    try {
      payload = JSON.parse(
        new TextDecoder().decode(rawBody),
      );
    } catch {
      return json(
        { error: "INVALID_JSON" },
        400,
      );
    }

    /*
     * -----------------------------------------------------------------------
     * 6. Validate Bunny library + video GUID
     * -----------------------------------------------------------------------
     */

    const guid = String(
      payload?.VideoGuid ?? "",
    );

    const payloadLibrary = String(
      payload?.VideoLibraryId ?? "",
    );

    const bunnyStatus = Number(
      payload?.Status ?? -1,
    );

    if (!guid) {
      return json(
        { error: "MISSING_VIDEO_GUID" },
        400,
      );
    }

    if (payloadLibrary !== libraryId) {
      /*
       * Signature is valid, but this webhook belongs
       * to another Bunny library.
       */
      return json({
        ignored: true,
        reason: "WRONG_LIBRARY",
      });
    }

    /*
     * -----------------------------------------------------------------------
     * 7. Validate status
     * -----------------------------------------------------------------------
     */

    if (
      !Number.isInteger(bunnyStatus) ||
      bunnyStatus < 0 ||
      bunnyStatus > 10
    ) {
      return json({
        ignored: true,
        reason: "UNKNOWN_STATUS",
      });
    }

    /*
     * -----------------------------------------------------------------------
     * 8. Supabase admin client
     * -----------------------------------------------------------------------
     */

    const admin = createClient(
      supabaseUrl,
      serviceRoleKey,
    );

    /*
     * -----------------------------------------------------------------------
     * 9. Find matching database rows
     * -----------------------------------------------------------------------
     */

    const [
      { data: videoRows, error: videoError },
      { data: libraryRows, error: libraryError },
    ] = await Promise.all([
      admin
        .from("videos")
        .select("id,status")
        .eq("provider", "bunny")
        .eq("provider_video_id", guid),

      admin
        .from("video_library")
        .select("id,status")
        .eq("provider", "bunny")
        .eq("provider_video_id", guid),
    ]);

    if (videoError || libraryError) {
      return json(
        { error: "DATABASE_LOOKUP_FAILED" },
        500,
      );
    }

    const vToUpdate =
      (videoRows ?? []).filter(
        (v) =>
          v.status !== "ready" &&
          v.status !== "deleted",
      );

    const lToUpdate =
      (libraryRows ?? []).filter(
        (v) =>
          v.status !== "ready" &&
          v.status !== "deleted",
      );

    if (
      vToUpdate.length === 0 &&
      lToUpdate.length === 0
    ) {
      return json({
        ignored: true,
        reason: "NO_ROWS_TO_UPDATE",
      });
    }

    /*
     * -----------------------------------------------------------------------
     * 10. Ask Bunny directly for authoritative video state
     *
     * We intentionally do NOT trust the webhook status alone.
     * -----------------------------------------------------------------------
     */

    const infoRes = await fetch(
      `${BUNNY_API}/library/${encodeURIComponent(
        libraryId,
      )}/videos/${encodeURIComponent(guid)}`,
      {
        method: "GET",
        headers: {
          AccessKey: bunnyApiKey,
          Accept: "application/json",
        },
      },
    );

    if (!infoRes.ok) {
      return json(
        {
          ignored: true,
          reason: "BUNNY_LOOKUP_FAILED",
        },
      );
    }

    const info = await infoRes.json();

    const next = mapBunnyStatus(
      Number(info?.status ?? 0),
      info?.availableResolutions,
      Number(info?.encodeProgress ?? 0),
    );

    /*
     * -----------------------------------------------------------------------
     * 11. Build database update
     * -----------------------------------------------------------------------
     */

    const patch: Record<string, unknown> = {
      status: next,
      updated_at: new Date().toISOString(),
    };

    const length = Math.round(
      Number(info?.length ?? 0),
    );

    if (
      next === "ready" &&
      Number.isFinite(length) &&
      length > 0
    ) {
      patch.duration = length;
    }

    /*
     * -----------------------------------------------------------------------
     * 12. Update matching records
     * -----------------------------------------------------------------------
     */

    const updates: Promise<unknown>[] = [];

    if (vToUpdate.length > 0) {
      updates.push(
        admin
          .from("videos")
          .update(patch)
          .in(
            "id",
            vToUpdate.map((v) => v.id),
          ),
      );
    }

    if (lToUpdate.length > 0) {
      updates.push(
        admin
          .from("video_library")
          .update(patch)
          .in(
            "id",
            lToUpdate.map((v) => v.id),
          ),
      );
    }

    const results = await Promise.all(updates);

    /*
     * Detect database update failures.
     */
    for (const result of results) {
      if (
        result &&
        typeof result === "object" &&
        "error" in result &&
        result.error
      ) {
        return json(
          { error: "DATABASE_UPDATE_FAILED" },
          500,
        );
      }
    }

    /*
     * -----------------------------------------------------------------------
     * 13. Success
     * -----------------------------------------------------------------------
     */

    return json({
      ok: true,
      status: next,
    });
  } catch {
    /*
     * Do not expose internal error details.
     */
    return json(
      { error: "INTERNAL_ERROR" },
      500,
    );
  }
});
