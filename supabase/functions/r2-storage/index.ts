import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } from "npm:@aws-sdk/client-s3@3.540.0";
import { getSignedUrl } from "npm:@aws-sdk/s3-request-presigner@3.540.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "AUTH_REQUIRED" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
    const token = authHeader.replace("Bearer ", "").trim();
    const { data: { user: callerUser }, error: authError } = await supabaseAdmin.auth.getUser(token);

    if (authError || !callerUser) {
      return new Response(JSON.stringify({ error: "AUTH_REQUIRED", details: authError?.message }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 1. Verify R2 credentials
    const accountId = Deno.env.get("R2_ACCOUNT_ID") || "c325afac18ccd046d3682224f35b37d5";
    const accessKeyId = Deno.env.get("R2_ACCESS_KEY_ID") || "7fc57c6cbdf9d6bb5f6d99a2dca70c32";
    const secretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY") || "2ab588b36702065e7a1ef3474d981e88e4d6f76f2c5711c38cb3e4b666e7211d";
    const bucketName = Deno.env.get("R2_BUCKET_NAME") || "edu-saas-token";

    if (!accountId || !accessKeyId || !secretAccessKey || !bucketName) {
      return new Response(
        JSON.stringify({
          error: "R2_NOT_CONFIGURED",
          details: "Cloudflare R2 secrets (R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET_NAME) are not configured in Supabase.",
        }),
        {
          status: 503,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Initialize S3 client for Cloudflare R2
    const s3Client = new S3Client({
      region: "auto",
      endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
      credentials: {
        accessKeyId,
        secretAccessKey,
      },
    });

    const body = await req.json();
    const action = body.action;

    // Client with caller's JWT to evaluate PostgreSQL RLS & Security Definer functions
    const supabaseCaller = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    // ── ACTION: get-upload-url ────────────────────────────────────────────────
    if (action === "get-upload-url") {
      // 1. Fetch user role and tenant
      const { data: userData, error: userError } = await supabaseAdmin
        .from("users")
        .select("role, tenant_id, status")
        .eq("id", callerUser.id)
        .single();

      if (userError || !userData || userData.role !== "teacher" || userData.status !== "active") {
        return new Response(JSON.stringify({ error: "NOT_AUTHORIZED", details: "Only active teachers can upload materials" }), {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const fileName = body.file_name || "document.pdf";
      const contentType = body.content_type || "application/pdf";
      const cleanFileName = fileName.replace(/[^a-zA-Z0-9._-]/g, "_");
      const storageKey = `materials/${userData.tenant_id}/${Date.now()}_${cleanFileName}`;

      const command = new PutObjectCommand({
        Bucket: bucketName,
        Key: storageKey,
        ContentType: contentType,
      });

      const uploadUrl = await getSignedUrl(s3Client, command, { expiresIn: 900 });

      return new Response(
        JSON.stringify({
          upload_url: uploadUrl,
          storage_path: storageKey,
          storage_provider: "r2",
          expires_in: 900,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // ── ACTION: get-download-url ──────────────────────────────────────────────
    if (action === "get-download-url") {
      const storagePath = body.storage_path;
      if (!storagePath) {
        return new Response(JSON.stringify({ error: "VALIDATION_ERROR", details: "storage_path is required" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // Check database authorization using can_access_file RPC
      const { data: hasAccess, error: accessError } = await supabaseCaller.rpc("can_access_file", {
        p_storage_path: storagePath,
      });

      if (accessError || !hasAccess) {
        return new Response(
          JSON.stringify({
            error: "NOT_AUTHORIZED",
            details: "You do not have permission to view or download this material.",
          }),
          {
            status: 403,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      const command = new GetObjectCommand({
        Bucket: bucketName,
        Key: storagePath,
        ResponseContentDisposition: "inline",
      });

      const downloadUrl = await getSignedUrl(s3Client, command, { expiresIn: 900 });

      return new Response(
        JSON.stringify({
          download_url: downloadUrl,
          expires_in: 900,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // ── ACTION: delete-files ──────────────────────────────────────────────────
    if (action === "delete-files") {
      // 1. Fetch user role and tenant
      const { data: userData, error: userError } = await supabaseAdmin
        .from("users")
        .select("role, tenant_id, status")
        .eq("id", callerUser.id)
        .single();

      if (userError || !userData || userData.role !== "teacher" || userData.status !== "active") {
        return new Response(JSON.stringify({ error: "NOT_AUTHORIZED", details: "Only active teachers can delete materials" }), {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const rawPaths: unknown = body.storage_paths || (body.storage_path ? [body.storage_path] : []);
      const storagePaths = Array.isArray(rawPaths) ? rawPaths.filter((p): p is string => typeof p === "string") : [];

      if (storagePaths.length === 0) {
        return new Response(JSON.stringify({ success: true, deleted: 0 }), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // Security check: ensure the paths belong to the teacher's tenant to prevent unauthorized deletions
      const tenantPrefix = `materials/${userData.tenant_id}/`;
      const validPaths = storagePaths.filter((path) => path.startsWith(tenantPrefix));

      const deleteResults = await Promise.allSettled(
        validPaths.map(async (key) => {
          const command = new DeleteObjectCommand({
            Bucket: bucketName,
            Key: key,
          });
          return s3Client.send(command);
        })
      );

      const deletedCount = deleteResults.filter((r) => r.status === "fulfilled").length;

      return new Response(
        JSON.stringify({
          success: true,
          deleted: deletedCount,
          total: validPaths.length,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    return new Response(JSON.stringify({ error: "INVALID_ACTION", details: `Unknown action '${action}'` }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ error: "INTERNAL_ERROR", details: errorMsg }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
