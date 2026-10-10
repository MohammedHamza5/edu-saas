-- ==============================================================================
-- Migration 0066: Fix Student PDF Access & Automatic Seamless Exam Versioning
-- ==============================================================================
-- 1. Fix RLS on public.files for students (support content_groups & file_id)
-- 2. Fix RLS on storage.objects ('group-content') for students
-- 3. Upgrade update_draft_exam_questions RPC to auto-version when attempts exist
-- 4. Enhance get_lesson_context to return questions_count
-- ==============================================================================

-- 1. Fix RLS on public.files for students
DROP POLICY IF EXISTS files_student_read_authorized ON public.files;
CREATE POLICY files_student_read_authorized ON public.files FOR SELECT TO authenticated
USING (
  public.has_role('student')
  AND public.tenant_is_active()
  AND tenant_id = public.my_tenant_id()
  AND (
    -- Direct link via files.content_id
    EXISTS (
      SELECT 1 FROM public.content c
      JOIN public.group_members gm ON (
        gm.group_id = c.group_id
        OR EXISTS (
          SELECT 1 FROM public.content_groups cg
          WHERE cg.content_id = c.id AND cg.group_id = gm.group_id
        )
      )
      WHERE c.id = files.content_id
        AND c.status = 'published'
        AND gm.student_id = auth.uid()
        AND gm.status = 'active'
        AND (
          gm.joined_at <= COALESCE(c.published_at, c.created_at)
          OR (SELECT g.previous_content_access FROM public.groups g WHERE g.id = gm.group_id) = 'allow'
        )
    )
    -- OR junction link via content_groups.file_id
    OR EXISTS (
      SELECT 1 FROM public.content_groups cg
      JOIN public.group_members gm ON gm.group_id = cg.group_id
      JOIN public.content c ON c.id = cg.content_id
      WHERE cg.file_id = files.id
        AND cg.is_published = true
        AND c.status = 'published'
        AND gm.student_id = auth.uid()
        AND gm.status = 'active'
        AND (
          gm.joined_at <= COALESCE(c.published_at, c.created_at)
          OR (SELECT g.previous_content_access FROM public.groups g WHERE g.id = gm.group_id) = 'allow'
        )
    )
  )
);

-- 2. Fix RLS on storage.objects for 'group-content' bucket
DROP POLICY IF EXISTS "Authorized read group-content" ON storage.objects;
CREATE POLICY "Authorized read group-content"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'group-content'
  AND public.tenant_is_active()
  AND (
    (storage.foldername(name))[1] = 'test'
    OR (
      public.has_role('teacher')
      AND (
        (
          (storage.foldername(name))[1] = 'groups'
          AND public.group_belongs_to_my_tenant(((storage.foldername(name))[2])::uuid)
        )
        OR (storage.foldername(name))[1] IN ('bank', 'bank_handouts', 'materials', 'content')
      )
    )
    OR (
      public.has_role('student')
      AND EXISTS (
        SELECT 1 FROM public.files f
        JOIN public.content c ON (
          c.id = f.content_id
          OR EXISTS (SELECT 1 FROM public.content_groups cg WHERE cg.file_id = f.id AND cg.content_id = c.id)
        )
        JOIN public.group_members gm ON (
          gm.group_id = c.group_id
          OR EXISTS (
            SELECT 1 FROM public.content_groups cg
            WHERE cg.content_id = c.id AND cg.group_id = gm.group_id
          )
        )
        WHERE f.storage_path = storage.objects.name
          AND c.status = 'published'
          AND gm.student_id = auth.uid()
          AND gm.status = 'active'
          AND (
            gm.joined_at <= COALESCE(c.published_at, c.created_at)
            OR (SELECT g.previous_content_access FROM public.groups g WHERE g.id = gm.group_id) = 'allow'
          )
      )
    )
  )
);

