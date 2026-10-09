-- Migration 0054: Fix chapter_id persistence in assign_content_to_groups & add atomic batch assignment
-- ==============================================================================
-- 1. Updates assign_content_to_groups to extract chapter_id from group_configs and persist it.
-- 2. Creates assign_batch_content_to_group RPC for instant, sub-second bulk assignments.
-- 3. Fixes unassigned lectures for chapter 'تجربة 102'.
-- ==============================================================================

-- 1. Update assign_content_to_groups
CREATE OR REPLACE FUNCTION public.assign_content_to_groups(
  p_content_id uuid,
  p_group_ids uuid[],
  p_group_configs jsonb DEFAULT '[]'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_role text;
  v_caller_tenant uuid;
  v_content_tenant uuid;
  v_primary_group uuid := NULL;
  v_target_group_id uuid;
  v_config jsonb;
  v_chapter_id uuid;
  v_file_id uuid;
  v_assoc_exam_id uuid;
  v_prereq_exam_id uuid;
  v_sort_order int;
  v_custom_title text;
  v_is_published boolean;
  v_existing_sort_order int;
  v_max_group_order int;
BEGIN
  -- Authenticate & authorize caller
  IF NOT public.has_role('teacher') THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only teachers can distribute content to groups';
  END IF;

  v_caller_tenant := public.my_tenant_id();

  SELECT tenant_id INTO v_content_tenant
  FROM public.content
  WHERE id = p_content_id;

  IF v_content_tenant IS NULL THEN
    RAISE EXCEPTION 'CONTENT_NOT_FOUND: Content record does not exist';
  END IF;

  IF v_content_tenant != v_caller_tenant THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Content belongs to another tenant';
  END IF;

  -- Create temporary table to preserve existing sort orders
  CREATE TEMP TABLE IF NOT EXISTS temp_existing_sort_orders (
    group_id uuid PRIMARY KEY,
    sort_order int
  ) ON COMMIT DROP;

  TRUNCATE temp_existing_sort_orders;

  INSERT INTO temp_existing_sort_orders (group_id, sort_order)
  SELECT group_id, sort_order
  FROM public.content_groups
  WHERE content_id = p_content_id;

  -- Delete existing group junction entries for this content
  DELETE FROM public.content_groups
  WHERE content_id = p_content_id;

  -- If groups provided, insert new junction entries
  IF p_group_ids IS NOT NULL AND array_length(p_group_ids, 1) > 0 THEN
    v_primary_group := p_group_ids[1];

    FOREACH v_target_group_id IN ARRAY p_group_ids
    LOOP
      IF EXISTS (SELECT 1 FROM public.groups WHERE id = v_target_group_id AND tenant_id = v_caller_tenant) THEN
        v_chapter_id := NULL;
        v_file_id := NULL;
        v_assoc_exam_id := NULL;
        v_prereq_exam_id := NULL;
        v_sort_order := NULL;
        v_custom_title := NULL;
        v_is_published := true;
        v_existing_sort_order := NULL;

        -- Check if there was an existing sort order for this content in this group
        SELECT sort_order INTO v_existing_sort_order
        FROM temp_existing_sort_orders
        WHERE group_id = v_target_group_id
        LIMIT 1;

        IF p_group_configs IS NOT NULL AND jsonb_array_length(p_group_configs) > 0 THEN
          SELECT cfg INTO v_config
          FROM jsonb_array_elements(p_group_configs) cfg
          WHERE (cfg->>'group_id')::uuid = v_target_group_id
          LIMIT 1;

          IF v_config IS NOT NULL THEN
            v_chapter_id := CASE WHEN v_config->>'chapter_id' IS NOT NULL AND (v_config->>'chapter_id') != '' THEN (v_config->>'chapter_id')::uuid ELSE NULL END;
            v_file_id := CASE WHEN v_config->>'file_id' IS NOT NULL AND (v_config->>'file_id') != '' THEN (v_config->>'file_id')::uuid ELSE NULL END;
            v_assoc_exam_id := CASE WHEN v_config->>'associated_exam_id' IS NOT NULL AND (v_config->>'associated_exam_id') != '' THEN (v_config->>'associated_exam_id')::uuid ELSE NULL END;
            v_prereq_exam_id := CASE WHEN v_config->>'prerequisite_exam_id' IS NOT NULL AND (v_config->>'prerequisite_exam_id') != '' THEN (v_config->>'prerequisite_exam_id')::uuid ELSE NULL END;
            v_custom_title := NULLIF(trim(v_config->>'custom_title'), '');
            v_is_published := COALESCE((v_config->>'is_published')::boolean, true);

            IF v_config->>'sort_order' IS NOT NULL AND (v_config->>'sort_order') != '' THEN
              v_sort_order := (v_config->>'sort_order')::int;
            END IF;
          END IF;
        END IF;

        -- Calculate current max sort_order for this group / chapter
        IF v_chapter_id IS NOT NULL THEN
          SELECT COALESCE(MAX(sort_order), -1) + 1 INTO v_max_group_order
          FROM public.content_groups
          WHERE group_id = v_target_group_id AND chapter_id = v_chapter_id;
        ELSE
          SELECT COALESCE(MAX(sort_order), -1) + 1 INTO v_max_group_order
          FROM public.content_groups
          WHERE group_id = v_target_group_id AND chapter_id IS NULL;
        END IF;

        -- Guaranteed append logic:
        IF v_existing_sort_order IS NOT NULL THEN
          v_sort_order := COALESCE(v_sort_order, v_existing_sort_order);
        ELSE
          IF v_sort_order IS NULL OR (v_sort_order <= 0 AND v_max_group_order > 0) THEN
            v_sort_order := v_max_group_order;
          END IF;
        END IF;

        INSERT INTO public.content_groups (
          tenant_id,
          content_id,
          group_id,
          chapter_id,
          file_id,
          associated_exam_id,
          prerequisite_exam_id,
          sort_order,
          custom_title,
          is_published
        )
        VALUES (
          v_caller_tenant,
          p_content_id,
          v_target_group_id,
          v_chapter_id,
          v_file_id,
          v_assoc_exam_id,
          v_prereq_exam_id,
          v_sort_order,
          v_custom_title,
          v_is_published
        )
        ON CONFLICT (content_id, group_id) DO UPDATE
        SET chapter_id = EXCLUDED.chapter_id,
            file_id = EXCLUDED.file_id,
            associated_exam_id = EXCLUDED.associated_exam_id,
            prerequisite_exam_id = EXCLUDED.prerequisite_exam_id,
            sort_order = EXCLUDED.sort_order,
            custom_title = EXCLUDED.custom_title,
            is_published = EXCLUDED.is_published;
      END IF;
    END LOOP;
  END IF;

  -- Update primary group_id and sort_order on content
  UPDATE public.content
  SET group_id = v_primary_group,
      sort_order = COALESCE(v_sort_order, sort_order),
      updated_at = now()
  WHERE id = p_content_id;

  RETURN jsonb_build_object(
    'success', true,
    'content_id', p_content_id,
    'assigned_groups', p_group_ids
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.assign_content_to_groups(uuid, uuid[], jsonb) TO authenticated;

-- 2. Create assign_batch_content_to_group RPC for instantaneous batch processing
CREATE OR REPLACE FUNCTION public.assign_batch_content_to_group(
  p_group_id uuid,
  p_items jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_role text;
  v_caller_tenant uuid;
  v_item jsonb;
  v_content_id uuid;
  v_raw_content_id text;
  v_actual_content_id uuid;
  v_chapter_id uuid;
  v_custom_title text;
  v_file_id uuid;
  v_assoc_exam_id uuid;
  v_is_published boolean;
  v_sort_order int;
  v_lib_video record;
  v_success_count int := 0;
BEGIN
  IF NOT public.has_role('teacher') THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only teachers can assign content';
  END IF;

  v_caller_tenant := public.my_tenant_id();

  IF NOT EXISTS (SELECT 1 FROM public.groups WHERE id = p_group_id AND tenant_id = v_caller_tenant) THEN
    RAISE EXCEPTION 'GROUP_NOT_FOUND';
  END IF;

  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RETURN jsonb_build_object('success', true, 'count', 0);
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_raw_content_id := v_item->>'content_id';
    IF v_raw_content_id IS NULL OR v_raw_content_id = '' THEN
      CONTINUE;
    END IF;

    v_content_id := v_raw_content_id::uuid;
    v_custom_title := NULLIF(trim(v_item->>'custom_title'), '');
    v_chapter_id := CASE WHEN v_item->>'chapter_id' IS NOT NULL AND (v_item->>'chapter_id') != '' THEN (v_item->>'chapter_id')::uuid ELSE NULL END;
    v_file_id := CASE WHEN v_item->>'file_id' IS NOT NULL AND (v_item->>'file_id') != '' THEN (v_item->>'file_id')::uuid ELSE NULL END;
    v_assoc_exam_id := CASE WHEN v_item->>'associated_exam_id' IS NOT NULL AND (v_item->>'associated_exam_id') != '' THEN (v_item->>'associated_exam_id')::uuid ELSE NULL END;
    v_is_published := COALESCE((v_item->>'is_published')::boolean, true);

    -- Check if v_content_id is already in public.content
    SELECT id INTO v_actual_content_id
    FROM public.content
    WHERE id = v_content_id AND tenant_id = v_caller_tenant;

    -- If not, check video_library
    IF v_actual_content_id IS NULL THEN
      SELECT * INTO v_lib_video
      FROM public.video_library
      WHERE id = v_content_id AND tenant_id = v_caller_tenant;

      IF v_lib_video.id IS NOT NULL THEN
        -- Check if a content row already exists for this library video
        SELECT c.id INTO v_actual_content_id
        FROM public.content c
        JOIN public.videos v ON v.content_id = c.id
        WHERE v.library_video_id = v_lib_video.id AND c.tenant_id = v_caller_tenant
        LIMIT 1;

        IF v_actual_content_id IS NULL THEN
          INSERT INTO public.content (
            tenant_id,
            group_id,
            title,
            description,
            type,
            status,
            sort_order
          ) VALUES (
            v_caller_tenant,
            p_group_id,
            COALESCE(v_custom_title, v_lib_video.title),
            v_lib_video.description,
            'video',
            'published',
            0
          ) RETURNING id INTO v_actual_content_id;

          INSERT INTO public.videos (
            content_id,
            library_video_id,
            provider,
            provider_video_id,
            thumbnail_url,
            duration,
            status
          ) VALUES (
            v_actual_content_id,
            v_lib_video.id,
            COALESCE(v_lib_video.provider, 'bunny'),
            v_lib_video.provider_video_id,
            v_lib_video.thumbnail_url,
            v_lib_video.duration,
            'ready'
          );
        END IF;
      END IF;
    END IF;

    IF v_actual_content_id IS NOT NULL THEN
      -- Determine sort order within chapter or unassigned bucket
      IF v_chapter_id IS NOT NULL THEN
        SELECT COALESCE(MAX(sort_order), -1) + 1 INTO v_sort_order
        FROM public.content_groups
        WHERE group_id = p_group_id AND chapter_id = v_chapter_id;
      ELSE
        SELECT COALESCE(MAX(sort_order), -1) + 1 INTO v_sort_order
        FROM public.content_groups
        WHERE group_id = p_group_id AND chapter_id IS NULL;
      END IF;

      INSERT INTO public.content_groups (
        tenant_id,
        content_id,
        group_id,
        chapter_id,
        file_id,
        associated_exam_id,
        sort_order,
        custom_title,
        is_published
      ) VALUES (
        v_caller_tenant,
        v_actual_content_id,
        p_group_id,
        v_chapter_id,
        v_file_id,
        v_assoc_exam_id,
        v_sort_order,
        v_custom_title,
        v_is_published
      )
      ON CONFLICT (content_id, group_id) DO UPDATE SET
        chapter_id = EXCLUDED.chapter_id,
        file_id = COALESCE(EXCLUDED.file_id, content_groups.file_id),
        associated_exam_id = COALESCE(EXCLUDED.associated_exam_id, content_groups.associated_exam_id),
        sort_order = EXCLUDED.sort_order,
        custom_title = COALESCE(EXCLUDED.custom_title, content_groups.custom_title),
        is_published = EXCLUDED.is_published;

      IF v_custom_title IS NOT NULL THEN
        UPDATE public.content
        SET title = v_custom_title,
            updated_at = now()
        WHERE id = v_actual_content_id;
      END IF;

      v_success_count := v_success_count + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'count', v_success_count
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.assign_batch_content_to_group(uuid, jsonb) TO authenticated;

-- 3. Fix existing rows for 'تجربة 2' and 'تجربة 3' into chapter 'تجربة 102'
UPDATE public.content_groups
SET chapter_id = '0bdaa0a2-1846-4e40-805c-badfb34904d1'
WHERE id IN ('ab471e84-d242-427b-8661-6cfa75fae0c1', '756a9109-74aa-410f-8e1b-a3a110b77374');
