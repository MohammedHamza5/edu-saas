-- ============================================================================
-- Migration 0029: Production Security Hardening
-- Hardens RLS on all public tables, locks down search_path on SECURITY DEFINER
-- functions, and revokes unauthorized RPC execution privileges from anon role.
-- ============================================================================

-- 1. Ensure RLS is active on all public reference tables
ALTER TABLE IF EXISTS public.taxonomy ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.question_types ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'taxonomy' AND policyname = 'taxonomy_read_all'
  ) THEN
    CREATE POLICY "taxonomy_read_all" ON public.taxonomy FOR SELECT TO authenticated, anon USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'question_types' AND policyname = 'question_types_read_all'
  ) THEN
    CREATE POLICY "question_types_read_all" ON public.question_types FOR SELECT TO authenticated, anon USING (true);
  END IF;
END $$;

-- 2. Lock down mutable search_path on SECURITY DEFINER functions (Remediates CWE-426 / Supabase 0011)
ALTER FUNCTION IF EXISTS public.touch_updated_at() SET search_path = public;
ALTER FUNCTION IF EXISTS public.record_student_heartbeat(integer, integer, text) SET search_path = public;
ALTER FUNCTION IF EXISTS public.record_activity_event(text, uuid, uuid, jsonb) SET search_path = public;
ALTER FUNCTION IF EXISTS public.trg_sync_exam_title() SET search_path = public;
ALTER FUNCTION IF EXISTS public.delete_qb_document(uuid) SET search_path = public;
ALTER FUNCTION IF EXISTS public.delete_qb_question(uuid) SET search_path = public;
ALTER FUNCTION IF EXISTS public.get_student_dashboard(uuid) SET search_path = public;

-- 3. Revoke execute privileges from anon & PUBLIC on all sensitive RPCs
DO $$
BEGIN
  REVOKE EXECUTE ON FUNCTION public.approve_student(uuid, text) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.assign_content_to_groups(uuid, uuid[]) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.assign_content_to_groups(uuid, uuid[], jsonb) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.can_access_file(text) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.claim_next_job(text) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.complete_job(uuid, jsonb) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.delete_qb_document(uuid) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.delete_qb_question(uuid) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.fail_job(uuid, text, boolean) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.get_group_course_progress(uuid, uuid) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.get_lesson_context(uuid, uuid) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.get_student_360(uuid) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.get_student_dashboard(uuid) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.get_video_playback_url(uuid) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.manual_unlock_lesson(uuid, uuid, uuid, text) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.publish_revision(uuid) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.record_activity_event(text, uuid, uuid, jsonb) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.record_student_heartbeat(integer, integer, text) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.reorder_content_items(uuid[], uuid) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.start_exam(uuid) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.submit_exam(uuid, jsonb) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.toggle_group_all_content_visibility(uuid, boolean) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.toggle_lesson_group_visibility(uuid, uuid, boolean) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.update_group_content_customization(uuid, uuid, uuid, uuid, uuid, integer, text) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.update_video_progress_v2(uuid, integer, integer, jsonb, integer, boolean) FROM anon, PUBLIC;

  -- RLS & internal helper functions
  REVOKE EXECUTE ON FUNCTION public.group_belongs_to_my_tenant(uuid) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.handle_new_auth_user() FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.has_role(text) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.is_member_of_group(uuid, uuid) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.is_parent_of_student(uuid, uuid) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.my_tenant_id() FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.notification_belongs_to_tenant(uuid, uuid) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.parent_has_child_in_group(uuid, uuid) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.prevent_identity_change() FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.qb_is_teacher(uuid) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.qb_my_tenant() FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.qb_prevent_revision_mutation() FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.tenant_is_active() FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.trg_sync_content_to_content_groups() FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.user_belongs_to_my_tenant(uuid) FROM anon, PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.user_has_notification(uuid, uuid) FROM anon, PUBLIC;

  -- 4. Restrict internal worker functions to service_role only
  REVOKE EXECUTE ON FUNCTION public.claim_next_job(text) FROM authenticated;
  REVOKE EXECUTE ON FUNCTION public.complete_job(uuid, jsonb) FROM authenticated;
  REVOKE EXECUTE ON FUNCTION public.fail_job(uuid, text, boolean) FROM authenticated;

  -- 5. Ensure authenticated and service_role retain necessary execute privileges
  GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated, service_role;
END $$;
