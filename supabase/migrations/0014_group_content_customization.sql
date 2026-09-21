-- ==============================================================================
-- 0014_group_content_customization.sql
-- Enables group-specific handouts (files), quizzes (exams), prerequisite locks,
-- and group-specific sort ordering for shared video bank content.
-- ==============================================================================

-- 1. Add group-specific customization columns to content_groups
ALTER TABLE public.content_groups
  ADD COLUMN IF NOT EXISTS file_id uuid REFERENCES public.files(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS associated_exam_id uuid REFERENCES public.exams(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS prerequisite_exam_id uuid REFERENCES public.exams(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS sort_order int DEFAULT 0,
  ADD COLUMN IF NOT EXISTS custom_title text;

-- 2. Create performance indexes
CREATE INDEX IF NOT EXISTS idx_content_groups_file ON public.content_groups(file_id);
CREATE INDEX IF NOT EXISTS idx_content_groups_exam ON public.content_groups(associated_exam_id);
CREATE INDEX IF NOT EXISTS idx_content_groups_prereq ON public.content_groups(prerequisite_exam_id);
CREATE INDEX IF NOT EXISTS idx_content_groups_sort ON public.content_groups(group_id, sort_order);

-- 3. Enhance assign_content_to_groups RPC to support group configs
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

  -- Delete existing group junction entries for this content
  DELETE FROM public.content_groups
  WHERE content_id = p_content_id;

  -- If groups provided, insert new junction entries
  IF p_group_ids IS NOT NULL AND array_length(p_group_ids, 1) > 0 THEN
    v_primary_group := p_group_ids[1];

    FOREACH v_target_group_id IN ARRAY p_group_ids
    LOOP
      IF EXISTS (SELECT 1 FROM public.groups WHERE id = v_target_group_id AND tenant_id = v_caller_tenant) THEN
        -- Check if there is specific configuration for this group in p_group_configs
        v_file_id := NULL;
        v_assoc_exam_id := NULL;
        v_prereq_exam_id := NULL;
        v_sort_order := 0;
        v_custom_title := NULL;

        IF p_group_configs IS NOT NULL AND jsonb_array_length(p_group_configs) > 0 THEN
          SELECT cfg INTO v_config
          FROM jsonb_array_elements(p_group_configs) cfg
          WHERE (cfg->>'group_id')::uuid = v_target_group_id
          LIMIT 1;

          IF v_config IS NOT NULL THEN
            v_file_id := CASE WHEN v_config->>'file_id' IS NOT NULL AND (v_config->>'file_id') != '' THEN (v_config->>'file_id')::uuid ELSE NULL END;
            v_assoc_exam_id := CASE WHEN v_config->>'associated_exam_id' IS NOT NULL AND (v_config->>'associated_exam_id') != '' THEN (v_config->>'associated_exam_id')::uuid ELSE NULL END;
            v_prereq_exam_id := CASE WHEN v_config->>'prerequisite_exam_id' IS NOT NULL AND (v_config->>'prerequisite_exam_id') != '' THEN (v_config->>'prerequisite_exam_id')::uuid ELSE NULL END;
            v_sort_order := COALESCE((v_config->>'sort_order')::int, 0);
            v_custom_title := NULLIF(trim(v_config->>'custom_title'), '');
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
          custom_title
        )
        VALUES (
          v_caller_tenant,
          p_content_id,
          v_target_group_id,
          v_file_id,
          v_assoc_exam_id,
          v_prereq_exam_id,
          v_sort_order,
          v_custom_title
        )
        ON CONFLICT (content_id, group_id) DO UPDATE
        SET file_id = EXCLUDED.file_id,
            associated_exam_id = EXCLUDED.associated_exam_id,
            prerequisite_exam_id = EXCLUDED.prerequisite_exam_id,
            sort_order = EXCLUDED.sort_order,
            custom_title = EXCLUDED.custom_title;
      END IF;
    END LOOP;
  END IF;

  -- Update primary group_id on content
  UPDATE public.content
  SET group_id = v_primary_group,
      updated_at = now()
  WHERE id = p_content_id;

  RETURN jsonb_build_object(
    'success', true,
    'content_id', p_content_id,
    'primary_group_id', v_primary_group,
    'assigned_count', COALESCE(array_length(p_group_ids, 1), 0)
  );
END;
$$;

-- 4. Single-group customization update RPC
CREATE OR REPLACE FUNCTION public.update_group_content_customization(
  p_content_id uuid,
  p_group_id uuid,
  p_file_id uuid DEFAULT NULL,
  p_associated_exam_id uuid DEFAULT NULL,
  p_prerequisite_exam_id uuid DEFAULT NULL,
  p_sort_order int DEFAULT NULL,
  p_custom_title text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_tenant uuid;
BEGIN
  IF NOT public.has_role('teacher') THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only teachers can update content customizations';
  END IF;

  v_caller_tenant := public.my_tenant_id();

  UPDATE public.content_groups
  SET file_id = COALESCE(p_file_id, file_id),
      associated_exam_id = COALESCE(p_associated_exam_id, associated_exam_id),
      prerequisite_exam_id = COALESCE(p_prerequisite_exam_id, prerequisite_exam_id),
      sort_order = COALESCE(p_sort_order, sort_order),
      custom_title = COALESCE(p_custom_title, custom_title)
  WHERE content_id = p_content_id
    AND group_id = p_group_id
    AND tenant_id = v_caller_tenant;

  RETURN jsonb_build_object('success', true);
END;
$$;