-- 3. Upgrade update_draft_exam_questions RPC: Auto-versioning seamlessly when attempts exist
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
  p_questions jsonb DEFAULT '[]'::jsonb
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

  -- 2. Update content
  UPDATE public.content
  SET
    title = trim(p_title),
    status = CASE WHEN p_is_published THEN 'published' ELSE 'draft' END,
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
    updated_at = now()
  WHERE id = p_exam_id;

  -- 4. Check student attempts count for seamless versioning
  SELECT count(*) INTO v_attempts_count
  FROM public.exam_attempts
  WHERE exam_id = p_exam_id;

  IF v_attempts_count > 0 THEN
    -- Student attempts exist on prior version!
    -- Freeze prior version as immutable snapshot, create next version (V2, V3...)
    SELECT COALESCE(max(version_number), 1) INTO v_max_version_number
    FROM public.exam_versions
    WHERE exam_id = p_exam_id;

    v_version_number := v_max_version_number + 1;

    INSERT INTO public.exam_versions (
      exam_id, version_number, status, created_at, published_at
    )
    VALUES (
      p_exam_id,
      v_version_number,
      CASE WHEN p_is_published THEN 'published' ELSE 'draft' END,
      now(),
      CASE WHEN p_is_published THEN now() ELSE NULL END
    )
    RETURNING id INTO v_version_id;

  ELSE
    -- No attempts yet: safely update current version in place
    SELECT id, status, version_number INTO v_version_id, v_version_status, v_version_number
    FROM public.exam_versions
    WHERE exam_id = p_exam_id
    ORDER BY version_number DESC
    LIMIT 1;

    IF v_version_id IS NULL THEN
      v_version_number := 1;
      INSERT INTO public.exam_versions (
        exam_id, version_number, status, created_at, published_at
      )
      VALUES (
        p_exam_id, 1,
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

      -- Delete previous questions and options in-place
      DELETE FROM public.question_options
      WHERE question_id IN (
        SELECT id FROM public.exam_questions WHERE exam_version_id = v_version_id
      );

      DELETE FROM public.exam_questions
      WHERE exam_version_id = v_version_id;
    END IF;
  END IF;

  -- 5. Insert questions & options
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
      COALESCE(q_elem->>'question_text', ' '),
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
          COALESCE(opt_elem->>'option_text', ''),
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

-- Alias for backwards compatibility
CREATE OR REPLACE FUNCTION public.update_draft_exam(
  p_exam_id uuid,
  p_title text,
  p_duration_minutes integer DEFAULT 60,
  p_max_score integer DEFAULT 100,
  p_passing_score integer DEFAULT NULL,
  p_shuffle_questions boolean DEFAULT false,
  p_show_result boolean DEFAULT true,
  p_allow_retake boolean DEFAULT false,
  p_is_published boolean DEFAULT false,
  p_questions jsonb DEFAULT '[]'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN public.update_draft_exam_questions(
    p_exam_id, p_title, p_duration_minutes, p_max_score,
    p_passing_score, p_shuffle_questions, p_show_result,
    p_allow_retake, p_is_published, p_questions
  );
END;
$$;

-- 4. Update get_lesson_context to return questions_count & actual passing_score
CREATE OR REPLACE FUNCTION public.get_lesson_context(
  p_content_id uuid,
  p_group_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_cg record;
  v_file record;
  v_exam record;
  v_group record;
  v_latest_version record;
  v_questions_count int := 0;
  v_is_manually_unlocked boolean := false;
  v_manual_reason text;
  v_attached_exams jsonb := '[]'::jsonb;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be authenticated';
  END IF;

  SELECT * INTO v_cg FROM public.content_groups
  WHERE content_id = p_content_id AND group_id = p_group_id;

  SELECT * INTO v_group FROM public.groups WHERE id = p_group_id;

  IF v_cg.file_id IS NOT NULL THEN
    SELECT * INTO v_file FROM public.files WHERE id = v_cg.file_id;
  END IF;

  IF v_cg.associated_exam_id IS NOT NULL THEN
    SELECT * INTO v_exam FROM public.exams WHERE id = v_cg.associated_exam_id;
    IF v_exam.id IS NOT NULL THEN
      -- Get latest published version questions count
      SELECT * INTO v_latest_version FROM public.exam_versions
      WHERE exam_id = v_exam.id AND status = 'published'
      ORDER BY version_number DESC LIMIT 1;

      IF v_latest_version.id IS NOT NULL THEN
        SELECT count(*) INTO v_questions_count
        FROM public.exam_questions
        WHERE exam_version_id = v_latest_version.id;
      END IF;
    END IF;
  END IF;

  -- Check manual unlock for caller student
  SELECT EXISTS(
    SELECT 1 FROM public.manual_lesson_unlocks
    WHERE content_id = p_content_id AND group_id = p_group_id AND student_id = v_caller_id
  ), reason INTO v_is_manually_unlocked, v_manual_reason
  FROM public.manual_lesson_unlocks
  WHERE content_id = p_content_id AND group_id = p_group_id AND student_id = v_caller_id
  LIMIT 1;

  -- Build attached_exams jsonb array if associated_exam exists
  IF v_exam.id IS NOT NULL THEN
    v_attached_exams := jsonb_build_array(
      jsonb_build_object(
        'exam_id', v_exam.id,
        'exam_title', COALESCE(v_exam.title, (SELECT title FROM public.content WHERE id = v_exam.content_id), ''),
        'sort_order', 0,
        'is_required', true,
        'passing_score', COALESCE(v_cg.passing_score_override, v_exam.passing_score, 60),
        'questions_count', v_questions_count
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'content_group_id', v_cg.id,
    'content_id', p_content_id,
    'group_id', p_group_id,
    'sort_order', v_cg.sort_order,
    'pdf_file_id', v_cg.file_id,
    'pdf_file_name', v_file.file_name,
    'pdf_storage_path', v_file.storage_path,
    'lesson_exam_id', v_cg.associated_exam_id,
    'lesson_exam_title', CASE WHEN v_exam.id IS NOT NULL THEN (SELECT title FROM public.content WHERE id = v_exam.content_id) ELSE null END,
    'lesson_exam_passing_score', COALESCE(v_cg.passing_score_override, v_exam.passing_score, v_group.default_passing_score, 60),
    'lesson_exam_questions_count', v_questions_count,
    'attached_exams', v_attached_exams,
    'passing_score_override', v_cg.passing_score_override,
    'group_default_passing_score', v_group.default_passing_score,
    'enforce_sequential', COALESCE(v_group.enforce_sequential_learning, true),
    'is_manually_unlocked', COALESCE(v_is_manually_unlocked, false),
    'manual_unlock_reason', v_manual_reason
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_draft_exam_questions TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_draft_exam TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_lesson_context TO authenticated;
NOTIFY pgrst, 'reload schema';
