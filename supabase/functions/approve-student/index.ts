import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

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
    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

    // 1. Verify caller via JWT
    const token = authHeader.replace("Bearer ", "").trim();
    const { data: { user: callerUser }, error: authError } = await supabaseAdmin.auth.getUser(token);
    if (authError || !callerUser) {
      return new Response(JSON.stringify({ error: "AUTH_REQUIRED", details: authError?.message }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Fetch caller's profile and verify role is teacher
    const { data: teacherProfile, error: teacherError } = await supabaseAdmin
      .from("users")
      .select("id, tenant_id, role, status")
      .eq("id", callerUser.id)
      .single();

    if (teacherError || !teacherProfile || teacherProfile.role !== "teacher" || teacherProfile.status !== "active") {
      return new Response(JSON.stringify({ error: "NOT_AUTHORIZED", details: "Caller must be an active teacher" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. Verify tenant is active
    const { data: tenantData } = await supabaseAdmin
      .from("tenants")
      .select("status")
      .eq("id", teacherProfile.tenant_id)
      .single();

    if (!tenantData || tenantData.status !== "active") {
      return new Response(JSON.stringify({ error: "TENANT_SUSPENDED" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 4. Parse request payload
    const body = await req.json();
    const { student_id, action } = body;

    if (!student_id || !action) {
      return new Response(JSON.stringify({ error: "VALIDATION_ERROR", details: "student_id and action are required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const validActions = ["approve", "reject", "suspend", "activate"];
    if (!validActions.includes(action)) {
      return new Response(JSON.stringify({ error: "VALIDATION_ERROR", details: "Invalid action" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const actionToStatus: Record<string, string> = {
      approve: "active",
      reject: "rejected",
      suspend: "suspended",
      activate: "active",
    };
    const newStatus = actionToStatus[action];

    // 5. Verify target student belongs to caller's tenant
    const { data: student, error: studentError } = await supabaseAdmin
      .from("users")
      .select("id, tenant_id, role, status, full_name, email")
      .eq("id", student_id)
      .single();

    if (studentError || !student) {
      return new Response(JSON.stringify({ error: "STUDENT_NOT_FOUND" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (student.tenant_id !== teacherProfile.tenant_id) {
      return new Response(JSON.stringify({ error: "NOT_AUTHORIZED", details: "Student belongs to different tenant" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 6. Update student status in public.users
    const { error: updateError } = await supabaseAdmin
      .from("users")
      .update({ status: newStatus, updated_at: new Date().toISOString() })
      .eq("id", student_id);

    if (updateError) {
      return new Response(JSON.stringify({ error: "UPDATE_FAILED", details: updateError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 6b. Auto-confirm email in auth.users so approved students can sign in immediately
    if (action === "approve" || action === "activate") {
      await supabaseAdmin.auth.admin.updateUserById(student_id, {
        email_confirm: true,
      });
    }

    // 7. Insert audit log
    await supabaseAdmin.from("audit_logs").insert({
      tenant_id: teacherProfile.tenant_id,
      actor_user_id: teacherProfile.id,
      action: `student_${action}`,
      entity_type: "users",
      entity_id: student_id,
      metadata: { previous_status: student.status, new_status: newStatus },
    });

    // 8. Create notification
    if (action === "approve" || action === "reject") {
      const isApproved = action === "approve";
      const { data: notif } = await supabaseAdmin
        .from("notifications")
        .insert({
          tenant_id: teacherProfile.tenant_id,
          title: isApproved ? "تم اعتماد حسابك بنجاح" : "حالة طلب التسجيل",
          body: isApproved
            ? "مرحباً بك في المنصة التعليمية! تم قبول طلبك بنجاح ويمكنك الآن تصفح المواد والمجموعات."
            : "نأسف لإبلاغك بأنه لم يتم قبول طلب التسجيل في الوقت الحالي.",
          type: "important_announcement",
          data: { student_id, action },
        })
        .select("id")
        .single();

      if (notif?.id) {
        await supabaseAdmin.from("notification_recipients").insert({
          notification_id: notif.id,
          user_id: student_id,
        });
      }
    }

    return new Response(
      JSON.stringify({ ok: true, status: newStatus }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err?.message || "Internal Server Error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
