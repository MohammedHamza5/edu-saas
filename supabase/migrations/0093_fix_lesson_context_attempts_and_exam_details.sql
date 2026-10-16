-- ==============================================================================
-- Migration 0093: Enrich get_lesson_context and get_exam_details with Attempt Status
-- ==============================================================================
-- 1. get_lesson_context: Include is_passed, best_score, attempt_count, and
--    latest_attempt_status for each attached exam for the caller student.
-- 2. get_exam_details: Return both my_latest_attempt / latest_attempt and
--    my_best_score / best_score for seamless client compatibility.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.get_lesson_context(p_content_id uuid, p_group_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_cg record;
  v_file_id uuid := null;
  v_file_name text := null;
  v_file_storage_path text := null;
  v_exam_id uuid := null;
  v_exam_title text := null;
  v_exam_passing_score int := null;
  v_group record;
  v_latest_version_id uuid := null;
  v_questions_count int := 0;
  v_is_manually_unlocked boolean := false;
  v_manual_reason text := null;
  v_attached_exams jsonb := '[]'::jsonb;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be authenticated';
  END IF;

  SELECT * INTO v_cg FROM public.content_groups
  WHERE content_id = p_content_id AND group_id = p_group_id;

  IF v_cg IS NULL THEN
    RETURN jsonb_build_object('error', 'NOT_FOUND');
  END IF;

  SELECT * INTO v_group FROM public.groups WHERE id = p_group_id;

  -- 1. Resolve attached PDF (with fallback if cg.file_id is null)
  IF v_cg.file_id IS NOT NULL THEN
    SELECT id, file_name, storage_path INTO v_file_id, v_file_name, v_file_storage_path
    FROM public.files WHERE id = v_cg.file_id;
  ELSE
    SELECT id, file_name, storage_path INTO v_file_id, v_file_name, v_file_storage_path
    FROM public.files WHERE content_id = p_content_id
    ORDER BY created_at DESC LIMIT 1;
    
    IF v_file_id IS NOT NULL THEN
      UPDATE public.content_groups
      SET file_id = v_file_id
      WHERE content_id = p_content_id AND group_id = p_group_id;
    END IF;
  END IF;

  -- 2. Resolve attached exams from lesson_exams or cg.associated_exam_id
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'exam_id', ex.id,
      'exam_title', COALESCE(ex.title, c.title, ''),
      'sort_order', COALESCE(q.sort_order, 0),
      'is_required', COALESCE(q.is_required, true),
      'passing_score', COALESCE(v_cg.passing_score_override, ex.passing_score, v_group.default_passing_score, 60),
      'questions_count', COALESCE((
        SELECT count(*)::int FROM public.exam_questions eq
        WHERE eq.exam_version_id = (
          SELECT ev.id FROM public.exam_versions ev
          WHERE ev.exam_id = ex.id
          ORDER BY ev.version_number DESC LIMIT 1
        )
      ), 0),
      'best_score', (
        SELECT MAX(ea.score) FROM public.exam_attempts ea
        WHERE ea.exam_id = ex.id
          AND ea.student_id = v_caller_id
          AND ea.status IN ('submitted', 'completed')
      ),
      'is_passed', (
        SELECT EXISTS (
          SELECT 1 FROM public.exam_attempts ea
          WHERE ea.exam_id = ex.id
            AND ea.student_id = v_caller_id
            AND ea.status IN ('submitted', 'completed')
            AND ea.score >= COALESCE(v_cg.passing_score_override, ex.passing_score, v_group.default_passing_score, 60)
        )
      ),
      'attempt_count', (
        SELECT COUNT(*)::int FROM public.exam_attempts ea
        WHERE ea.exam_id = ex.id
          AND ea.student_id = v_caller_id
      ),
      'latest_attempt_status', (
        SELECT ea.status FROM public.exam_attempts ea
        WHERE ea.exam_id = ex.id
          AND ea.student_id = v_caller_id
        ORDER BY ea.started_at DESC LIMIT 1
      )
    ) ORDER BY COALESCE(q.sort_order, 0) ASC
  ), '[]'::jsonb) INTO v_attached_exams
  FROM (
    SELECT le.exam_id, le.sort_order, le.is_required
    FROM public.lesson_exams le
    WHERE le.content_id = p_content_id AND le.group_id = p_group_id
    UNION
    SELECT v_cg.associated_exam_id AS exam_id, 0 AS sort_order, true AS is_required
    WHERE v_cg.associated_exam_id IS NOT NULL
  ) q
  JOIN public.exams ex ON ex.id = q.exam_id
  LEFT JOIN public.content c ON c.id = ex.content_id;

  -- 3. Check manual unlock for caller student
  SELECT EXISTS(
    SELECT 1 FROM public.manual_lesson_unlocks
    WHERE content_id = p_content_id AND group_id = p_group_id AND student_id = v_caller_id
  ), reason INTO v_is_manually_unlocked, v_manual_reason
  FROM public.manual_lesson_unlocks
  WHERE content_id = p_content_id AND group_id = p_group_id AND student_id = v_caller_id
  LIMIT 1;

  RETURN jsonb_build_object(
    'content_group_id', v_cg.id,
    'content_id', p_content_id,
    'group_id', p_group_id,
    'sort_order', v_cg.sort_order,
    'pdf_file_id', v_file_id,
    'pdf_file_name', v_file_name,
    'pdf_storage_path', v_file_storage_path,
    'lesson_exam_id', v_cg.associated_exam_id,
    'lesson_exam_title', (SELECT title FROM public.exams WHERE id = v_cg.associated_exam_id),
    'attached_exams', v_attached_exams,
    'passing_score_override', v_cg.passing_score_override,
    'group_default_passing_score', v_group.default_passing_score,
    'enforce_sequential', COALESCE(v_group.enforce_sequential_learning, true),
    'is_manually_unlocked', COALESCE(v_is_manually_unlocked, false),
    'manual_unlock_reason', v_manual_reason
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_lesson_context(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_lesson_context(uuid, uuid) TO authenticated;

-- Upgrade get_exam_details with dual property keys for robust client compatibility
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
    RAISE EXCEPTION 'NOT_AUTHORIZED: User profile not found';
  END IF;

  v_is_teacher := (v_caller_role = 'teacher');

  SELECT * INTO v_exam FROM public.exams WHERE id = p_exam_id AND tenant_id = v_caller_tenant;
  IF v_exam.id IS NULL THEN
    RAISE EXCEPTION 'EXAM_NOT_FOUND: Exam does not exist in your tenant';
  END IF;

  SELECT * INTO v_content FROM public.content WHERE id = v_exam.content_id;

  IF NOT v_is_teacher THEN
    IF v_content.status != 'published' THEN
      RAISE EXCEPTION 'NOT_AUTHORIZED: Exam is not published';
    END IF;

    IF v_caller_role = 'student' THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.group_members gm
        WHERE gm.student_id = v_caller_id AND gm.status = 'active'
          AND (
            (v_content.group_id IS NOT NULL AND gm.group_id = v_content.group_id)
            OR EXISTS (
              SELECT 1 FROM public.content_groups cg
              WHERE (cg.content_id = v_content.id OR cg.associated_exam_id = p_exam_id OR cg.prerequisite_exam_id = p_exam_id)
                AND cg.group_id = gm.group_id
            )
            OR EXISTS (
              SELECT 1 FROM public.lesson_exams le
              WHERE le.exam_id = p_exam_id
                AND le.group_id = gm.group_id
            )
            OR (
              v_content.group_id IS NULL
              AND EXISTS (
                SELECT 1 FROM public.groups g
                WHERE g.id = gm.group_id AND g.tenant_id = v_caller_tenant
              )
            )
          )
      ) THEN
        RAISE EXCEPTION 'NOT_AUTHORIZED: Student is not an active member of this group';
      END IF;
    ELSIF v_caller_role = 'parent' THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.group_members gm
        JOIN public.parent_students ps ON ps.student_id = gm.student_id
        WHERE ps.parent_id = v_caller_id AND gm.status = 'active'
          AND (
            (v_content.group_id IS NOT NULL AND gm.group_id = v_content.group_id)
            OR EXISTS (
              SELECT 1 FROM public.content_groups cg
              WHERE (cg.content_id = v_content.id OR cg.associated_exam_id = p_exam_id OR cg.prerequisite_exam_id = p_exam_id)
                AND cg.group_id = gm.group_id
            )
            OR EXISTS (
              SELECT 1 FROM public.lesson_exams le
              WHERE le.exam_id = p_exam_id
                AND le.group_id = gm.group_id
            )
            OR (
              v_content.group_id IS NULL
              AND EXISTS (
                SELECT 1 FROM public.groups g
                WHERE g.id = gm.group_id AND g.tenant_id = v_caller_tenant
              )
            )
          )
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

    -- Self-healing version fallback for published exams
    IF v_version.id IS NULL AND v_content.status = 'published' THEN
      SELECT * INTO v_version FROM public.exam_versions
      WHERE exam_id = p_exam_id ORDER BY version_number DESC LIMIT 1;

      IF v_version.id IS NOT NULL THEN
        UPDATE public.exam_versions
        SET status = 'published', published_at = COALESCE(published_at, now())
        WHERE id = v_version.id;
      END IF;
    END IF;
  END IF;

  IF v_version.id IS NOT NULL THEN
    SELECT COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', ec.id, 'exam_version_id', ec.exam_version_id, 'title', ec.title,
        'context_text', ec.context_text, 'image_url', ec.image_url,
        'image_meta', ec.image_meta, 'sort_order', ec.sort_order
      ) ORDER BY ec.sort_order
    ), '[]'::jsonb) INTO v_contexts
    FROM public.exam_contexts ec WHERE ec.exam_version_id = v_version.id;

    SELECT COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', q.id, 'exam_version_id', q.exam_version_id,
        'question_text', q.question_text, 'question_type', q.question_type,
        'points', q.points, 'sort_order', q.sort_order,
        'image_url', q.image_url, 'image_meta', q.image_meta,
        'context_id', q.context_id,
        'options', (
          SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
              'id', qo.id, 'question_id', qo.question_id,
              'option_text', qo.option_text, 'sort_order', qo.sort_order,
              'image_url', qo.image_url, 'image_meta', qo.image_meta,
              'is_correct', CASE WHEN v_is_teacher THEN qo.is_correct ELSE null END
            ) ORDER BY qo.sort_order
          ), '[]'::jsonb)
          FROM public.question_options qo WHERE qo.question_id = q.id
        )
      ) ORDER BY q.sort_order
    ), '[]'::jsonb) INTO v_questions
    FROM public.exam_questions q WHERE q.exam_version_id = v_version.id;
  END IF;

  IF NOT v_is_teacher THEN
    SELECT jsonb_build_object(
      'id', ea.id, 'status', ea.status, 'score', ea.score,
      'percentage', ea.percentage, 'started_at', ea.started_at,
      'submitted_at', ea.submitted_at
    ) INTO v_latest_attempt
    FROM public.exam_attempts ea
    WHERE ea.exam_id = p_exam_id AND ea.student_id = v_caller_id
    ORDER BY ea.started_at DESC LIMIT 1;

    SELECT count(*), max(score) INTO v_attempts_count, v_best_score
    FROM public.exam_attempts
    WHERE exam_id = p_exam_id AND student_id = v_caller_id AND status = 'submitted';
  END IF;

  RETURN jsonb_build_object(
    'id', v_exam.id,
    'content_id', v_content.id,
    'title', v_content.title,
    'description', v_content.description,
    'group_id', v_content.group_id,
    'group_name', v_group_name,
    'status', v_content.status,
    'duration_minutes', v_exam.duration_minutes,
    'max_score', v_exam.max_score,
    'passing_score', v_exam.passing_score,
    'shuffle_questions', v_exam.shuffle_questions,
    'show_result', v_exam.show_result,
    'allow_retake', v_exam.allow_retake,
    'start_at', v_exam.start_at,
    'end_at', v_exam.end_at,
    'folder_id', v_exam.folder_id,
    'created_at', v_exam.created_at,
    'version_id', v_version.id,
    'version_number', v_version.version_number,
    'version_status', v_version.status,
    'contexts', v_contexts,
    'questions', v_questions,
    -- Dual keys for backward/forward compatibility
    'latest_attempt', v_latest_attempt,
    'my_latest_attempt', v_latest_attempt,
    'attempts_count', v_attempts_count,
    'best_score', v_best_score,
    'my_best_score', v_best_score
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_exam_details(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_exam_details(uuid) TO authenticated;
