-- 0064_optimize_exam_draft_and_foreign_keys.sql
-- 1. Helper security definer functions to prevent recursive RLS explosion
CREATE OR REPLACE FUNCTION public.get_exam_version_tenant_id(p_version_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT e.tenant_id
  FROM public.exam_versions v
  JOIN public.exams e ON e.id = v.exam_id
  WHERE v.id = p_version_id
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.get_question_tenant_id(p_question_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT e.tenant_id
  FROM public.exam_questions q
  JOIN public.exam_versions v ON v.id = q.exam_version_id
  JOIN public.exams e ON e.id = v.exam_id
  WHERE q.id = p_question_id
  LIMIT 1;
$$;

-- 2. Optimize eq_teacher_all and qo_teacher_all
DROP POLICY IF EXISTS eq_teacher_all ON public.exam_questions;
CREATE POLICY eq_teacher_all ON public.exam_questions
FOR ALL TO authenticated
USING (
  has_role('teacher') 
  AND tenant_is_active() 
  AND get_exam_version_tenant_id(exam_version_id) = my_tenant_id()
)
WITH CHECK (
  has_role('teacher') 
  AND tenant_is_active() 
  AND get_exam_version_tenant_id(exam_version_id) = my_tenant_id()
);

DROP POLICY IF EXISTS qo_teacher_all ON public.question_options;
CREATE POLICY qo_teacher_all ON public.question_options
FOR ALL TO authenticated
USING (
  has_role('teacher') 
  AND tenant_is_active() 
  AND get_question_tenant_id(question_id) = my_tenant_id()
)
WITH CHECK (
  has_role('teacher') 
  AND tenant_is_active() 
  AND get_question_tenant_id(question_id) = my_tenant_id()
);

-- 3. Foreign key indexes to make deletes instant
CREATE INDEX IF NOT EXISTS idx_exam_answers_selected_option ON public.exam_answers(selected_option_id);
CREATE INDEX IF NOT EXISTS idx_exam_answers_question ON public.exam_answers(question_id);
CREATE INDEX IF NOT EXISTS idx_exam_answers_attempt ON public.exam_answers(attempt_id);
CREATE INDEX IF NOT EXISTS idx_student_mistakes_selected_option ON public.student_mistakes(selected_option_id);

-- 4. Deploy update_draft_exam_questions RPC
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
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only active teachers can edit draft exams';
  END IF;

  -- 1. Find exam and verify tenant
  SELECT content_id INTO v_content_id
  FROM public.exams
  WHERE id = p_exam_id AND tenant_id = v_tenant_id;

  IF v_content_id IS NULL THEN
    RAISE EXCEPTION 'NOT_FOUND: Exam does not exist or does not belong to your academy';
  END IF;

  -- 2. Check student attempts count (Immutability guarantee)
  SELECT count(*) INTO v_attempts_count
  FROM public.exam_attempts
  WHERE exam_id = p_exam_id;

  IF v_attempts_count > 0 THEN
    RAISE EXCEPTION 'EXAM_HAS_ATTEMPTS: Cannot edit questions of an exam that has student attempts. Please create a new version (V2).';
  END IF;

  -- 3. Update content
  UPDATE public.content
  SET
    title = trim(p_title),
    status = CASE WHEN p_is_published THEN 'published' ELSE 'draft' END,
    published_at = CASE WHEN p_is_published AND published_at IS NULL THEN now() ELSE published_at END,
    updated_at = now()
  WHERE id = v_content_id;

  -- 4. Update exam settings
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

  -- 5. Find or create draft version
  SELECT id, status, version_number INTO v_version_id, v_version_status, v_version_number
  FROM public.exam_versions
  WHERE exam_id = p_exam_id
  ORDER BY version_number DESC
  LIMIT 1;

  IF v_version_id IS NULL THEN
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
  END IF;

  -- 6. Delete previous questions (cascades to question_options)
  DELETE FROM public.question_options
  WHERE question_id IN (
    SELECT id FROM public.exam_questions WHERE exam_version_id = v_version_id
  );

  DELETE FROM public.exam_questions
  WHERE exam_version_id = v_version_id;

  -- 7. Insert updated questions and options
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
    'questions_count', v_idx,
    'is_published', p_is_published
  );
END;
$$;

-- 5. Alias update_draft_exam that points to update_draft_exam_questions
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
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.update_draft_exam_questions(
    p_exam_id,
    p_title,
    p_duration_minutes,
    p_max_score,
    p_passing_score,
    p_shuffle_questions,
    p_show_result,
    p_allow_retake,
    p_is_published,
    p_questions
  );
$$;

GRANT EXECUTE ON FUNCTION public.update_draft_exam_questions TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_draft_exam TO authenticated;
