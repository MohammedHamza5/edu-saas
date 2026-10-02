-- Migration 0031: Robust Content Reordering RPC
-- Ensures reordering correctly updates sort_order in both content and content_groups,
-- creating junction rows if missing, and preventing any reversion.

CREATE OR REPLACE FUNCTION public.reorder_content_items(
  p_ids uuid[], 
  p_group_id uuid DEFAULT NULL::uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_now TIMESTAMPTZ := NOW();
BEGIN
  IF p_ids IS NULL OR array_length(p_ids, 1) IS NULL THEN
    RETURN;
  END IF;

  FOR i IN 1..array_length(p_ids, 1) LOOP
    -- 1) Update public.content.sort_order
    UPDATE public.content
    SET
      sort_order = i - 1,
      updated_at = v_now
    WHERE id = p_ids[i];

    -- 2) Update public.content_groups.sort_order for this group
    IF p_group_id IS NOT NULL THEN
      UPDATE public.content_groups
      SET sort_order = i - 1
      WHERE content_id = p_ids[i] AND group_id = p_group_id;

      IF NOT FOUND THEN
        INSERT INTO public.content_groups (tenant_id, content_id, group_id, sort_order)
        SELECT c.tenant_id, p_ids[i], p_group_id, i - 1
        FROM public.content c
        WHERE c.id = p_ids[i]
        ON CONFLICT (content_id, group_id)
        DO UPDATE SET sort_order = EXCLUDED.sort_order;
      END IF;
    ELSE
      UPDATE public.content_groups
      SET sort_order = i - 1
      WHERE content_id = p_ids[i];
    END IF;
  END LOOP;
END;
$function$;
