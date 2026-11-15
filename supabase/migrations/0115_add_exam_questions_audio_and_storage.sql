-- ============================================================================
-- 0115_add_exam_questions_audio_and_storage.sql
-- 1. Adds audio_url, audio_duration_seconds, and video_url to public.exam_questions
-- 2. Provisions 'exam-audio' public bucket with proper Storage RLS policies
-- 3. Updates create_exam_with_questions to persist audio and exam_category
-- 4. Updates update_draft_exam_questions to persist audio
-- 5. Updates get_exam_details, start_exam, get_exam_review, and 
--    get_student_mistakes_questions to return audio metadata to teacher and students
-- ============================================================================

-- 0. Ensure student_mistakes and exam_attempts taxonomy columns exist
ALTER TABLE public.student_mistakes
  ADD COLUMN IF NOT EXISTS reflection_reason text
  CHECK (reflection_reason IS NULL OR reflection_reason IN ('concept_gap', 'careless_error', 'misread_question', 'time_pressure'));

ALTER TABLE public.exam_attempts
  ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

ALTER TABLE public.exam_answers
  ADD COLUMN IF NOT EXISTS time_spent_seconds integer DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS is_flagged_guess boolean DEFAULT false;

-- 1. Add audio and video columns to public.exam_questions
ALTER TABLE public.exam_questions 
  ADD COLUMN IF NOT EXISTS audio_url TEXT NULL,
  ADD COLUMN IF NOT EXISTS audio_duration_seconds INTEGER NULL,
  ADD COLUMN IF NOT EXISTS video_url TEXT NULL;

-- 2. Provision 'exam-audio' Storage Bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'exam-audio',
  'exam-audio',
  true,
  20971520, -- 20 MB
  ARRAY['audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/wav', 'audio/ogg', 'audio/webm', 'audio/x-m4a']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 20971520,
  allowed_mime_types = ARRAY['audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/wav', 'audio/ogg', 'audio/webm', 'audio/x-m4a'];

-- Ensure group-content also accepts audio types as fallback
UPDATE storage.buckets
SET allowed_mime_types = ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'application/pdf', 'audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/wav', 'audio/ogg', 'audio/webm', 'audio/x-m4a']
WHERE id = 'group-content';

-- 3. Storage RLS policies for exam-audio bucket
DO $$
BEGIN
  DROP POLICY IF EXISTS "exam_audio_public_read" ON storage.objects;
  DROP POLICY IF EXISTS "exam_audio_authenticated_insert" ON storage.objects;
  DROP POLICY IF EXISTS "exam_audio_authenticated_update" ON storage.objects;
  DROP POLICY IF EXISTS "exam_audio_authenticated_delete" ON storage.objects;
END $$;

CREATE POLICY "exam_audio_public_read" ON storage.objects
  FOR SELECT TO authenticated, anon
  USING (bucket_id = 'exam-audio');

CREATE POLICY "exam_audio_authenticated_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'exam-audio');

CREATE POLICY "exam_audio_authenticated_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'exam-audio');

CREATE POLICY "exam_audio_authenticated_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'exam-audio');

-- 4. Update create_exam_with_questions RPC to persist audio and exam_category
DROP FUNCTION IF EXISTS public.create_exam_with_questions(
  text, uuid, integer, integer, integer, boolean, boolean, boolean, boolean, timestamp with time zone, timestamp with time zone, jsonb, uuid
);

