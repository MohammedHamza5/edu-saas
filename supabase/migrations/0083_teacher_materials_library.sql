-- Migration 0079: Teacher Materials / Files Library CMS
-- Provides intelligent file organization, folder hierarchy, deduplication, and instant lecture attachment.

-- 1. Material Folders
CREATE TABLE IF NOT EXISTS public.material_folders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    parent_id uuid REFERENCES public.material_folders(id) ON DELETE CASCADE,
    name text NOT NULL,
    color text NOT NULL DEFAULT '#EA580C',
    icon text NOT NULL DEFAULT 'folder',
    sort_order int NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_material_folders_tenant ON public.material_folders(tenant_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_material_folders_parent ON public.material_folders(parent_id);

ALTER TABLE public.material_folders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS material_folders_teacher_all ON public.material_folders;
CREATE POLICY material_folders_teacher_all ON public.material_folders FOR ALL TO authenticated
  USING (public.has_role('teacher') AND public.tenant_is_active() AND tenant_id = public.my_tenant_id())
  WITH CHECK (public.has_role('teacher') AND public.tenant_is_active() AND tenant_id = public.my_tenant_id());


-- 2. Material Library Table
CREATE TABLE IF NOT EXISTS public.material_library (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    folder_id uuid REFERENCES public.material_folders(id) ON DELETE SET NULL,
    title text NOT NULL,
    description text,
    file_name text NOT NULL,
    storage_path text NOT NULL,
    file_size bigint NOT NULL DEFAULT 0,
    mime_type text NOT NULL DEFAULT 'application/pdf',
    storage_provider text NOT NULL DEFAULT 'supabase',
    file_hash text,
    assigned_lectures_count int NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_material_library_tenant ON public.material_library(tenant_id);
CREATE INDEX IF NOT EXISTS idx_material_library_folder ON public.material_library(folder_id);
CREATE INDEX IF NOT EXISTS idx_material_library_hash ON public.material_library(tenant_id, file_hash);
CREATE INDEX IF NOT EXISTS idx_material_library_title ON public.material_library(tenant_id, title);

ALTER TABLE public.material_library ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS material_library_teacher_all ON public.material_library;
CREATE POLICY material_library_teacher_all ON public.material_library FOR ALL TO authenticated
  USING (public.has_role('teacher') AND public.tenant_is_active() AND tenant_id = public.my_tenant_id())
  WITH CHECK (public.has_role('teacher') AND public.tenant_is_active() AND tenant_id = public.my_tenant_id());


-- 3. Link library material to public.files instances
ALTER TABLE public.files 
ADD COLUMN IF NOT EXISTS library_material_id uuid REFERENCES public.material_library(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_files_library_material ON public.files(library_material_id);


-- 4. Automatic usage count trigger
CREATE OR REPLACE FUNCTION public.sync_material_library_usage()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF (TG_OP = 'INSERT' AND NEW.library_material_id IS NOT NULL) THEN
        UPDATE public.material_library
        SET assigned_lectures_count = assigned_lectures_count + 1,
            updated_at = now()
        WHERE id = NEW.library_material_id;
    ELSIF (TG_OP = 'DELETE' AND OLD.library_material_id IS NOT NULL) THEN
        UPDATE public.material_library
        SET assigned_lectures_count = GREATEST(assigned_lectures_count - 1, 0),
            updated_at = now()
        WHERE id = OLD.library_material_id;
    ELSIF (TG_OP = 'UPDATE') THEN
        IF (OLD.library_material_id IS DISTINCT FROM NEW.library_material_id) THEN
            IF (OLD.library_material_id IS NOT NULL) THEN
                UPDATE public.material_library
                SET assigned_lectures_count = GREATEST(assigned_lectures_count - 1, 0),
                    updated_at = now()
                WHERE id = OLD.library_material_id;
            END IF;
            IF (NEW.library_material_id IS NOT NULL) THEN
                UPDATE public.material_library
                SET assigned_lectures_count = assigned_lectures_count + 1,
                    updated_at = now()
                WHERE id = NEW.library_material_id;
            END IF;
        END IF;
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_material_library_usage ON public.files;
CREATE TRIGGER trg_sync_material_library_usage
AFTER INSERT OR UPDATE OR DELETE ON public.files
FOR EACH ROW EXECUTE FUNCTION public.sync_material_library_usage();


-- 5. Extended Material Folders View with counts
CREATE OR REPLACE VIEW public.material_folders_with_counts AS
SELECT 
  f.id,
  f.tenant_id,
  f.parent_id,
  f.name,
  f.color,
  f.icon,
  f.sort_order,
  f.created_at,
  f.updated_at,
  (SELECT count(*)::int FROM public.material_library ml WHERE ml.folder_id = f.id) AS files_count,
  (SELECT COALESCE(sum(ml.file_size), 0)::bigint FROM public.material_library ml WHERE ml.folder_id = f.id) AS total_size_bytes,
  (SELECT count(*)::int FROM public.material_folders sf WHERE sf.parent_id = f.id) AS subfolders_count
FROM public.material_folders f;

GRANT SELECT ON public.material_folders_with_counts TO authenticated;


-- 6. RPC: Smart Deduplication Check
CREATE OR REPLACE FUNCTION public.find_duplicate_material(
    p_file_hash text DEFAULT NULL,
    p_file_name text DEFAULT NULL,
    p_file_size bigint DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_tenant_id uuid;
    v_record record;
BEGIN
    IF NOT (public.has_role('teacher') AND public.tenant_is_active()) THEN
        RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
    END IF;

    v_tenant_id := public.my_tenant_id();

    -- Check by hash first if provided
    IF p_file_hash IS NOT NULL AND length(trim(p_file_hash)) > 0 THEN
        SELECT * INTO v_record
        FROM public.material_library
        WHERE tenant_id = v_tenant_id AND file_hash = p_file_hash
        LIMIT 1;
        
        IF FOUND THEN
            RETURN jsonb_build_object(
                'found', true,
                'match_type', 'hash',
                'material', row_to_json(v_record)
            );
        END IF;
    END IF;

    -- Fallback check by exact file_name + file_size
    IF p_file_name IS NOT NULL AND p_file_size > 0 THEN
        SELECT * INTO v_record
        FROM public.material_library
        WHERE tenant_id = v_tenant_id 
          AND file_name = p_file_name 
          AND file_size = p_file_size
        LIMIT 1;

        IF FOUND THEN
            RETURN jsonb_build_object(
                'found', true,
                'match_type', 'metadata',
                'material', row_to_json(v_record)
            );
        END IF;
    END IF;

    RETURN jsonb_build_object('found', false);
END;
$$;

GRANT EXECUTE ON FUNCTION public.find_duplicate_material(text, text, bigint) TO authenticated;

-- Allow teachers to preview material_library files directly from Cloudflare R2
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

  -- 1) Teacher: can access if file belongs to teacher's tenant (in files table or material_library)
  IF v_role = 'teacher' THEN
    RETURN EXISTS (
      SELECT 1 FROM public.files f
      WHERE f.storage_path = p_storage_path
        AND f.tenant_id = v_tenant_id
    ) OR EXISTS (
      SELECT 1 FROM public.material_library ml
      WHERE ml.storage_path = p_storage_path
        AND ml.tenant_id = v_tenant_id
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

  -- 3) Parent: can access if any active child can access
  IF v_role = 'parent' THEN
    RETURN EXISTS (
      SELECT 1
      FROM public.parent_students ps
      JOIN public.group_members gm ON (
        gm.student_id = ps.student_id 
        AND gm.status = 'active'
      )
      JOIN public.files f ON f.storage_path = p_storage_path
      JOIN public.content c ON c.id = f.content_id
      JOIN public.groups g ON g.id = gm.group_id
      WHERE ps.parent_id = v_user_id
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
        AND (
          gm.joined_at <= COALESCE(c.published_at, c.created_at)
          OR g.previous_content_access = 'allow'
        )
    );
  END IF;

  RETURN false;
END;
$$;
