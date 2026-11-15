-- ============================================================================
-- Migration 0112: Add Audio Explanation to Exam Questions & Audio Storage
-- ============================================================================
-- 1. Adds audio_url (text) and audio_duration_seconds (int) to public.exam_questions.
-- 2. Creates the 'exam-audio' storage bucket with RLS policies for teachers and students.
-- 3. Updates get_exam_details RPC to return audio_url and audio_duration_seconds.
-- 4. Updates get_exam_review RPC to return audio_url and audio_duration_seconds.
-- 5. Updates get_student_mistakes_questions RPC to return audio_url and audio_duration_seconds.
-- ============================================================================

-- 1. Add audio explanation columns to exam_questions
ALTER TABLE public.exam_questions 
  ADD COLUMN IF NOT EXISTS audio_url text NULL,
  ADD COLUMN IF NOT EXISTS audio_duration_seconds integer NULL;

COMMENT ON COLUMN public.exam_questions.audio_url IS 
  'Relative storage path or URL to the teacher voice recording explaining this question';

COMMENT ON COLUMN public.exam_questions.audio_duration_seconds IS 
  'Duration of the audio recording in seconds for instant waveform/time rendering';

-- 2. Storage Bucket setup for audio recordings
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'exam-audio',
  'exam-audio',
  true,
  20971520, -- 20MB limit per audio file
  ARRAY['audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/ogg', 'audio/x-m4a', 'audio/wav', 'audio/webm']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 20971520,
  allowed_mime_types = ARRAY['audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/ogg', 'audio/x-m4a', 'audio/wav', 'audio/webm'];

-- Storage RLS Policies for exam-audio
DROP POLICY IF EXISTS "Teacher manage exam-audio" ON storage.objects;
CREATE POLICY "Teacher manage exam-audio"
ON storage.objects FOR ALL TO authenticated
USING (
  bucket_id = 'exam-audio'
  AND (SELECT public.tenant_is_active())
  AND (SELECT public.has_role('teacher'))
)
WITH CHECK (
  bucket_id = 'exam-audio'
  AND (SELECT public.tenant_is_active())
  AND (SELECT public.has_role('teacher'))
);

DROP POLICY IF EXISTS "Allow authenticated read exam-audio" ON storage.objects;
CREATE POLICY "Allow authenticated read exam-audio"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'exam-audio');

