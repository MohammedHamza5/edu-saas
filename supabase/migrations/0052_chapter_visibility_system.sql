-- Migration 0052: Chapter Visibility System
-- ==============================================================================
-- 1. Add is_published column to public.chapters (default true)
-- 2. Update RLS policies so students & parents can only read published chapters
-- 3. Update create_chapter RPC to support p_is_published parameter
-- 4. Provide toggle_chapter_visibility RPC for atomic status updates
-- ==============================================================================

-- 1. Add is_published column and index
ALTER TABLE public.chapters
  ADD COLUMN IF NOT EXISTS is_published boolean NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_chapters_group_published
  ON public.chapters(group_id, is_published);

-- 2. Update Student and Parent RLS policies
DROP POLICY IF EXISTS chapters_student_read ON public.chapters;
CREATE POLICY chapters_student_read ON public.chapters
  FOR SELECT TO authenticated
  USING (
    public.has_role('student')
    AND public.tenant_is_active()
    AND tenant_id = public.my_tenant_id()
    AND is_published = true
    AND EXISTS (
      SELECT 1 FROM public.group_members gm
      WHERE gm.group_id = chapters.group_id
        AND gm.student_id = auth.uid()
        AND gm.status = 'active'
    )
  );

DROP POLICY IF EXISTS chapters_parent_read ON public.chapters;
CREATE POLICY chapters_parent_read ON public.chapters
  FOR SELECT TO authenticated
  USING (
    public.has_role('parent')
    AND public.tenant_is_active()
    AND tenant_id = public.my_tenant_id()
    AND is_published = true
    AND EXISTS (
      SELECT 1 FROM public.parent_students ps
      JOIN public.group_members gm ON gm.student_id = ps.student_id
      WHERE ps.parent_id = auth.uid()
        AND gm.group_id = chapters.group_id
        AND gm.status = 'active'
    )
  );

-- 3. Update create_chapter function to accept optional p_is_published
CREATE OR REPLACE FUNCTION public.create_chapter(
  p_group_id uuid,
  p_title text,
  p_is_published boolean DEFAULT true
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
  v_existing_published boolean;
  v_clean_title text := TRIM(p_title);
  v_publish boolean := COALESCE(p_is_published, true);
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
  SELECT id, sort_order, is_published INTO v_existing_id, v_existing_order, v_existing_published
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
      'is_published', v_existing_published,
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
    sort_order,
    is_published
  ) VALUES (
    v_tenant_id,
    p_group_id,
    v_clean_title,
    v_next_order,
    v_publish
  )
  ON CONFLICT (group_id, LOWER(TRIM(title))) DO UPDATE
    SET updated_at = NOW()
  RETURNING id, sort_order, is_published INTO v_new_chapter_id, v_next_order, v_publish;

  RETURN jsonb_build_object(
    'id', v_new_chapter_id,
    'title', v_clean_title,
    'sort_order', v_next_order,
    'is_published', v_publish,
    'already_existed', false
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_chapter(uuid, text, boolean) TO authenticated;

-- 4. toggle_chapter_visibility RPC
CREATE OR REPLACE FUNCTION public.toggle_chapter_visibility(
  p_chapter_id uuid,
  p_is_published boolean
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_tenant_id uuid;
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

  UPDATE public.chapters
  SET is_published = p_is_published,
      updated_at = NOW()
  WHERE id = p_chapter_id AND tenant_id = v_tenant_id;

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.toggle_chapter_visibility(uuid, boolean) TO authenticated;