CREATE OR REPLACE FUNCTION public.create_exam_with_questions(
  p_title text,
  p_group_id uuid DEFAULT NULL,
  p_duration_minutes integer DEFAULT 60,
  p_max_score integer DEFAULT 100,
  p_passing_score integer DEFAULT NULL,
  p_shuffle_questions boolean DEFAULT false,
  p_show_result boolean DEFAULT true,
  p_allow_retake boolean DEFAULT false,
  p_is_published boolean DEFAULT false,
  p_start_at timestamptz DEFAULT NULL,
  p_end_at timestamptz DEFAULT NULL,
  p_questions jsonb DEFAULT '[]'::jsonb,
  p_pdf_file_id uuid DEFAULT NULL,
  p_exam_category text DEFAULT 'real_test'
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
  v_exam_id uuid;
  v_version_id uuid;
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
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only active teachers can create exams';
  END IF;

  -- Verify group_id if provided
  IF p_group_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.groups
      WHERE id = p_group_id AND tenant_id = v_tenant_id
    ) THEN
      RAISE EXCEPTION 'NOT_FOUND: Group does not exist or does not belong to your academy';
    END IF;
  END IF;

  -- Verify pdf_file_id if provided
  IF p_pdf_file_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.material_library
      WHERE id = p_pdf_file_id AND tenant_id = v_tenant_id
    ) AND NOT EXISTS (
      SELECT 1 FROM public.files
      WHERE id = p_pdf_file_id AND tenant_id = v_tenant_id
    ) THEN
      RAISE EXCEPTION 'NOT_FOUND: Attached PDF does not exist or does not belong to your academy';
    END IF;
  END IF;

  -- 1. Create content record
  INSERT INTO public.content (
    tenant_id,
    group_id,
    title,
    type,
    status,
    published_at
  )
  VALUES (
    v_tenant_id,
    p_group_id,
    trim(p_title),
    'exam',
    CASE WHEN p_is_published THEN 'published' ELSE 'draft' END,
    CASE WHEN p_is_published THEN now() ELSE NULL END
  )
  RETURNING id INTO v_content_id;

  -- 2. Create exams record (with exam_category)
  INSERT INTO public.exams (
    content_id,
    tenant_id,
    duration_minutes,
    max_score,
    passing_score,
    shuffle_questions,
    show_result,
    allow_retake,
    start_at,
    end_at,
    pdf_file_id,
    exam_category
  )
  VALUES (
    v_content_id,
    v_tenant_id,
    p_duration_minutes,
    p_max_score,
    p_passing_score,
    p_shuffle_questions,
    p_show_result,
    p_allow_retake,
    p_start_at,
    p_end_at,
    p_pdf_file_id,
    COALESCE(p_exam_category, 'real_test')
  )
  RETURNING id INTO v_exam_id;

  -- 3. Create initial version record
  INSERT INTO public.exam_versions (
    exam_id,
    version_number,
    status,
    created_at,
    published_at
  )
  VALUES (
    v_exam_id,
    1,
    CASE WHEN p_is_published THEN 'published' ELSE 'draft' END,
    now(),
    CASE WHEN p_is_published THEN now() ELSE NULL END
  )
  RETURNING id INTO v_version_id;

  -- 4. Atomically insert all questions and options with audio support
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
      q_elem->>'audio_url',
      CASE WHEN q_elem ? 'audio_duration_seconds' AND (q_elem->>'audio_duration_seconds') IS NOT NULL AND (q_elem->>'audio_duration_seconds') != '' THEN (q_elem->>'audio_duration_seconds')::integer ELSE NULL END
    )
    RETURNING id INTO v_new_q_id;

    -- Insert options for this question
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
    'exam_id', v_exam_id,
    'content_id', v_content_id,
    'version_id', v_version_id,
    'questions_count', v_idx,
    'is_published', p_is_published,
    'category', COALESCE(p_exam_category, 'real_test')
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_exam_with_questions(
  text, uuid, integer, integer, integer, boolean, boolean, boolean, boolean, timestamptz, timestamptz, jsonb, uuid, text
) TO authenticated;

