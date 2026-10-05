-- 0035: fix get_exam_details — removed references to non-existent columns
-- (exam_questions.created_at, exam_attempts.is_passed, exam_attempts.max_score)
CREATE OR REPLACE FUNCTION public.get_exam_details(p_exam_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id      uuid := auth.uid();
  v_caller_tenant  uuid;
  v_caller_role    text;
  v_exam           record;
  v_content        record;
  v_group_name     text;
  v_version        record;
  v_questions      jsonb := '[]'::jsonb;
  v_contexts       jsonb := '[]'::jsonb;
  v_latest_attempt jsonb := null;
  v_attempts_count integer := 0;
  v_best_score     integer := null;
  v_is_teacher     boolean := false;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be authenticated';
  END IF;

  SELECT tenant_id, role INTO v_caller_tenant, v_caller_role
  FROM public.users WHERE id = v_caller_id AND status IN ('active', 'pending');

  IF v_caller_tenant IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Active user profile required';
  END IF;

  v_is_teacher := (v_caller_role = 'teacher');

  SELECT * INTO v_exam FROM public.exams WHERE id = p_exam_id;
  IF v_exam.id IS NULL THEN
    RAISE EXCEPTION 'EXAM_NOT_FOUND: Exam does not exist';
  END IF;

  SELECT * INTO v_content FROM public.content WHERE id = v_exam.content_id;

  IF v_exam.tenant_id != v_caller_tenant THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Tenant mismatch';
  END IF;

  IF NOT v_is_teacher THEN
    IF v_content.status != 'published' THEN
      RAISE EXCEPTION 'NOT_AUTHORIZED: Exam is not published';
    END IF;

    IF v_caller_role = 'student' THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.group_members gm
        WHERE gm.student_id = v_caller_id AND gm.status = 'active'
          AND (gm.group_id = v_content.group_id
               OR EXISTS (SELECT 1 FROM public.content_groups cg
                          WHERE cg.content_id = v_content.id AND cg.group_id = gm.group_id))
      ) THEN
        RAISE EXCEPTION 'NOT_AUTHORIZED: Student is not an active member of this group';
      END IF;
    ELSIF v_caller_role = 'parent' THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.group_members gm
        JOIN public.parent_students ps ON ps.student_id = gm.student_id
        WHERE ps.parent_id = v_caller_id AND gm.status = 'active'
          AND (gm.group_id = v_content.group_id
               OR EXISTS (SELECT 1 FROM public.content_groups cg
                          WHERE cg.content_id = v_content.id AND cg.group_id = gm.group_id))
      ) THEN
        RAISE EXCEPTION 'NOT_AUTHORIZED: Parent is not linked to an active student in this group';
      END IF;
    ELSE
      RAISE EXCEPTION 'NOT_AUTHORIZED';
    END IF;
  END IF;

  IF v_content.group_id IS NOT NULL THEN
    SELECT name INTO v_group_name FROM public.groups WHERE id = v_content.group_id;
  END IF;

  IF v_is_teacher THEN
    SELECT * INTO v_version FROM public.exam_versions
    WHERE exam_id = p_exam_id ORDER BY version_number DESC LIMIT 1;
  ELSE
    SELECT * INTO v_version FROM public.exam_versions
    WHERE exam_id = p_exam_id AND status = 'published' ORDER BY version_number DESC LIMIT 1;
  END IF;

  IF v_version.id IS NOT NULL THEN
    SELECT COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', ec.id, 'exam_version_id', ec.exam_version_id, 'title', ec.title,
        'context_text', ec.context_text, 'image_url', ec.image_url,
        'image_meta', ec.image_meta, 'sort_order', ec.sort_order
      ) ORDER BY ec.sort_order, ec.created_at
    ), '[]'::jsonb)
    INTO v_contexts
    FROM public.exam_contexts ec WHERE ec.exam_version_id = v_version.id;

    SELECT COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', eq.id, 'exam_version_id', eq.exam_version_id,
        'question_text', eq.question_text, 'question_type', eq.question_type,
        'points', eq.points, 'sort_order', eq.sort_order,
        'image_url', eq.image_url, 'image_meta', eq.image_meta,
        'context_id', eq.context_id,
        'options', (
          SELECT COALESCE(jsonb_agg(
            CASE WHEN v_is_teacher THEN
              jsonb_build_object('id', qo.id, 'question_id', qo.question_id,
                'option_text', qo.option_text, 'sort_order', qo.sort_order,
                'is_correct', qo.is_correct, 'image_url', qo.image_url,
                'image_meta', qo.image_meta)
            ELSE
              -- SECURITY: never expose is_correct to students/parents
              jsonb_build_object('id', qo.id, 'question_id', qo.question_id,
                'option_text', qo.option_text, 'sort_order', qo.sort_order,
                'image_url', qo.image_url, 'image_meta', qo.image_meta)
            END ORDER BY qo.sort_order, qo.id
          ), '[]'::jsonb)
          FROM public.question_options qo WHERE qo.question_id = eq.id
        )
      ) ORDER BY eq.sort_order, eq.id
    ), '[]'::jsonb)
    INTO v_questions
    FROM public.exam_questions eq WHERE eq.exam_version_id = v_version.id;
  END IF;

  IF v_caller_role = 'student' THEN
    SELECT count(*), max(score) INTO v_attempts_count, v_best_score
    FROM public.exam_attempts WHERE exam_id = p_exam_id AND student_id = v_caller_id;

    SELECT to_jsonb(a.*) INTO v_latest_attempt
    FROM (
      SELECT id, exam_id, student_id, exam_version_id, started_at, submitted_at,
             score, percentage, status
      FROM public.exam_attempts
      WHERE exam_id = p_exam_id AND student_id = v_caller_id
      ORDER BY started_at DESC LIMIT 1
    ) a;
  END IF;

  RETURN jsonb_build_object(
    'id', v_exam.id, 'content_id', v_exam.content_id, 'tenant_id', v_exam.tenant_id,
    'title', COALESCE(v_content.title, ''), 'description', v_content.description,
    'group_id', v_content.group_id, 'group_name', v_group_name,
    'duration_minutes', v_exam.duration_minutes, 'max_score', v_exam.max_score,
    'passing_score', v_exam.passing_score, 'shuffle_questions', v_exam.shuffle_questions,
    'show_result', v_exam.show_result, 'allow_retake', v_exam.allow_retake,
    'start_at', v_exam.start_at, 'end_at', v_exam.end_at,
    'created_at', v_exam.created_at, 'updated_at', v_exam.updated_at,
    'content', jsonb_build_object(
      'id', v_content.id, 'title', v_content.title, 'description', v_content.description,
      'group_id', v_content.group_id, 'status', v_content.status,
      'groups', jsonb_build_object('name', v_group_name)),
    'active_version', CASE WHEN v_version.id IS NOT NULL THEN
      jsonb_build_object(
        'id', v_version.id, 'exam_id', v_version.exam_id,
        'version_number', v_version.version_number, 'status', v_version.status,
        'created_at', v_version.created_at, 'published_at', v_version.published_at,
        'exam_contexts', v_contexts, 'exam_questions', v_questions)
      ELSE null END,
    'attempts_count', v_attempts_count,
    'my_latest_attempt', v_latest_attempt,
    'my_best_score', v_best_score
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_exam_details(uuid) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.get_exam_details(uuid) TO authenticated;
NOTIFY pgrst, 'reload schema';
