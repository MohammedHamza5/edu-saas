-- ============================================================================
-- Migration 0120: Fix get_exam_details RPC to return audio_url, audio_duration_seconds,
-- and image metadata for exam questions and options while preserving folder & PDF support.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_exam_details(p_exam_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', pg_temp
AS $function$
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
  v_pdf_file_id    uuid := null;
  v_pdf_file_name  text := null;
  v_pdf_file_size  bigint := null;
  v_pdf_storage_path text := null;
  v_pdf_storage_provider text := null;
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
          AND (
            (v_content.group_id IS NOT NULL AND gm.group_id = v_content.group_id)
            OR EXISTS (
              SELECT 1 FROM public.content_groups cg
              WHERE (cg.associated_exam_id = v_exam.id OR cg.prerequisite_exam_id = v_exam.id)
                AND cg.group_id = gm.group_id
            )
            OR EXISTS (
              SELECT 1 FROM public.lesson_exams le
              WHERE le.exam_id = v_exam.id AND le.group_id = gm.group_id
            )
            OR EXISTS (
              SELECT 1 FROM public.content c_parent
              WHERE (c_parent.associated_exam_id = v_exam.id OR c_parent.prerequisite_exam_id = v_exam.id)
                AND c_parent.group_id = gm.group_id
            )
            OR (
              v_content.group_id IS NULL
              AND NOT EXISTS (
                SELECT 1 FROM public.content_groups cg2
                WHERE (cg2.associated_exam_id = v_exam.id OR cg2.prerequisite_exam_id = v_exam.id)
              )
              AND NOT EXISTS (
                SELECT 1 FROM public.lesson_exams le2
                WHERE le2.exam_id = v_exam.id
              )
              AND NOT EXISTS (
                SELECT 1 FROM public.content c_parent2
                WHERE (c_parent2.associated_exam_id = v_exam.id OR c_parent2.prerequisite_exam_id = v_exam.id)
              )
            )
          )
      ) THEN
        RAISE EXCEPTION 'NOT_AUTHORIZED: Student does not belong to the exam group';
      END IF;
    ELSIF v_caller_role = 'parent' THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.parent_students ps
        JOIN public.group_members gm ON gm.student_id = ps.student_id
        WHERE ps.parent_id = v_caller_id AND gm.status = 'active'
          AND (
            (v_content.group_id IS NOT NULL AND gm.group_id = v_content.group_id)
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

  -- Resolve PDF Attachment metadata
  IF v_exam.pdf_file_id IS NOT NULL THEN
    SELECT id, COALESCE(file_name, title), file_size, storage_path, storage_provider
    INTO v_pdf_file_id, v_pdf_file_name, v_pdf_file_size, v_pdf_storage_path, v_pdf_storage_provider
    FROM public.material_library WHERE id = v_exam.pdf_file_id;

    IF v_pdf_file_id IS NULL THEN
      SELECT id, file_name, file_size, storage_path, storage_provider
      INTO v_pdf_file_id, v_pdf_file_name, v_pdf_file_size, v_pdf_storage_path, v_pdf_storage_provider
      FROM public.files WHERE id = v_exam.pdf_file_id;
    END IF;
  END IF;

  IF v_pdf_file_id IS NULL AND v_content.id IS NOT NULL THEN
    SELECT id, file_name, file_size, storage_path, storage_provider
    INTO v_pdf_file_id, v_pdf_file_name, v_pdf_file_size, v_pdf_storage_path, v_pdf_storage_provider
    FROM public.files WHERE content_id = v_content.id
    ORDER BY created_at DESC LIMIT 1;
  END IF;

  IF v_is_teacher THEN
    SELECT * INTO v_version FROM public.exam_versions
    WHERE exam_id = p_exam_id ORDER BY version_number DESC LIMIT 1;
  ELSE
    SELECT * INTO v_version FROM public.exam_versions
    WHERE exam_id = p_exam_id AND status = 'published' ORDER BY version_number DESC LIMIT 1;

    IF v_version.id IS NULL AND v_content.status = 'published' THEN
      SELECT * INTO v_version FROM public.exam_versions
      WHERE exam_id = p_exam_id ORDER BY version_number DESC LIMIT 1;

      IF v_version.id IS NOT NULL THEN
        UPDATE public.exam_versions
        SET status = 'published', published_at = COALESCE(v_content.published_at, now())
        WHERE id = v_version.id;
        v_version.status := 'published';
      END IF;
    END IF;
  END IF;

  IF v_version.id IS NOT NULL THEN
    -- 1. Contexts from public.exam_contexts
    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', ec.id,
          'exam_version_id', ec.exam_version_id,
          'title', ec.title,
          'context_text', ec.context_text,
          'image_url', ec.image_url,
          'image_meta', ec.image_meta,
          'sort_order', ec.sort_order
        ) ORDER BY ec.sort_order
      ),
      '[]'::jsonb
    ) INTO v_contexts
    FROM public.exam_contexts ec
    WHERE ec.exam_version_id = v_version.id;

    -- 2. Questions directly from public.exam_questions (preserving audio_url, audio_duration_seconds, image_url, image_meta)
    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', q.id,
          'exam_version_id', q.exam_version_id,
          'question_text', q.question_text,
          'question_type', q.question_type,
          'points', q.points,
          'sort_order', q.sort_order,
          'image_url', q.image_url,
          'image_meta', q.image_meta,
          'context_id', q.context_id,
          'audio_url', q.audio_url,
          'audio_duration_seconds', q.audio_duration_seconds,
          'options', (
            SELECT COALESCE(
              jsonb_agg(
                jsonb_build_object(
                  'id', qo.id,
                  'question_id', qo.question_id,
                  'option_text', qo.option_text,
                  'sort_order', qo.sort_order,
                  'image_url', qo.image_url,
                  'image_meta', qo.image_meta,
                  'is_correct', CASE WHEN v_is_teacher THEN qo.is_correct ELSE null END
                ) ORDER BY qo.sort_order
              ),
              '[]'::jsonb
            )
            FROM public.question_options qo
            WHERE qo.question_id = q.id
          )
        ) ORDER BY q.sort_order
      ),
      '[]'::jsonb
    ) INTO v_questions
    FROM public.exam_questions q
    WHERE q.exam_version_id = v_version.id;
  END IF;

  IF NOT v_is_teacher AND v_caller_role = 'student' THEN
    SELECT jsonb_build_object(
      'id', ea.id,
      'exam_id', ea.exam_id,
      'exam_version_id', ea.exam_version_id,
      'student_id', ea.student_id,
      'status', ea.status,
      'score', ea.score,
      'percentage', ea.percentage,
      'started_at', ea.started_at,
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
    'exam_category', COALESCE(v_exam.exam_category, 'real_test'),
    'duration_minutes', v_exam.duration_minutes,
    'max_score', v_exam.max_score,
    'passing_score', v_exam.passing_score,
    'shuffle_questions', v_exam.shuffle_questions,
    'show_result', v_exam.show_result,
    'allow_retake', v_exam.allow_retake,
    'start_at', v_exam.start_at,
    'end_at', v_exam.end_at,
    'folder_id', v_exam.folder_id,
    'folder', CASE 
      WHEN v_exam.folder_id IS NOT NULL THEN (
        SELECT jsonb_build_object(
          'id', ef.id,
          'name', ef.name,
          'color', ef.color,
          'icon', ef.icon
        )
        FROM public.exam_folders ef
        WHERE ef.id = v_exam.folder_id
        LIMIT 1
      )
      ELSE NULL
    END,
    'folder_name', (SELECT ef.name FROM public.exam_folders ef WHERE ef.id = v_exam.folder_id LIMIT 1),
    'folder_color', (SELECT ef.color FROM public.exam_folders ef WHERE ef.id = v_exam.folder_id LIMIT 1),
    'pdf_file_id', v_pdf_file_id,
    'pdf_file_name', v_pdf_file_name,
    'pdf_file_size', v_pdf_file_size,
    'pdf_storage_path', v_pdf_storage_path,
    'pdf_storage_provider', v_pdf_storage_provider,
    'created_at', v_exam.created_at,
    'version_id', v_version.id,
    'version_number', v_version.version_number,
    'version_status', v_version.status,
    'contexts', v_contexts,
    'questions', v_questions,
    'active_version', CASE 
      WHEN v_version.id IS NOT NULL THEN jsonb_build_object(
        'id', v_version.id,
        'exam_id', v_exam.id,
        'version_number', v_version.version_number,
        'status', v_version.status,
        'created_at', COALESCE(v_version.created_at, v_exam.created_at),
        'questions', v_questions,
        'contexts', v_contexts
      )
      ELSE null
    END,
    'latest_attempt', v_latest_attempt,
    'my_latest_attempt', v_latest_attempt,
    'attempts_count', v_attempts_count,
    'best_score', v_best_score,
    'my_best_score', v_best_score
  );
END;
$function$;