-- 5. Update update_draft_exam_questions RPC to persist audio and exam_category
DROP FUNCTION IF EXISTS public.update_draft_exam_questions(
  uuid, text, integer, integer, integer, boolean, boolean, boolean, boolean, jsonb, uuid, boolean
);

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
  p_clear_pdf boolean DEFAULT false,
  p_exam_category text DEFAULT NULL
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
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only active teachers can update exams';
  END IF;

  -- 1. Locate exam and verify ownership
  SELECT content_id INTO v_content_id
  FROM public.exams
  WHERE id = p_exam_id AND tenant_id = v_tenant_id;

  IF v_content_id IS NULL THEN
    RAISE EXCEPTION 'NOT_FOUND: Exam does not exist or does not belong to your academy';
  END IF;

  -- Verify pdf_file_id if provided
  IF p_pdf_file_id IS NOT NULL AND NOT p_clear_pdf THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.material_library
      WHERE id = p_pdf_file_id AND tenant_id = v_tenant_id
    ) AND NOT EXISTS (
      SELECT 1 FROM public.files
      WHERE id = p_pdf_file_id AND tenant_id = v_tenant_id
    ) THEN
      RAISE EXCEPTION 'NOT_FOUND: Attached PDF does not exist or does not belong to your academy';
    END IF;
  END IF;

  -- 2. Update content metadata
  UPDATE public.content
  SET
    title = trim(p_title),
    status = CASE WHEN p_is_published THEN 'published' ELSE status END,
    published_at = CASE WHEN p_is_published AND published_at IS NULL THEN now() ELSE published_at END,
    updated_at = now()
  WHERE id = v_content_id;

  -- 3. Update exam settings
  UPDATE public.exams
  SET
    duration_minutes = p_duration_minutes,
    max_score = p_max_score,
    passing_score = p_passing_score,
    shuffle_questions = p_shuffle_questions,
    show_result = p_show_result,
    allow_retake = p_allow_retake,
    exam_category = CASE
      WHEN p_exam_category IS NOT NULL AND p_exam_category IN ('real_test', 'question_bank')
      THEN p_exam_category
      ELSE exam_category
    END,
    pdf_file_id = CASE
      WHEN p_clear_pdf THEN NULL
      WHEN p_pdf_file_id IS NOT NULL THEN p_pdf_file_id
      ELSE pdf_file_id
    END,
    updated_at = now()
  WHERE id = p_exam_id;

  -- 4. Check student attempts count for seamless versioning
  SELECT count(*) INTO v_attempts_count
  FROM public.exam_attempts
  WHERE exam_id = p_exam_id;

  IF v_attempts_count > 0 THEN
    SELECT COALESCE(max(version_number), 1) INTO v_max_version_number
    FROM public.exam_versions
    WHERE exam_id = p_exam_id;

    UPDATE public.exam_versions
    SET status = 'archived'
    WHERE exam_id = p_exam_id AND status = 'published';

    v_version_number := v_max_version_number + 1;
    v_version_status := CASE WHEN p_is_published THEN 'published' ELSE 'draft' END;

    INSERT INTO public.exam_versions (
      exam_id,
      version_number,
      status,
      created_at,
      published_at
    )
    VALUES (
      p_exam_id,
      v_version_number,
      v_version_status,
      now(),
      CASE WHEN p_is_published THEN now() ELSE NULL END
    )
    RETURNING id INTO v_version_id;
  ELSE
    SELECT id, version_number INTO v_version_id, v_version_number
    FROM public.exam_versions
    WHERE exam_id = p_exam_id
    ORDER BY version_number DESC
    LIMIT 1;

    IF v_version_id IS NULL THEN
      INSERT INTO public.exam_versions (
        exam_id,
        version_number,
        status,
        created_at,
        published_at
      )
      VALUES (
        p_exam_id,
        1,
        CASE WHEN p_is_published THEN 'published' ELSE 'draft' END,
        now(),
        CASE WHEN p_is_published THEN now() ELSE NULL END
      )
      RETURNING id INTO v_version_id;
    ELSE
      UPDATE public.exam_versions
      SET
        status = CASE WHEN p_is_published THEN 'published' ELSE 'draft' END,
        published_at = CASE WHEN p_is_published AND published_at IS NULL THEN now() ELSE published_at END
      WHERE id = v_version_id;

      DELETE FROM public.exam_questions WHERE exam_version_id = v_version_id;
    END IF;
  END IF;

  -- 5. Insert questions with audio support
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
      q_elem->>'audio_url',
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
  uuid, text, integer, integer, integer, boolean, boolean, boolean, boolean, jsonb, uuid, boolean, text
) TO authenticated;

