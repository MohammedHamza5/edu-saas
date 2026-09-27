-- ============================================================================
-- Migration: 0020_storage_provider_support.sql
-- Description: Add storage_provider to files table and create can_access_file
--              RPC to authorize Cloudflare R2 presigned download requests.
-- ============================================================================

-- 1. Add storage_provider to files table
ALTER TABLE public.files 
  ADD COLUMN IF NOT EXISTS storage_provider text NOT NULL DEFAULT 'supabase' 
  CHECK (storage_provider IN ('supabase', 'r2'));

-- 2. Create index on storage_path for fast lookup
CREATE INDEX IF NOT EXISTS idx_files_storage_path 
  ON public.files(storage_path);

-- 3. Security definer function to strictly check whether the caller
--    (authenticated user) is permitted to access a specific file.
CREATE OR REPLACE FUNCTION public.can_access_file(p_storage_path text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role text;
  v_tenant_id uuid;
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN false;
  END IF;

  IF NOT public.tenant_is_active() THEN
    RETURN false;
  END IF;

  SELECT role, tenant_id INTO v_role, v_tenant_id
  FROM public.users
  WHERE id = v_user_id;

  IF v_role IS NULL THEN
    RETURN false;
  END IF;

  -- 1) Teacher: can access if file belongs to teacher's tenant
  IF v_role = 'teacher' THEN
    RETURN EXISTS (
      SELECT 1 FROM public.files f
      WHERE f.storage_path = p_storage_path
        AND f.tenant_id = v_tenant_id
    );
  END IF;

  -- 2) Student: can access if content is published and student is in the assigned group
  IF v_role = 'student' THEN
    RETURN EXISTS (
      SELECT 1 
      FROM public.files f
      JOIN public.content c ON c.id = f.content_id
      JOIN public.group_members gm ON (
        gm.student_id = v_user_id 
        AND gm.status = 'active'
        AND (
          -- Direct group linkage
          (c.group_id = gm.group_id AND c.status = 'published')
          OR
          -- Multi-group linkage via content_groups junction
          EXISTS (
            SELECT 1 FROM public.content_groups cg
            WHERE cg.content_id = c.id
              AND cg.group_id = gm.group_id
              AND cg.is_published = true
          )
        )
      )
      JOIN public.groups g ON g.id = gm.group_id
      WHERE f.storage_path = p_storage_path
        AND (
          gm.joined_at <= COALESCE(c.published_at, c.created_at)
          OR g.previous_content_access = 'allow'
        )
    );
  END IF;

  -- 3) Parent: can access if child has access
  IF v_role = 'parent' THEN
    RETURN EXISTS (
      SELECT 1 
      FROM public.files f
      JOIN public.content c ON c.id = f.content_id
      JOIN public.parent_students ps ON ps.parent_id = v_user_id
      JOIN public.group_members gm ON (
        gm.student_id = ps.student_id
        AND gm.status = 'active'
        AND (
          (c.group_id = gm.group_id AND c.status = 'published')
          OR
          EXISTS (
            SELECT 1 FROM public.content_groups cg
            WHERE cg.content_id = c.id
              AND cg.group_id = gm.group_id
              AND cg.is_published = true
          )
        )
      )
      JOIN public.groups g ON g.id = gm.group_id
      WHERE f.storage_path = p_storage_path
        AND (
          gm.joined_at <= COALESCE(c.published_at, c.created_at)
          OR g.previous_content_access = 'allow'
        )
    );
  END IF;

  RETURN false;
END;
$$;
