-- ==============================================================================
-- Migration 0061: Unpublish Exam RPC, Publish RPC, Safe Question Options RLS & Data Repair
-- ==============================================================================

-- 1. Create unpublish_exam RPC: Atomically reverts an exam and its active version to draft
CREATE OR REPLACE FUNCTION public.unpublish_exam(
  p_exam_id uuid,
  p_version_id uuid DEFAULT NULL
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
  v_target_version_id uuid := p_version_id;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be authenticated';
  END IF;

  SELECT tenant_id INTO v_tenant_id
  FROM public.users
  WHERE id = v_caller_id AND role = 'teacher' AND status = 'active';

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only active teachers can unpublish exams';
  END IF;

  -- Verify exam exists and belongs to teacher's tenant
  SELECT content_id INTO v_content_id
  FROM public.exams
  WHERE id = p_exam_id AND tenant_id = v_tenant_id;

  IF v_content_id IS NULL THEN
    RAISE EXCEPTION 'NOT_FOUND: Exam not found in your academy';
  END IF;

  -- If version_id not provided, find the active published version or latest version
  IF v_target_version_id IS NULL THEN
    SELECT id INTO v_target_version_id
    FROM public.exam_versions
    WHERE exam_id = p_exam_id AND status = 'published'
    ORDER BY version_number DESC
    LIMIT 1;

    IF v_target_version_id IS NULL THEN
      SELECT id INTO v_target_version_id
      FROM public.exam_versions
      WHERE exam_id = p_exam_id
      ORDER BY version_number DESC
      LIMIT 1;
    END IF;
  END IF;

  -- Revert version status to draft
  IF v_target_version_id IS NOT NULL THEN
    UPDATE public.exam_versions
    SET status = 'draft'
    WHERE id = v_target_version_id;
  END IF;

  -- Revert content status to draft
  UPDATE public.content
  SET
    status = 'draft',
    updated_at = now()
  WHERE id = v_content_id;

  RETURN jsonb_build_object(
    'exam_id', p_exam_id,
    'version_id', v_target_version_id,
    'status', 'draft',
    'message', 'Exam reverted to draft successfully'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.unpublish_exam(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.unpublish_exam(uuid, uuid) TO authenticated;

-- 2. Create publish_exam_version RPC: Atomically publishes version and updates content status
CREATE OR REPLACE FUNCTION public.publish_exam_version(
  p_version_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_tenant_id uuid;
  v_exam_id uuid;
  v_content_id uuid;
  v_version_number int;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be authenticated';
  END IF;

  SELECT tenant_id INTO v_tenant_id
  FROM public.users
  WHERE id = v_caller_id AND role = 'teacher' AND status = 'active';

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only active teachers can publish exams';
  END IF;

  -- Verify version and tenant
  SELECT ev.exam_id, ev.version_number, e.content_id
  INTO v_exam_id, v_version_number, v_content_id
  FROM public.exam_versions ev
  JOIN public.exams e ON e.id = ev.exam_id
  WHERE ev.id = p_version_id AND e.tenant_id = v_tenant_id;

  IF v_exam_id IS NULL THEN
    RAISE EXCEPTION 'NOT_FOUND: Exam version not found in your academy';
  END IF;

  -- Update version status
  UPDATE public.exam_versions
  SET
    status = 'published',
    published_at = now()
  WHERE id = p_version_id;

  -- Update content status
  UPDATE public.content
  SET
    status = 'published',
    published_at = COALESCE(published_at, now()),
    updated_at = now()
  WHERE id = v_content_id;

  RETURN jsonb_build_object(
    'exam_id', v_exam_id,
    'version_id', p_version_id,
    'version_number', v_version_number,
    'status', 'published'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.publish_exam_version(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.publish_exam_version(uuid) TO authenticated;

-- 3. Add Safe RLS Read Policy for Students on question_options
-- Note: is_correct is never exposed to students in select projections
DROP POLICY IF EXISTS qo_student_read_published ON public.question_options;
CREATE POLICY qo_student_read_published ON public.question_options
  FOR SELECT TO authenticated
  USING (
    public.has_role('student')
    AND public.tenant_is_active()
    AND EXISTS (
      SELECT 1 FROM public.exam_questions q
      JOIN public.exam_versions v ON v.id = q.exam_version_id
      JOIN public.exams e ON e.id = v.exam_id
      JOIN public.content c ON c.id = e.content_id
      JOIN public.group_members gm ON gm.group_id = c.group_id
      WHERE q.id = question_options.question_id
        AND c.status = 'published'
        AND v.status = 'published'
        AND gm.student_id = auth.uid()
        AND gm.status = 'active'
    )
  );

-- 4. Repair existing exam questions in DB that have 0 options
-- Automatically populate options A, B, C, D (with A as default correct)
INSERT INTO public.question_options (
  question_id,
  option_text,
  sort_order,
  is_correct
)
SELECT
  q.id,
  opt.letter,
  opt.ord,
  (opt.ord = 1)
FROM public.exam_questions q
CROSS JOIN (
  VALUES ('A', 1), ('B', 2), ('C', 3), ('D', 4)
) AS opt(letter, ord)
WHERE NOT EXISTS (
  SELECT 1 FROM public.question_options qo WHERE qo.question_id = q.id
);

NOTIFY pgrst, 'reload schema';