-- 6. Update get_exam_details RPC to return audio metadata
CREATE OR REPLACE FUNCTION public.get_exam_details(p_exam_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_caller_role text;
  v_caller_tenant uuid;
  v_is_teacher boolean := false;
  v_exam record;
  v_content record;
  v_version record;
  v_questions jsonb := '[]'::jsonb;
  v_contexts jsonb := '[]'::jsonb;
  v_group_name text;
  v_latest_attempt jsonb := null;
  v_attempts_count int := 0;
  v_best_score numeric := null;
  v_pdf_file_id uuid;
  v_pdf_file_name text;
  v_pdf_file_size bigint;
  v_pdf_storage_path text;
  v_pdf_storage_provider text;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be authenticated';
  END IF;

  SELECT role, tenant_id INTO v_caller_role, v_caller_tenant
  FROM public.users WHERE id = v_caller_id;

  v_is_teacher := (v_caller_role = 'teacher');

  SELECT * INTO v_exam FROM public.exams WHERE id = p_exam_id;
  IF v_exam.id IS NULL THEN
    RAISE EXCEPTION 'EXAM_NOT_FOUND: Exam does not exist';
  END IF;

  IF v_exam.tenant_id != v_caller_tenant THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Cross-tenant access forbidden';
  END IF;

  SELECT * INTO v_content FROM public.content WHERE id = v_exam.content_id;
  IF v_content.id IS NULL THEN
    RAISE EXCEPTION 'CONTENT_NOT_FOUND: Exam content record not found';
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
        SET status = 'published', published_at = COALESCE(published_at, now())
        WHERE id = v_version.id;
      END IF;
    END IF;
  END IF;

  IF v_version.id IS NOT NULL THEN
    SELECT COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', ec.id, 'exam_version_id', ec.exam_version_id,
        'title', ec.title, 'context_text', ec.context_text,
        'image_url', ec.image_url, 'image_meta', ec.image_meta,
        'sort_order', ec.sort_order
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
    'pdf_file_id', v_pdf_file_id,
    'pdf_file_name', v_pdf_file_name,
    'pdf_file_size', v_pdf_file_size,
    'pdf_storage_path', v_pdf_storage_path,
    'pdf_storage_provider', v_pdf_storage_provider,
    'created_at', v_exam.created_at,
    'version_id', v_version.id,
    'version_number', v_version.version_number,
    'version_status', v_version.status,
    'questions_count', jsonb_array_length(v_questions),
    'contexts', v_contexts,
    'questions', v_questions,
    'latest_attempt', v_latest_attempt,
    'attempts_count', v_attempts_count,
    'best_score', v_best_score
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_exam_details(uuid) TO authenticated;

-- 7. Update start_exam RPC to return audio metadata to student
CREATE OR REPLACE FUNCTION public.start_exam(p_exam_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id        uuid := auth.uid();
  v_tenant_id         uuid;
  v_exam              record;
  v_version           record;
  v_attempt_id        uuid;
  v_active_attempt    record;
  v_passed_attempt    record;
  v_is_lecture_exam   boolean := false;
  v_remaining_seconds integer;
  v_questions         jsonb := '[]'::jsonb;
  v_contexts          jsonb := '[]'::jsonb;
  v_started_at        timestamptz;
  v_event_group_id    uuid;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be authenticated';
  END IF;

  SELECT tenant_id INTO v_tenant_id
  FROM public.users
  WHERE id = v_student_id AND role = 'student' AND status = 'active';

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only active students can take exams';
  END IF;

  SELECT
    e.*,
    c.status AS content_status,
    c.title AS content_title,
    c.group_id AS content_group_id
  INTO v_exam
  FROM public.exams e
  JOIN public.content c ON c.id = e.content_id
  WHERE e.id = p_exam_id;

  IF v_exam.id IS NULL THEN
    RAISE EXCEPTION 'EXAM_NOT_FOUND: Exam does not exist';
  END IF;

  IF v_exam.tenant_id != v_tenant_id THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Exam belongs to a different academy';
  END IF;

  IF v_exam.content_status != 'published' THEN
    RAISE EXCEPTION 'EXAM_NOT_PUBLISHED: This exam is not published yet';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.lesson_exams le WHERE le.exam_id = p_exam_id
    UNION
    SELECT 1 FROM public.content_groups cg
    WHERE (cg.associated_exam_id = p_exam_id OR cg.prerequisite_exam_id = p_exam_id)
      AND cg.is_published = true
  ) INTO v_is_lecture_exam;

  IF NOT v_is_lecture_exam THEN
    IF v_exam.start_at IS NOT NULL AND now() < v_exam.start_at THEN
      RAISE EXCEPTION 'EXAM_NOT_STARTED: Exam starts at %', v_exam.start_at;
    END IF;
    IF v_exam.end_at IS NOT NULL AND now() > v_exam.end_at THEN
      RAISE EXCEPTION 'EXAM_EXPIRED: Exam window closed at %', v_exam.end_at;
    END IF;
  END IF;

  SELECT * INTO v_active_attempt
  FROM public.exam_attempts
  WHERE exam_id = p_exam_id AND student_id = v_student_id AND status = 'in_progress'
  ORDER BY started_at DESC
  LIMIT 1;

  IF v_active_attempt.id IS NOT NULL THEN
    IF NOT v_is_lecture_exam AND COALESCE(v_exam.duration_minutes, 0) > 0 THEN
      IF now() > (v_active_attempt.started_at + (v_exam.duration_minutes * interval '1 minute')) THEN
        UPDATE public.exam_attempts
        SET status = 'expired', submitted_at = now()
        WHERE id = v_active_attempt.id;
      ELSE
        v_attempt_id := v_active_attempt.id;
        v_started_at := v_active_attempt.started_at;
      END IF;
    ELSE
      v_attempt_id := v_active_attempt.id;
      v_started_at := v_active_attempt.started_at;
    END IF;
  END IF;

  IF v_attempt_id IS NULL THEN
    IF v_is_lecture_exam THEN
      SELECT * INTO v_passed_attempt
      FROM public.exam_attempts
      WHERE exam_id = p_exam_id AND student_id = v_student_id AND status = 'submitted'
        AND percentage >= COALESCE(v_exam.passing_score, 0)
      ORDER BY submitted_at DESC
      LIMIT 1;
    ELSE
      IF NOT v_exam.allow_retake AND EXISTS (
        SELECT 1 FROM public.exam_attempts
        WHERE exam_id = p_exam_id AND student_id = v_student_id AND status IN ('submitted', 'expired')
      ) THEN
        RAISE EXCEPTION 'ATTEMPTS_LIMIT_REACHED: Retake is not allowed for this exam';
      END IF;
    END IF;

    SELECT * INTO v_version
    FROM public.exam_versions
    WHERE exam_id = p_exam_id AND status = 'published'
    ORDER BY version_number DESC
    LIMIT 1;

    IF v_version.id IS NULL THEN
      SELECT * INTO v_version
      FROM public.exam_versions
      WHERE exam_id = p_exam_id
      ORDER BY version_number DESC
      LIMIT 1;

      IF v_version.id IS NOT NULL THEN
        UPDATE public.exam_versions
        SET status = 'published', published_at = COALESCE(published_at, now())
        WHERE id = v_version.id;
      ELSE
        RAISE EXCEPTION 'EXAM_NOT_FOUND: No published version available for this exam';
      END IF;
    END IF;

    v_started_at := now();

    INSERT INTO public.exam_attempts (exam_id, exam_version_id, student_id, started_at, status)
    VALUES (p_exam_id, v_version.id, v_student_id, v_started_at, 'in_progress')
    RETURNING id INTO v_attempt_id;
  ELSE
    SELECT * INTO v_version
    FROM public.exam_versions
    WHERE id = v_active_attempt.exam_version_id;
  END IF;

  SELECT COALESCE(jsonb_agg(ctx_item), '[]'::jsonb) INTO v_contexts
  FROM (
    SELECT ec.id, ec.title, ec.context_text, ec.image_url, ec.image_meta, ec.sort_order
    FROM public.exam_contexts ec
    WHERE ec.exam_version_id = v_version.id
    ORDER BY ec.sort_order
  ) ctx_item;

  IF v_exam.shuffle_questions THEN
    PERFORM setseed((abs(hashtext(v_attempt_id::text)) % 2147483647)::double precision / 2147483647.0);
  END IF;

  SELECT COALESCE(jsonb_agg(q_item), '[]'::jsonb) INTO v_questions
  FROM (
    SELECT
      eq.id, eq.question_text, eq.question_type, eq.points, eq.sort_order,
      eq.image_url, eq.image_meta, eq.context_id,
      (
        SELECT COALESCE(jsonb_agg(
          jsonb_build_object(
            'id', qo.id,
            'option_text', qo.option_text,
            'sort_order', qo.sort_order,
            'image_url', qo.image_url,
            'image_meta', qo.image_meta
          ) ORDER BY qo.sort_order
        ), '[]'::jsonb)
        FROM public.question_options qo
        WHERE qo.question_id = eq.id
      ) AS options
    FROM public.exam_questions eq
    WHERE eq.exam_version_id = v_version.id
    ORDER BY CASE WHEN v_exam.shuffle_questions THEN random() ELSE eq.sort_order END
  ) q_item;

  IF NOT v_is_lecture_exam AND COALESCE(v_exam.duration_minutes, 0) > 0 THEN
    v_remaining_seconds := GREATEST(
      1,
      (v_exam.duration_minutes * 60) - FLOOR(EXTRACT(EPOCH FROM (now() - v_started_at)))::integer
    );
  ELSE
    v_remaining_seconds := 0;
  END IF;

  RETURN jsonb_build_object(
    'attempt_id', v_attempt_id,
    'exam_version_id', v_version.id,
    'started_at', COALESCE(v_started_at, now()),
    'duration_minutes', CASE WHEN v_is_lecture_exam THEN 0 ELSE COALESCE(v_exam.duration_minutes, 0) END,
    'remaining_seconds', v_remaining_seconds,
    'server_now', now(),
    'is_lecture_exam', v_is_lecture_exam,
    'contexts', v_contexts,
    'questions', v_questions
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.start_exam(uuid) TO authenticated;

-- 8. Update get_exam_review RPC to return audio metadata to reviewing student
CREATE OR REPLACE FUNCTION public.get_exam_review(p_attempt_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id   uuid := auth.uid();
  v_attempt     record;
  v_exam        record;
  v_questions   jsonb := '[]'::jsonb;
  v_answers     jsonb := '[]'::jsonb;
  v_is_teacher  boolean := false;
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

  SELECT (role = 'teacher') INTO v_is_teacher
  FROM public.users
  WHERE id = v_caller_id;

  IF v_attempt.student_id != v_caller_id AND NOT COALESCE(v_is_teacher, false) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: You are not authorized to view this attempt review';
  END IF;

  IF v_attempt.status NOT IN ('submitted', 'expired') THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only completed attempts can be reviewed';
  END IF;

  SELECT * INTO v_exam
  FROM public.exams
  WHERE id = v_attempt.exam_id;

  -- Build questions with audio metadata and options
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

  -- Build answers including text_answer
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

GRANT EXECUTE ON FUNCTION public.get_exam_review(uuid) TO authenticated;

-- 9. Update get_student_mistakes_questions RPC to return audio metadata
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
        'reflection_reason', sm.reflection_reason,
        'selected_option_text', (
          SELECT opt.option_text 
          FROM public.question_options opt 
          WHERE opt.id = sm.selected_option_id
          LIMIT 1
        ),
        'options', (
          SELECT COALESCE(
            jsonb_agg(
              jsonb_build_object(
                'id', opt.id,
                'option_text', opt.option_text,
                'sort_order', opt.sort_order
              ) ORDER BY opt.sort_order ASC
            ),
            '[]'::jsonb
          )
          FROM public.question_options opt
          WHERE opt.question_id = q.id
        )
      ) ORDER BY sm.is_resolved ASC, sm.last_failed_at DESC
    ),
    '[]'::jsonb
  )
  INTO v_questions
  FROM public.student_mistakes sm
  JOIN public.exam_questions q ON q.id = sm.question_id
  JOIN public.exam_versions ev ON ev.id = q.exam_version_id
  JOIN public.exams ex ON ex.id = ev.exam_id
  JOIN public.content c ON c.id = ex.content_id
  LEFT JOIN public.exams e ON e.id = sm.source_exam_id
  WHERE sm.student_id = p_student_id
    AND (NOT p_only_unresolved OR sm.is_resolved = FALSE)
    AND (p_exam_id IS NULL OR sm.source_exam_id = p_exam_id);

  RETURN v_questions;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_student_mistakes_questions(UUID, UUID, BOOLEAN) TO authenticated;
