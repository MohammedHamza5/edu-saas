-- ============================================================================
-- 0057_create_exam_version_rpc.sql
-- Atomic, idempotent RPC to clone an existing exam into a new draft version
-- ============================================================================

CREATE OR REPLACE FUNCTION public.create_exam_version(p_exam_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid;
  v_exam_id uuid;
  v_exam_tenant_id uuid;
  v_existing_draft_id uuid;
  v_existing_version_number integer;
  v_existing_status text;
  v_existing_created_at timestamptz;
  v_existing_published_at timestamptz;
  v_last_version_id uuid;
  v_last_version_number integer;
  v_next_version integer;
  v_new_version_id uuid;
  v_new_created_at timestamptz;
  v_new_ctx_id uuid;
  v_new_q_id uuid;
  v_mapped_ctx_id uuid;
  r_ctx RECORD;
  r_q RECORD;
BEGIN
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: Authentication required';
  END IF;

  -- 1. Verify exam existence & teacher authorization
  SELECT e.id, e.tenant_id INTO v_exam_id, v_exam_tenant_id
  FROM public.exams e
  WHERE e.id = p_exam_id;

  IF v_exam_id IS NULL THEN
    RAISE EXCEPTION 'NOT_FOUND: Exam does not exist';
  END IF;

  IF NOT (
    public.has_role('teacher') AND 
    public.tenant_is_active() AND 
    public.my_tenant_id() = v_exam_tenant_id
  ) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: You are not authorized to manage versions for this exam';
  END IF;

  -- 2. Check if an unpublished draft version already exists
  SELECT id, version_number, status, created_at, published_at
  INTO v_existing_draft_id, v_existing_version_number, v_existing_status, v_existing_created_at, v_existing_published_at
  FROM public.exam_versions
  WHERE exam_id = p_exam_id AND status = 'draft'
  ORDER BY version_number DESC
  LIMIT 1;

  IF v_existing_draft_id IS NOT NULL THEN
    -- Idempotent return of the current draft version
    RETURN jsonb_build_object(
      'id', v_existing_draft_id,
      'exam_id', p_exam_id,
      'version_number', v_existing_version_number,
      'status', v_existing_status,
      'created_at', v_existing_created_at,
      'published_at', v_existing_published_at
    );
  END IF;

  -- 3. Find the most recent published version to clone questions from
  SELECT id, version_number
  INTO v_last_version_id, v_last_version_number
  FROM public.exam_versions
  WHERE exam_id = p_exam_id
  ORDER BY version_number DESC
  LIMIT 1;

  v_next_version := COALESCE(v_last_version_number, 0) + 1;

  -- 4. Create new draft version
  INSERT INTO public.exam_versions (exam_id, version_number, status, created_at)
  VALUES (p_exam_id, v_next_version, 'draft', now())
  RETURNING id, created_at INTO v_new_version_id, v_new_created_at;

  -- 5. Clone contexts and questions if last version exists
  IF v_last_version_id IS NOT NULL THEN
    -- Temporary mapping table for contexts: old_ctx_id -> new_ctx_id
    CREATE TEMP TABLE IF NOT EXISTS _ctx_map (
      old_id uuid PRIMARY KEY,
      new_id uuid NOT NULL
    ) ON COMMIT DROP;
    DELETE FROM _ctx_map;

    FOR r_ctx IN
      SELECT id, title, context_text, image_url, image_meta, sort_order
      FROM public.exam_contexts
      WHERE exam_version_id = v_last_version_id
      ORDER BY sort_order
    LOOP
      INSERT INTO public.exam_contexts (
        exam_version_id, tenant_id, title, context_text, image_url, image_meta, sort_order, created_at
      )
      VALUES (
        v_new_version_id, v_exam_tenant_id, r_ctx.title, r_ctx.context_text, r_ctx.image_url, r_ctx.image_meta, r_ctx.sort_order, now()
      )
      RETURNING id INTO v_new_ctx_id;

      INSERT INTO _ctx_map (old_id, new_id) VALUES (r_ctx.id, v_new_ctx_id);
    END LOOP;

    -- Clone questions and options
    FOR r_q IN
      SELECT q.id, q.question_text, q.question_type, q.points, q.sort_order, q.image_url, q.image_meta, q.context_id
      FROM public.exam_questions q
      WHERE q.exam_version_id = v_last_version_id
      ORDER BY q.sort_order
    LOOP
      v_mapped_ctx_id := NULL;
      IF r_q.context_id IS NOT NULL THEN
        SELECT new_id INTO v_mapped_ctx_id FROM _ctx_map WHERE old_id = r_q.context_id;
      END IF;

      INSERT INTO public.exam_questions (
        exam_version_id, question_text, question_type, points, sort_order, image_url, image_meta, context_id
      )
      VALUES (
        v_new_version_id, r_q.question_text, r_q.question_type, r_q.points, r_q.sort_order, r_q.image_url, r_q.image_meta, v_mapped_ctx_id
      )
      RETURNING id INTO v_new_q_id;

      -- Clone options
      INSERT INTO public.question_options (
        question_id, option_text, sort_order, is_correct, image_url, image_meta
      )
      SELECT 
        v_new_q_id, option_text, sort_order, is_correct, image_url, image_meta
      FROM public.question_options
      WHERE question_id = r_q.id
      ORDER BY sort_order;
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'id', v_new_version_id,
    'exam_id', p_exam_id,
    'version_number', v_next_version,
    'status', 'draft',
    'created_at', v_new_created_at,
    'published_at', NULL
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_exam_version(uuid) TO authenticated;
