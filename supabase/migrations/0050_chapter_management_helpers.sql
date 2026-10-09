-- Migration 0050: Chapter Management Helpers
-- ==============================================================================
-- Provides atomic helper RPCs for full chapter and lecture flexibility
-- in the Teacher Course Builder:
-- 1. set_lesson_chapter: Assign or move a lesson to a specific chapter (or unassign).
-- 2. reorder_chapter_lessons: Reorder lessons within a chapter or unassigned bucket.
-- 3. reorder_course_chapters: Reorder chapters within a group.
-- 4. remove_lesson_from_group: Detach a lesson from a group/chapter without deleting video asset.
-- ==============================================================================

-- 1. set_lesson_chapter
CREATE OR REPLACE FUNCTION public.set_lesson_chapter(
  p_content_id uuid,
  p_group_id uuid,
  p_chapter_id uuid DEFAULT NULL
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

  -- Verify chapter belongs to the same group if chapter_id is provided
  IF p_chapter_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.chapters
      WHERE id = p_chapter_id AND group_id = p_group_id AND tenant_id = v_tenant_id
    ) THEN
      RAISE EXCEPTION 'INVALID_CHAPTER';
    END IF;
  END IF;

  UPDATE public.content_groups
  SET chapter_id = p_chapter_id
  WHERE content_id = p_content_id AND group_id = p_group_id AND tenant_id = v_tenant_id;

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_lesson_chapter(uuid, uuid, uuid) TO authenticated;

-- 2. reorder_chapter_lessons
CREATE OR REPLACE FUNCTION public.reorder_chapter_lessons(
  p_group_id uuid,
  p_content_ids uuid[]
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_tenant_id uuid;
  v_cid uuid;
  v_order int := 0;
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

  FOREACH v_cid IN ARRAY p_content_ids
  LOOP
    UPDATE public.content_groups
    SET sort_order = v_order
    WHERE content_id = v_cid AND group_id = p_group_id AND tenant_id = v_tenant_id;

    -- Also update sort_order on content table if applicable
    UPDATE public.content
    SET sort_order = v_order
    WHERE id = v_cid AND tenant_id = v_tenant_id;

    v_order := v_order + 1;
  END LOOP;

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.reorder_chapter_lessons(uuid, uuid[]) TO authenticated;

-- 3. reorder_course_chapters
CREATE OR REPLACE FUNCTION public.reorder_course_chapters(
  p_group_id uuid,
  p_chapter_ids uuid[]
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_tenant_id uuid;
  v_chid uuid;
  v_order int := 0;
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

  FOREACH v_chid IN ARRAY p_chapter_ids
  LOOP
    UPDATE public.chapters
    SET sort_order = v_order, updated_at = now()
    WHERE id = v_chid AND group_id = p_group_id AND tenant_id = v_tenant_id;

    v_order := v_order + 1;
  END LOOP;

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.reorder_course_chapters(uuid, uuid[]) TO authenticated;

-- 4. remove_lesson_from_group
CREATE OR REPLACE FUNCTION public.remove_lesson_from_group(
  p_content_id uuid,
  p_group_id uuid
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

  -- Delete from content_groups junction
  DELETE FROM public.content_groups
  WHERE content_id = p_content_id AND group_id = p_group_id AND tenant_id = v_tenant_id;

  -- If this content is exclusively associated with this group and has no other links,
  -- we can clear group_id on content
  UPDATE public.content
  SET group_id = NULL
  WHERE id = p_content_id AND group_id = p_group_id AND tenant_id = v_tenant_id;

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.remove_lesson_from_group(uuid, uuid) TO authenticated;
