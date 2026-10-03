-- Migration 0033: Append new content to the end of group courses automatically
-- Fixes issue where adding a new lesson defaults sort_order to 0 (top/first)
-- instead of placing it at the end of the group syllabus.

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
  v_file_id uuid;
  v_assoc_exam_id uuid;
  v_prereq_exam_id uuid;
  v_sort_order int;
  v_custom_title text;
  v_is_published boolean;
  v_existing_sort_order int;
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

        -- If sort_order not explicitly provided:
        IF v_sort_order IS NULL THEN
          IF v_existing_sort_order IS NOT NULL THEN
            -- Preserve existing sort order when editing
            v_sort_order := v_existing_sort_order;
          ELSE
            -- New assignment: append to the end of the group's syllabus
            SELECT COALESCE(MAX(sort_order), -1) + 1 INTO v_sort_order
            FROM public.content_groups
            WHERE group_id = v_target_group_id;
          END IF;
        END IF;

        INSERT INTO public.content_groups (
          tenant_id,
          content_id,
          group_id,
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
          v_file_id,
          v_assoc_exam_id,
          v_prereq_exam_id,
          v_sort_order,
          v_custom_title,
          v_is_published
        )
        ON CONFLICT (content_id, group_id) DO UPDATE
        SET file_id = EXCLUDED.file_id,
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
    'primary_group_id', v_primary_group,
    'assigned_count', COALESCE(array_length(p_group_ids, 1), 0),
    'sort_order', v_sort_order
  );
END;
$$;
