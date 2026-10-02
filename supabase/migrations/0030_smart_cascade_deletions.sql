-- ============================================================================
-- Migration 0030: Smart Cascade Deletions for Students, Groups, and Lessons
-- ============================================================================

-- 1. DELETE STUDENT RPC
CREATE OR REPLACE FUNCTION public.delete_student(p_student_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tenant_id uuid;
  v_user_role text;
  v_target_tenant_id uuid;
  v_target_role text;
BEGIN
  -- Security check: Verify caller is an active teacher
  SELECT tenant_id, role INTO v_tenant_id, v_user_role
  FROM public.users
  WHERE id = auth.uid() AND status = 'active';

  IF v_user_role != 'teacher' THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only teachers can delete students';
  END IF;

  -- Verify target user is in the same tenant and is a student
  SELECT tenant_id, role INTO v_target_tenant_id, v_target_role
  FROM public.users
  WHERE id = p_student_id;

  IF v_target_tenant_id IS NULL OR v_target_tenant_id != v_tenant_id THEN
    RAISE EXCEPTION 'NOT_FOUND: Student not found in your academy';
  END IF;

  IF v_target_role != 'student' THEN
    RAISE EXCEPTION 'INVALID_ACTION: Only student accounts can be deleted with this operation';
  END IF;

  -- 1. Video tracking
  DELETE FROM public.video_progress WHERE student_id = p_student_id;

  -- 2. Exam attempts & answers
  DELETE FROM public.exam_answers 
  WHERE attempt_id IN (SELECT id FROM public.exam_attempts WHERE student_id = p_student_id);
  DELETE FROM public.exam_attempts WHERE student_id = p_student_id;

  -- 3. Assignment submissions & files
  DELETE FROM public.submission_files 
  WHERE submission_id IN (SELECT id FROM public.assignment_submissions WHERE student_id = p_student_id);
  DELETE FROM public.assignment_submissions WHERE student_id = p_student_id;

  -- 4. Attendance
  DELETE FROM public.attendance WHERE student_id = p_student_id;

  -- 5. Daily engagement & telemetry
  DELETE FROM public.student_daily_engagement WHERE student_id = p_student_id;

  -- 6. Manual lesson unlocks
  DELETE FROM public.manual_lesson_unlocks WHERE student_id = p_student_id;

  -- 7. Parent associations
  DELETE FROM public.parent_students WHERE student_id = p_student_id;

  -- 8. Group memberships
  DELETE FROM public.group_members WHERE student_id = p_student_id;

  -- 9. Notifications, devices & events
  DELETE FROM public.notification_recipients WHERE user_id = p_student_id;
  DELETE FROM public.user_devices WHERE user_id = p_student_id;
  DELETE FROM public.activity_events WHERE user_id = p_student_id;

  -- 10. Delete from public.users
  DELETE FROM public.users WHERE id = p_student_id;

  -- 11. Delete from auth.users (so credentials and auth sessions are immediately revoked)
  DELETE FROM auth.users WHERE id = p_student_id;
END;
$$;

-- 2. DELETE GROUP RPC
CREATE OR REPLACE FUNCTION public.delete_group(p_group_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tenant_id uuid;
  v_user_role text;
BEGIN
  -- Security check: Verify caller is an active teacher
  SELECT tenant_id, role INTO v_tenant_id, v_user_role
  FROM public.users
  WHERE id = auth.uid() AND status = 'active';

  IF v_user_role != 'teacher' THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only teachers can delete groups';
  END IF;

  -- Verify group belongs to teacher's tenant
  IF NOT EXISTS (
    SELECT 1 FROM public.groups
    WHERE id = p_group_id AND tenant_id = v_tenant_id
  ) THEN
    RAISE EXCEPTION 'NOT_FOUND: Group not found in your academy';
  END IF;

  -- 1. Remove group-specific customizations from junction table
  DELETE FROM public.content_groups WHERE group_id = p_group_id;

  -- 2. Detach content from group to preserve lessons and exams in Central Bank/Library
  UPDATE public.content SET group_id = NULL WHERE group_id = p_group_id;

  -- 3. Attendance records and sessions
  DELETE FROM public.attendance WHERE group_id = p_group_id;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'attendance_sessions') THEN
    DELETE FROM public.attendance_sessions WHERE group_id = p_group_id;
  END IF;

  -- 4. Group memberships (students remain active in academy)
  DELETE FROM public.group_members WHERE group_id = p_group_id;

  -- 5. Delete group
  DELETE FROM public.groups WHERE id = p_group_id AND tenant_id = v_tenant_id;
END;
$$;

-- 3. DELETE LESSON WITH SMART CLEANUP RPC
CREATE OR REPLACE FUNCTION public.delete_lesson_with_cleanup(p_content_id uuid)
RETURNS text[]
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tenant_id uuid;
  v_user_role text;
  v_storage_paths text[];
BEGIN
  -- Security check: Verify caller is an active teacher
  SELECT tenant_id, role INTO v_tenant_id, v_user_role
  FROM public.users
  WHERE id = auth.uid() AND status = 'active';

  IF v_user_role != 'teacher' THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only teachers can delete lessons';
  END IF;

  -- Verify content belongs to teacher's tenant
  IF NOT EXISTS (
    SELECT 1 FROM public.content
    WHERE id = p_content_id AND tenant_id = v_tenant_id
  ) THEN
    RAISE EXCEPTION 'NOT_FOUND: Lesson not found in your academy';
  END IF;

  -- 1. Collect all storage paths of files attached directly or via group overrides
  SELECT COALESCE(array_agg(f.storage_path), ARRAY[]::text[])
  INTO v_storage_paths
  FROM public.files f
  WHERE f.content_id = p_content_id AND f.storage_path IS NOT NULL;

  -- 2. Nullify any exam references so the exams themselves stay completely safe in exams bank
  UPDATE public.content 
  SET associated_exam_id = NULL, prerequisite_exam_id = NULL 
  WHERE id = p_content_id;

  -- 3. Delete group customization records for this lesson
  DELETE FROM public.content_groups WHERE content_id = p_content_id;

  -- 4. Delete manual unlocks
  DELETE FROM public.manual_lesson_unlocks WHERE content_id = p_content_id;

  -- 5. Delete student video progress
  DELETE FROM public.video_progress 
  WHERE video_id IN (SELECT id FROM public.videos WHERE content_id = p_content_id);

  -- 6. Delete video metadata records
  DELETE FROM public.videos WHERE content_id = p_content_id;

  -- 7. Delete database file records
  DELETE FROM public.files WHERE content_id = p_content_id;

  -- 8. Delete activity logs referencing this content
  DELETE FROM public.activity_events WHERE content_id = p_content_id;

  -- 9. Delete the content record itself
  DELETE FROM public.content WHERE id = p_content_id AND tenant_id = v_tenant_id;

  RETURN v_storage_paths;
END;
$$;