-- 3. Update get_exam_details to return question audio explanation fields
CREATE OR REPLACE FUNCTION public.get_exam_details(p_exam_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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

  -- Resolve PDF Attachment metadata (Check material_library first, then files)
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
        'audio_url', q.audio_url,
        'audio_duration_seconds', q.audio_duration_seconds,
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

REVOKE ALL ON FUNCTION public.get_exam_details(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_exam_details(uuid) TO authenticated;

-- 4. Update get_exam_review to include audio_url and audio_duration_seconds
CREATE OR REPLACE FUNCTION public.get_exam_review(p_attempt_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id   uuid := auth.uid();
  v_caller_role text;
  v_caller_tenant uuid;
  v_attempt     record;
  v_exam        record;
  v_questions   jsonb := '[]'::jsonb;
  v_answers     jsonb := '[]'::jsonb;
  v_is_authorized boolean := false;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be authenticated';
  END IF;

  SELECT * INTO v_attempt
  FROM public.exam_attempts
  WHERE id = p_attempt_id;

  IF v_attempt.id IS NULL THEN
    RAISE EXCEPTION 'ATTEMPT_NOT_FOUND: Attempt does not exist';
  END IF;

  SELECT role, tenant_id INTO v_caller_role, v_caller_tenant
  FROM public.users
  WHERE id = v_caller_id AND status = 'active';

  SELECT * INTO v_exam
  FROM public.exams
  WHERE id = v_attempt.exam_id;

  IF v_attempt.student_id = v_caller_id THEN
    v_is_authorized := true;
  ELSIF v_caller_role = 'teacher' AND v_caller_tenant = v_exam.tenant_id THEN
    v_is_authorized := true;
  ELSIF v_caller_role = 'parent' AND EXISTS (
    SELECT 1 FROM public.parent_students ps
    WHERE ps.parent_id = v_caller_id AND ps.student_id = v_attempt.student_id
  ) THEN
    v_is_authorized := true;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: You are not authorized to view this attempt review';
  END IF;

  IF v_attempt.status NOT IN ('submitted', 'expired') THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only submitted or expired attempts can be reviewed';
  END IF;

  -- Build questions with audio_url and audio_duration_seconds
  SELECT COALESCE(jsonb_agg(q_item), '[]'::jsonb) INTO v_questions
  FROM (
    SELECT
      eq.id,
      eq.exam_version_id,
      eq.question_text,
      eq.question_type,
      eq.points,
      eq.sort_order,
      eq.image_url,
      eq.image_meta,
      eq.context_id,
      eq.audio_url,
      eq.audio_duration_seconds,
      (
        SELECT COALESCE(jsonb_agg(
          jsonb_build_object(
            'id', qo.id,
            'question_id', qo.question_id,
            'option_text', qo.option_text,
            'sort_order', qo.sort_order,
            'image_url', qo.image_url,
            'image_meta', qo.image_meta,
            'is_correct', qo.is_correct
          ) ORDER BY qo.sort_order, qo.id
        ), '[]'::jsonb)
        FROM public.question_options qo
        WHERE qo.question_id = eq.id
      ) AS options
    FROM public.exam_questions eq
    WHERE eq.exam_version_id = v_attempt.exam_version_id
    ORDER BY eq.sort_order, eq.id
  ) q_item;

  -- Build answers including text_answer for grid_in questions
  SELECT COALESCE(jsonb_agg(a_item), '[]'::jsonb) INTO v_answers
  FROM (
    SELECT
      ea.id,
      ea.attempt_id,
      ea.question_id,
      ea.selected_option_id,
      ea.text_answer,
      ea.is_correct,
      ea.points_earned,
      ea.answered_at
    FROM public.exam_answers ea
    WHERE ea.attempt_id = v_attempt.id
  ) a_item;

  RETURN jsonb_build_object(
    'id', v_attempt.id,
    'exam_id', v_attempt.exam_id,
    'exam_version_id', v_attempt.exam_version_id,
    'student_id', v_attempt.student_id,
    'started_at', v_attempt.started_at,
    'submitted_at', v_attempt.submitted_at,
    'status', v_attempt.status,
    'score', v_attempt.score,
    'percentage', v_attempt.percentage,
    'questions', v_questions,
    'answers', v_answers
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_exam_review(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_exam_review(uuid) TO authenticated;

-- 5. Update get_student_mistakes_questions to include audio_url and audio_duration_seconds
CREATE OR REPLACE FUNCTION public.get_student_mistakes_questions(
  p_student_id UUID,
  p_exam_id UUID DEFAULT NULL,
  p_only_unresolved BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_questions JSONB;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  IF v_caller != p_student_id AND NOT public.has_role('teacher') THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'mistake_id', sm.id,
        'question_id', q.id,
        'question_text', q.question_text,
        'question_type', q.question_type,
        'points', q.points,
        'sort_order', q.sort_order,
        'image_url', q.image_url,
        'image_meta', q.image_meta,
        'audio_url', q.audio_url,
        'audio_duration_seconds', q.audio_duration_seconds,
        'is_resolved', sm.is_resolved,
        'failure_count', sm.failure_count,
        'last_failed_at', sm.last_failed_at,
        'source_exam_id', sm.source_exam_id,
        'source_exam_title', COALESCE(e.title, c.title, 'اختبار'),
        'lesson_title', c.title,
        'last_selected_option_id', sm.selected_option_id,
        'is_skipped', (sm.selected_option_id IS NULL),
        'selected_option_text', (
          SELECT opt.option_text 
          FROM public.question_options opt 
          WHERE opt.id = sm.selected_option_id
          LIMIT 1
        ),
        'options', (
          -- Safe options projection without is_correct
          SELECT COALESCE(
            jsonb_agg(
              jsonb_build_object(
                'id', opt.id,
                'option_text', opt.option_text,
                'sort_order', opt.sort_order,
                'image_url', opt.image_url,
                'image_meta', opt.image_meta
              ) ORDER BY opt.sort_order ASC
            ),
            '[]'::jsonb
          )
          FROM public.question_options opt
          WHERE opt.question_id = q.id
        )
      )
      ORDER BY sm.last_failed_at DESC
    ),
    '[]'::jsonb
  )
  INTO v_questions
  FROM public.student_mistakes sm
  JOIN public.exam_questions q ON q.id = sm.question_id
  JOIN public.exams e ON e.id = sm.source_exam_id
  LEFT JOIN public.content c ON c.id = e.content_id
  WHERE sm.student_id = p_student_id
    AND (p_exam_id IS NULL OR sm.source_exam_id = p_exam_id)
    AND (NOT p_only_unresolved OR sm.is_resolved = false);

  RETURN v_questions;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_student_mistakes_questions(UUID, UUID, BOOLEAN) TO authenticated;


-- 6. Update update_draft_exam_questions to preserve audio_url and audio_duration_seconds
CREATE OR REPLACE FUNCTION public.update_draft_exam_questions(
  p_exam_id uuid,
  p_title text,
  p_duration_minutes integer DEFAULT 60,
  p_max_score integer DEFAULT 100,
  p_passing_score integer DEFAULT NULL,
  p_shuffle_questions boolean DEFAULT false,
  p_show_result boolean DEFAULT true,
  p_allow_retake boolean DEFAULT false,
  p_is_published boolean DEFAULT false,
  p_questions jsonb DEFAULT '[]'::jsonb,
  p_pdf_file_id uuid DEFAULT NULL,
  p_clear_pdf boolean DEFAULT false
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
  v_version_id uuid;
  v_version_status text;
  v_version_number int;
  v_max_version_number int;
  q_elem jsonb;
  opt_elem jsonb;
  v_new_q_id uuid;
  v_idx int;
  v_opt_idx int;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: Authentication required';
  END IF;

  SELECT tenant_id INTO v_tenant_id
  FROM public.users
  WHERE id = v_caller_id AND role = 'teacher' AND status = 'active';

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only active teachers can edit exams';
  END IF;

  -- 1. Find exam and verify tenant
  SELECT content_id INTO v_content_id
  FROM public.exams
  WHERE id = p_exam_id AND tenant_id = v_tenant_id;

  IF v_content_id IS NULL THEN
    RAISE EXCEPTION 'NOT_FOUND: Exam does not exist or does not belong to your academy';
  END IF;

  -- Verify pdf file belongs to tenant if provided
  IF p_pdf_file_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.material_library WHERE id = p_pdf_file_id AND tenant_id = v_tenant_id
    ) AND NOT EXISTS (
      SELECT 1 FROM public.files WHERE id = p_pdf_file_id AND tenant_id = v_tenant_id
    ) THEN
      RAISE EXCEPTION 'NOT_FOUND: Attached PDF does not exist in your academy files';
    END IF;
  END IF;

  -- 2. Update content table
  UPDATE public.content
  SET
    title = trim(p_title),
    status = CASE WHEN p_is_published THEN 'published' ELSE status END,
    published_at = CASE WHEN p_is_published THEN COALESCE(published_at, now()) ELSE published_at END,
    updated_at = now()
  WHERE id = v_content_id AND tenant_id = v_tenant_id;

  -- 3. Update exams table
  UPDATE public.exams
  SET
    duration_minutes = COALESCE(p_duration_minutes, duration_minutes),
    max_score = COALESCE(p_max_score, max_score),
    passing_score = p_passing_score,
    shuffle_questions = COALESCE(p_shuffle_questions, shuffle_questions),
    show_result = COALESCE(p_show_result, show_result),
    allow_retake = COALESCE(p_allow_retake, allow_retake),
    pdf_file_id = CASE WHEN p_clear_pdf THEN NULL WHEN p_pdf_file_id IS NOT NULL THEN p_pdf_file_id ELSE pdf_file_id END,
    updated_at = now()
  WHERE id = p_exam_id AND tenant_id = v_tenant_id;

  -- 4. Check if student attempts exist for this exam
  SELECT count(*) INTO v_attempts_count
  FROM public.exam_attempts
  WHERE exam_id = p_exam_id;

  -- 5. Manage versioning
  IF v_attempts_count > 0 THEN
    -- Student attempts exist: preserve history by creating a new version
    SELECT COALESCE(MAX(version_number), 1) INTO v_max_version_number
    FROM public.exam_versions
    WHERE exam_id = p_exam_id;

    v_version_number := v_max_version_number + 1;

    INSERT INTO public.exam_versions (
      exam_id,
      version_number,
      status,
      created_by,
      published_at
    )
    VALUES (
      p_exam_id,
      v_version_number,
      CASE WHEN p_is_published THEN 'published' ELSE 'draft' END,
      v_caller_id,
      CASE WHEN p_is_published THEN now() ELSE NULL END
    )
    RETURNING id INTO v_version_id;
  ELSE
    -- No attempts: reuse or update the existing latest version
    SELECT id, status, version_number INTO v_version_id, v_version_status, v_version_number
    FROM public.exam_versions
    WHERE exam_id = p_exam_id
    ORDER BY version_number DESC
    LIMIT 1;

    IF v_version_id IS NULL THEN
      v_version_number := 1;
      INSERT INTO public.exam_versions (
        exam_id,
        version_number,
        status,
        created_by,
        published_at
      )
      VALUES (
        p_exam_id,
        1,
        CASE WHEN p_is_published THEN 'published' ELSE 'draft' END,
        v_caller_id,
        CASE WHEN p_is_published THEN now() ELSE NULL END
      )
      RETURNING id INTO v_version_id;
    ELSE
      -- Clean up old questions for this version
      DELETE FROM public.question_options
      WHERE question_id IN (
        SELECT id FROM public.exam_questions WHERE exam_version_id = v_version_id
      );

      DELETE FROM public.exam_questions
      WHERE exam_version_id = v_version_id;

      UPDATE public.exam_versions
      SET
        status = CASE WHEN p_is_published THEN 'published' ELSE status END,
        published_at = CASE WHEN p_is_published THEN COALESCE(published_at, now()) ELSE published_at END
      WHERE id = v_version_id;
    END IF;
  END IF;

  -- 6. Insert questions and options with audio explanation support
  v_idx := 0;
  FOR q_elem IN SELECT * FROM jsonb_array_elements(p_questions)
  LOOP
    v_idx := v_idx + 1;

    INSERT INTO public.exam_questions (
      exam_version_id,
      question_text,
      question_type,
      points,
      sort_order,
      image_url,
      image_meta,
      context_id,
      audio_url,
      audio_duration_seconds
    )
    VALUES (
      v_version_id,
      COALESCE(trim(q_elem->>'question_text'), ''),
      COALESCE(q_elem->>'question_type', 'multiple_choice'),
      COALESCE((q_elem->>'points')::integer, 1),
      COALESCE((q_elem->>'sort_order')::integer, v_idx),
      q_elem->>'image_url',
      CASE WHEN q_elem ? 'image_meta' AND q_elem->'image_meta' IS NOT NULL AND jsonb_typeof(q_elem->'image_meta') = 'object' THEN q_elem->'image_meta' ELSE NULL END,
      CASE WHEN q_elem ? 'context_id' AND (q_elem->>'context_id') IS NOT NULL AND (q_elem->>'context_id') != '' THEN (q_elem->>'context_id')::uuid ELSE NULL END,
      NULLIF(trim(q_elem->>'audio_url'), ''),
      CASE WHEN q_elem ? 'audio_duration_seconds' AND (q_elem->>'audio_duration_seconds') IS NOT NULL AND (q_elem->>'audio_duration_seconds') != '' THEN (q_elem->>'audio_duration_seconds')::integer ELSE NULL END
    )
    RETURNING id INTO v_new_q_id;

    IF q_elem ? 'options' AND jsonb_typeof(q_elem->'options') = 'array' THEN
      v_opt_idx := 0;
      FOR opt_elem IN SELECT * FROM jsonb_array_elements(q_elem->'options')
      LOOP
        v_opt_idx := v_opt_idx + 1;
        INSERT INTO public.question_options (
          question_id,
          option_text,
          sort_order,
          is_correct,
          image_url,
          image_meta
        )
        VALUES (
          v_new_q_id,
          COALESCE(trim(opt_elem->>'option_text'), ''),
          COALESCE((opt_elem->>'sort_order')::integer, v_opt_idx),
          COALESCE((opt_elem->>'is_correct')::boolean, false),
          opt_elem->>'image_url',
          CASE WHEN opt_elem ? 'image_meta' AND opt_elem->'image_meta' IS NOT NULL AND jsonb_typeof(opt_elem->'image_meta') = 'object' THEN opt_elem->'image_meta' ELSE NULL END
        );
      END LOOP;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'exam_id', p_exam_id,
    'version_id', v_version_id,
    'version_number', v_version_number,
    'questions_count', v_idx,
    'is_published', p_is_published
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_draft_exam_questions(
  uuid, text, integer, integer, integer, boolean, boolean, boolean, boolean, jsonb, uuid, boolean
) TO authenticated;
