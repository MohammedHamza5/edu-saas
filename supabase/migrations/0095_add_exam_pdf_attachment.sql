-- ==============================================================================
-- Migration: 0095_add_exam_pdf_attachment.sql
-- Description:
--   1. Adds pdf_file_id column to public.exams (supports material_library and files).
--   2. Updates public.create_exam_with_questions to accept p_pdf_file_id.
--   3. Updates public.update_draft_exam_questions to accept p_pdf_file_id and p_clear_pdf.
--   4. Updates public.get_exam_details to resolve PDF attachment from material_library or files.
--   5. Updates public.can_access_file to authorize student/parent access to exam attached PDFs.
--   6. Reloads PostgREST schema cache.
-- ==============================================================================

-- 1. Add pdf_file_id column to public.exams
ALTER TABLE public.exams 
ADD COLUMN IF NOT EXISTS pdf_file_id uuid;

CREATE INDEX IF NOT EXISTS idx_exams_pdf_file_id ON public.exams(pdf_file_id);

-- 2. Update create_exam_with_questions RPC
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
  p_pdf_file_id uuid DEFAULT NULL
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

  -- Verify pdf_file_id if provided (check material_library first, then files)
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

  -- 2. Create exams record
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
    pdf_file_id
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
    p_pdf_file_id
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

  -- 4. Atomically insert all questions and options
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
      context_id
    )
    VALUES (
      v_version_id,
      COALESCE(trim(q_elem->>'question_text'), ''),
      COALESCE(q_elem->>'question_type', 'multiple_choice'),
      COALESCE((q_elem->>'points')::integer, 1),
      COALESCE((q_elem->>'sort_order')::integer, v_idx),
      q_elem->>'image_url',
      CASE WHEN q_elem ? 'image_meta' AND q_elem->'image_meta' IS NOT NULL AND jsonb_typeof(q_elem->'image_meta') = 'object' THEN q_elem->'image_meta' ELSE NULL END,
      CASE WHEN q_elem ? 'context_id' AND (q_elem->>'context_id') IS NOT NULL AND (q_elem->>'context_id') != '' THEN (q_elem->>'context_id')::uuid ELSE NULL END
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
    'success', true
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_exam_with_questions(
  text, uuid, integer, integer, integer, boolean, boolean, boolean, boolean, timestamptz, timestamptz, jsonb, uuid
) TO authenticated;

-- 3. Update update_draft_exam_questions RPC to support pdf_file_id
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

  -- 2. Update content
  UPDATE public.content
  SET
    title = trim(p_title),
    status = CASE WHEN p_is_published THEN 'published' ELSE 'draft' END,
    published_at = CASE WHEN p_is_published AND published_at IS NULL THEN now() ELSE published_at END,
    updated_at = now()
  WHERE id = v_content_id;

  -- 3. Update exam settings and PDF
  UPDATE public.exams
  SET
    duration_minutes = p_duration_minutes,
    max_score = p_max_score,
    passing_score = p_passing_score,
    shuffle_questions = p_shuffle_questions,
    show_result = p_show_result,
    allow_retake = p_allow_retake,
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
    -- Archive previous versions and increment version_number
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
    -- Safe in-place update of draft version
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

      -- Delete previous questions for this version
      DELETE FROM public.exam_questions WHERE exam_version_id = v_version_id;
    END IF;
  END IF;

  -- 5. Insert questions
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
      context_id
    )
    VALUES (
      v_version_id,
      COALESCE(trim(q_elem->>'question_text'), ''),
      COALESCE(q_elem->>'question_type', 'multiple_choice'),
      COALESCE((q_elem->>'points')::integer, 1),
      COALESCE((q_elem->>'sort_order')::integer, v_idx),
      q_elem->>'image_url',
      CASE WHEN q_elem ? 'image_meta' AND q_elem->'image_meta' IS NOT NULL AND jsonb_typeof(q_elem->'image_meta') = 'object' THEN q_elem->'image_meta' ELSE NULL END,
      CASE WHEN q_elem ? 'context_id' AND (q_elem->>'context_id') IS NOT NULL AND (q_elem->>'context_id') != '' THEN (q_elem->>'context_id')::uuid ELSE NULL END
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

-- 4. Update get_exam_details RPC to return PDF attachment details
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
  v_pdf_file_id    uuid := null;
  v_pdf_file_name  text := null;
  v_pdf_file_size  bigint := null;
  v_pdf_storage_path text := null;
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
    SELECT id, file_name, file_size, storage_path
    INTO v_pdf_file_id, v_pdf_file_name, v_pdf_file_size, v_pdf_storage_path
    FROM public.material_library WHERE id = v_exam.pdf_file_id;

    IF v_pdf_file_id IS NULL THEN
      SELECT id, file_name, file_size, storage_path
      INTO v_pdf_file_id, v_pdf_file_name, v_pdf_file_size, v_pdf_storage_path
      FROM public.files WHERE id = v_exam.pdf_file_id;
    END IF;
  END IF;

  IF v_pdf_file_id IS NULL AND v_content.id IS NOT NULL THEN
    SELECT id, file_name, file_size, storage_path
    INTO v_pdf_file_id, v_pdf_file_name, v_pdf_file_size, v_pdf_storage_path
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
    'created_at', v_exam.created_at,
    'version_id', v_version.id,
    'version_number', v_version.version_number,
    'version_status', v_version.status,
    'contexts', v_contexts,
    'questions', v_questions,
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

-- 5. Update can_access_file to authorize student/parent access to exam PDFs
CREATE OR REPLACE FUNCTION public.can_access_file(p_storage_path text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role text;
  v_tenant_id uuid;
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN false;
  END IF;

  IF NOT public.tenant_is_active() THEN
    RETURN false;
  END IF;

  SELECT role, tenant_id INTO v_role, v_tenant_id
  FROM public.users
  WHERE id = v_user_id;

  IF v_role IS NULL THEN
    RETURN false;
  END IF;

  -- 1) Teacher: can access if file belongs to teacher's tenant (in files table or material_library)
  IF v_role = 'teacher' THEN
    RETURN EXISTS (
      SELECT 1 FROM public.files f
      WHERE f.storage_path = p_storage_path
        AND f.tenant_id = v_tenant_id
    ) OR EXISTS (
      SELECT 1 FROM public.material_library ml
      WHERE ml.storage_path = p_storage_path
        AND ml.tenant_id = v_tenant_id
    );
  END IF;

  -- 2) Student: can access if content is published and student is in the assigned group
  IF v_role = 'student' THEN
    RETURN EXISTS (
      SELECT 1 
      FROM public.files f
      JOIN public.content c ON c.id = f.content_id
      JOIN public.group_members gm ON (
        gm.student_id = v_user_id 
        AND gm.status = 'active'
        AND (
          (c.group_id = gm.group_id AND c.status = 'published')
          OR
          EXISTS (
            SELECT 1 FROM public.content_groups cg
            WHERE cg.content_id = c.id
              AND cg.group_id = gm.group_id
              AND cg.is_published = true
          )
        )
      )
      JOIN public.groups g ON g.id = gm.group_id
      WHERE f.storage_path = p_storage_path
        AND (
          gm.joined_at <= COALESCE(c.published_at, c.created_at)
          OR g.previous_content_access = 'allow'
        )
    ) OR EXISTS (
      -- Student access for Exam attached PDF (from material_library or files)
      SELECT 1
      FROM public.exams e
      JOIN public.content c ON c.id = e.content_id
      JOIN public.group_members gm ON (
        gm.student_id = v_user_id
        AND gm.status = 'active'
        AND (
          (c.group_id = gm.group_id)
          OR
          EXISTS (
            SELECT 1 FROM public.content_groups cg
            WHERE cg.content_id = c.id AND cg.group_id = gm.group_id AND cg.is_published = true
          )
          OR
          EXISTS (
            SELECT 1 FROM public.lesson_exams le
            WHERE le.exam_id = e.id AND le.group_id = gm.group_id
          )
          OR (
            c.group_id IS NULL
            AND EXISTS (
              SELECT 1 FROM public.groups g2
              WHERE g2.id = gm.group_id AND g2.tenant_id = v_tenant_id
            )
          )
        )
      )
      WHERE c.status = 'published'
        AND (
          EXISTS (
            SELECT 1 FROM public.material_library ml
            WHERE ml.id = e.pdf_file_id AND ml.storage_path = p_storage_path
          )
          OR EXISTS (
            SELECT 1 FROM public.files f2
            WHERE f2.id = e.pdf_file_id AND f2.storage_path = p_storage_path
          )
        )
    );
  END IF;

  -- 3) Parent: can access if any active child can access
  IF v_role = 'parent' THEN
    RETURN EXISTS (
      SELECT 1
      FROM public.parent_students ps
      JOIN public.group_members gm ON (
        gm.student_id = ps.student_id 
        AND gm.status = 'active'
      )
      JOIN public.files f ON f.storage_path = p_storage_path
      JOIN public.content c ON c.id = f.content_id
      JOIN public.groups g ON g.id = gm.group_id
      WHERE ps.parent_id = v_user_id
        AND (
          (c.group_id = gm.group_id AND c.status = 'published')
          OR
          EXISTS (
            SELECT 1 FROM public.content_groups cg
            WHERE cg.content_id = c.id
              AND cg.group_id = gm.group_id
              AND cg.is_published = true
          )
        )
        AND (
          gm.joined_at <= COALESCE(c.published_at, c.created_at)
          OR g.previous_content_access = 'allow'
        )
    ) OR EXISTS (
      -- Parent access for Exam attached PDF
      SELECT 1
      FROM public.parent_students ps
      JOIN public.group_members gm ON (
        gm.student_id = ps.student_id
        AND gm.status = 'active'
      )
      JOIN public.exams e ON true
      JOIN public.content c ON c.id = e.content_id
      WHERE ps.parent_id = v_user_id
        AND c.status = 'published'
        AND (
          (c.group_id = gm.group_id)
          OR
          EXISTS (
            SELECT 1 FROM public.content_groups cg
            WHERE cg.content_id = c.id AND cg.group_id = gm.group_id AND cg.is_published = true
          )
          OR
          EXISTS (
            SELECT 1 FROM public.lesson_exams le
            WHERE le.exam_id = e.id AND le.group_id = gm.group_id
          )
          OR (
            c.group_id IS NULL
            AND EXISTS (
              SELECT 1 FROM public.groups g2
              WHERE g2.id = gm.group_id AND g2.tenant_id = v_tenant_id
            )
          )
        )
        AND (
          EXISTS (
            SELECT 1 FROM public.material_library ml
            WHERE ml.id = e.pdf_file_id AND ml.storage_path = p_storage_path
          )
          OR EXISTS (
            SELECT 1 FROM public.files f2
            WHERE f2.id = e.pdf_file_id AND f2.storage_path = p_storage_path
          )
        )
    );
  END IF;

  RETURN false;
END;
$$;

REVOKE ALL ON FUNCTION public.can_access_file(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_access_file(text) TO authenticated;

-- 6. Reload schema cache for PostgREST
NOTIFY pgrst, 'reload schema';
