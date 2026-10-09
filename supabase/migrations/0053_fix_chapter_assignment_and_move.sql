-- Migration 0053: Fix Chapter Assignment and Move Helpers
-- ==============================================================================
-- 1. Updates set_lesson_chapter RPC:
--    - Supports status IN ('active', 'pending') for teachers.
--    - Uses atomic UPSERT on content_groups so unassigned lessons properly attach.
-- 2. Updates assign_folder_as_chapter_to_group RPC:
--    - Tolerates matching chapter titles via ON CONFLICT DO UPDATE.
--    - Matches video_library records with status != 'failed'.
--    - Correctly attaches all video lessons to the generated chapter.
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
  v_next_order int;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT tenant_id INTO v_tenant_id
  FROM public.users
  WHERE id = v_caller_id AND role = 'teacher' AND status IN ('active', 'pending');

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

  -- Determine next sort order in target chapter or unassigned bucket
  IF p_chapter_id IS NOT NULL THEN
    SELECT COALESCE(MAX(sort_order), -1) + 1 INTO v_next_order
    FROM public.content_groups
    WHERE group_id = p_group_id AND chapter_id = p_chapter_id;
  ELSE
    SELECT COALESCE(MAX(sort_order), -1) + 1 INTO v_next_order
    FROM public.content_groups
    WHERE group_id = p_group_id AND chapter_id IS NULL;
  END IF;

  -- Atomic UPSERT into content_groups
  INSERT INTO public.content_groups (
    tenant_id,
    content_id,
    group_id,
    chapter_id,
    sort_order,
    is_published
  ) VALUES (
    v_tenant_id,
    p_content_id,
    p_group_id,
    p_chapter_id,
    v_next_order,
    true
  )
  ON CONFLICT (content_id, group_id) DO UPDATE SET
    chapter_id = EXCLUDED.chapter_id,
    sort_order = EXCLUDED.sort_order;

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_lesson_chapter(uuid, uuid, uuid) TO authenticated;

-- 2. assign_folder_as_chapter_to_group
CREATE OR REPLACE FUNCTION public.assign_folder_as_chapter_to_group(
  p_folder_id uuid,
  p_group_id uuid,
  p_chapter_title text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_caller_role text;
  v_tenant_id uuid;
  v_folder_name text;
  v_chapter_title text;
  v_chapter_id uuid;
  v_chapter_order int;
  v_video_row record;
  v_content_id uuid;
  v_current_lesson_order int := 0;
  v_added_count int := 0;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT role, tenant_id INTO v_caller_role, v_tenant_id
  FROM public.users
  WHERE id = v_caller_id AND status IN ('active', 'pending');

  IF v_caller_role != 'teacher' OR v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  SELECT name INTO v_folder_name
  FROM public.video_folders
  WHERE id = p_folder_id AND tenant_id = v_tenant_id;

  IF v_folder_name IS NULL THEN
    RAISE EXCEPTION 'FOLDER_NOT_FOUND';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.groups
    WHERE id = p_group_id AND tenant_id = v_tenant_id
  ) THEN
    RAISE EXCEPTION 'GROUP_NOT_FOUND';
  END IF;

  v_chapter_title := COALESCE(NULLIF(TRIM(p_chapter_title), ''), v_folder_name);

  SELECT COALESCE(MAX(sort_order), -1) + 1 INTO v_chapter_order
  FROM public.chapters
  WHERE group_id = p_group_id;

  -- Upsert chapter idempotently to avoid unique constraint collisions
  INSERT INTO public.chapters (
    tenant_id,
    group_id,
    title,
    sort_order,
    source_folder_id,
    is_published
  ) VALUES (
    v_tenant_id,
    p_group_id,
    v_chapter_title,
    v_chapter_order,
    p_folder_id,
    true
  )
  ON CONFLICT (group_id, LOWER(TRIM(title))) DO UPDATE
    SET source_folder_id = COALESCE(EXCLUDED.source_folder_id, chapters.source_folder_id),
        updated_at = NOW()
  RETURNING id INTO v_chapter_id;

  SELECT COALESCE(MAX(sort_order), -1) + 1 INTO v_current_lesson_order
  FROM public.content_groups
  WHERE group_id = p_group_id;

  FOR v_video_row IN (
    SELECT id, title, description, provider, provider_video_id, thumbnail_url, duration
    FROM public.video_library
    WHERE folder_id = p_folder_id 
      AND tenant_id = v_tenant_id
      AND status != 'failed'
    ORDER BY created_at ASC
  ) LOOP
    SELECT c.id INTO v_content_id
    FROM public.content c
    JOIN public.videos v ON v.content_id = c.id
    WHERE v.library_video_id = v_video_row.id
      AND c.tenant_id = v_tenant_id
    LIMIT 1;

    IF v_content_id IS NULL THEN
      INSERT INTO public.content (
        tenant_id,
        group_id,
        title,
        description,
        type,
        status,
        sort_order
      ) VALUES (
        v_tenant_id,
        p_group_id,
        v_video_row.title,
        v_video_row.description,
        'video',
        'published',
        v_current_lesson_order
      ) RETURNING id INTO v_content_id;

      INSERT INTO public.videos (
        content_id,
        library_video_id,
        provider,
        provider_video_id,
        thumbnail_url,
        duration,
        status
      ) VALUES (
        v_content_id,
        v_video_row.id,
        COALESCE(v_video_row.provider, 'bunny'),
        v_video_row.provider_video_id,
        v_video_row.thumbnail_url,
        v_video_row.duration,
        'ready'
      );
    END IF;

    INSERT INTO public.content_groups (
      tenant_id,
      content_id,
      group_id,
      chapter_id,
      sort_order,
      is_published
    ) VALUES (
      v_tenant_id,
      v_content_id,
      p_group_id,
      v_chapter_id,
      v_current_lesson_order,
      true
    )
    ON CONFLICT (content_id, group_id) DO UPDATE SET
      chapter_id = EXCLUDED.chapter_id,
      sort_order = EXCLUDED.sort_order,
      is_published = true;

    v_current_lesson_order := v_current_lesson_order + 1;
    v_added_count := v_added_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'chapter_id', v_chapter_id,
    'chapter_title', v_chapter_title,
    'lessons_count', v_added_count
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.assign_folder_as_chapter_to_group(uuid, uuid, text) TO authenticated;
