-- ==============================================================================
-- Migration 0056: Delete or Archive Exam RPC
-- ==============================================================================
-- Allows teachers to safely delete or archive exams.
-- 1. If an exam has 0 student attempts (or if p_force = true), it is permanently
--    and cleanly deleted along with all versions, questions, and options.
-- 2. If an exam has existing student attempts and p_force = false, it is
--    gracefully archived (status = 'archived') to protect historical grades
--    and audit integrity, while removing it from all active student/teacher lists.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.delete_exam(
  p_exam_id uuid,
  p_force boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_tenant_id uuid;
  v_content_id uuid;
  v_attempts_count int;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT tenant_id INTO v_tenant_id
  FROM public.users
  WHERE id = v_caller_id AND role = 'teacher' AND status = 'active';

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only active teachers can delete exams';
  END IF;

  -- 1. Find exam and verify tenant ownership
  SELECT content_id INTO v_content_id
  FROM public.exams
  WHERE id = p_exam_id AND tenant_id = v_tenant_id;

  IF v_content_id IS NULL THEN
    RAISE EXCEPTION 'EXAM_NOT_FOUND: Exam does not exist or does not belong to your academy';
  END IF;

  -- 2. Count student attempts
  SELECT count(*) INTO v_attempts_count
  FROM public.exam_attempts
  WHERE exam_id = p_exam_id;

  -- 3. Always unlink from any lesson in content_groups or content
  UPDATE public.content_groups
  SET associated_exam_id = NULL
  WHERE associated_exam_id = p_exam_id;

  UPDATE public.content_groups
  SET prerequisite_exam_id = NULL
  WHERE prerequisite_exam_id = p_exam_id;

  UPDATE public.content
  SET associated_exam_id = NULL
  WHERE associated_exam_id = p_exam_id;

  UPDATE public.content
  SET prerequisite_exam_id = NULL
  WHERE prerequisite_exam_id = p_exam_id;

  -- 4. Delete or Archive
  IF v_attempts_count = 0 OR p_force = true THEN
    -- Delete answers and attempts if forced
    IF v_attempts_count > 0 THEN
      DELETE FROM public.exam_answers
      WHERE attempt_id IN (SELECT id FROM public.exam_attempts WHERE exam_id = p_exam_id);

      DELETE FROM public.exam_attempts
      WHERE exam_id = p_exam_id;
    END IF;

    -- Delete question options
    DELETE FROM public.question_options
    WHERE question_id IN (
      SELECT eq.id FROM public.exam_questions eq
      JOIN public.exam_versions ev ON ev.id = eq.exam_version_id
      WHERE ev.exam_id = p_exam_id
    );

    -- Delete questions
    DELETE FROM public.exam_questions
    WHERE exam_version_id IN (
      SELECT id FROM public.exam_versions WHERE exam_id = p_exam_id
    );

    -- Delete contexts if table exists
    BEGIN
      DELETE FROM public.exam_contexts
      WHERE exam_version_id IN (
        SELECT id FROM public.exam_versions WHERE exam_id = p_exam_id
      );
    EXCEPTION WHEN undefined_table THEN
      NULL;
    END;

    -- Delete versions
    DELETE FROM public.exam_versions
    WHERE exam_id = p_exam_id;

    -- Delete exam record
    DELETE FROM public.exams
    WHERE id = p_exam_id AND tenant_id = v_tenant_id;

    -- Delete content record
    DELETE FROM public.content
    WHERE id = v_content_id AND tenant_id = v_tenant_id;

    RETURN jsonb_build_object(
      'success', true,
      'action', 'deleted',
      'attempts_count', v_attempts_count
    );
  ELSE
    -- Archive versions and content so historical audit stays intact
    UPDATE public.exam_versions
    SET status = 'archived'
    WHERE exam_id = p_exam_id;

    UPDATE public.content
    SET status = 'archived'
    WHERE id = v_content_id AND tenant_id = v_tenant_id;

    RETURN jsonb_build_object(
      'success', true,
      'action', 'archived',
      'attempts_count', v_attempts_count
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_exam(uuid, boolean) TO authenticated;
