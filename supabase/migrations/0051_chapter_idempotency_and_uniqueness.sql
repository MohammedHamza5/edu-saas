-- Migration 0051: Chapter Idempotency and Uniqueness
-- ==============================================================================
-- Ensures that creating chapters is strictly idempotent and prevents
-- duplicate chapters with the same name from ever being created in the same group.
-- ==============================================================================

-- 1. Create unique index on (group_id, LOWER(TRIM(title)))
CREATE UNIQUE INDEX IF NOT EXISTS idx_chapters_group_title_unique 
ON public.chapters (group_id, LOWER(TRIM(title)));

-- 2. Update create_chapter function with atomic idempotency
CREATE OR REPLACE FUNCTION public.create_chapter(
  p_group_id uuid,
  p_title text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_tenant_id uuid;
  v_next_order int;
  v_new_chapter_id uuid;
  v_existing_id uuid;
  v_existing_order int;
  v_clean_title text := TRIM(p_title);
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT tenant_id INTO v_tenant_id
  FROM public.users
  WHERE id = v_caller_id AND role = 'teacher' AND status = 'active';

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  IF v_clean_title IS NULL OR v_clean_title = '' THEN
    RAISE EXCEPTION 'TITLE_REQUIRED';
  END IF;

  -- 1. Check if chapter with identical title already exists in this group
  SELECT id, sort_order INTO v_existing_id, v_existing_order
  FROM public.chapters
  WHERE group_id = p_group_id 
    AND tenant_id = v_tenant_id 
    AND LOWER(TRIM(title)) = LOWER(v_clean_title)
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'id', v_existing_id,
      'title', v_clean_title,
      'sort_order', v_existing_order,
      'already_existed', true
    );
  END IF;

  -- 2. Determine next sort_order
  SELECT COALESCE(MAX(sort_order), -1) + 1 INTO v_next_order
  FROM public.chapters
  WHERE group_id = p_group_id;

  -- 3. Atomic insert with ON CONFLICT safety
  INSERT INTO public.chapters (
    tenant_id,
    group_id,
    title,
    sort_order
  ) VALUES (
    v_tenant_id,
    p_group_id,
    v_clean_title,
    v_next_order
  )
  ON CONFLICT (group_id, LOWER(TRIM(title))) DO UPDATE
    SET updated_at = NOW()
  RETURNING id, sort_order INTO v_new_chapter_id, v_next_order;

  RETURN jsonb_build_object(
    'id', v_new_chapter_id,
    'title', v_clean_title,
    'sort_order', v_next_order,
    'already_existed', false
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_chapter(uuid, text) TO authenticated;
