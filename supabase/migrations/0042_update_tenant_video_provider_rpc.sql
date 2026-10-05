-- Migration 0042: Add update_tenant_video_provider RPC
CREATE OR REPLACE FUNCTION public.update_tenant_video_provider(p_provider text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.has_role('teacher') THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only teachers can update platform settings';
  END IF;

  IF p_provider NOT IN ('bunny', 'youtube') THEN
    RAISE EXCEPTION 'INVALID_PROVIDER: Provider must be bunny or youtube';
  END IF;

  UPDATE public.tenants
  SET video_provider = p_provider
  WHERE id = public.my_tenant_id();
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_tenant_video_provider(text) TO authenticated;
