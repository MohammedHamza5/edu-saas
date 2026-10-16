-- Migration 0085: Optimize Materials Library CMS Performance & Indexing
-- Adds covering indexes and security invoker for fast folder queries and instant browsing.

-- 1. Covering & Partial Indexes for Root and Subfolder queries
CREATE INDEX IF NOT EXISTS idx_material_library_folder_size 
  ON public.material_library(folder_id, file_size);

CREATE INDEX IF NOT EXISTS idx_material_library_tenant_folder 
  ON public.material_library(tenant_id, folder_id);

CREATE INDEX IF NOT EXISTS idx_material_folders_tenant_parent 
  ON public.material_folders(tenant_id, parent_id);

CREATE INDEX IF NOT EXISTS idx_material_library_root 
  ON public.material_library(tenant_id) WHERE folder_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_material_folders_root 
  ON public.material_folders(tenant_id) WHERE parent_id IS NULL;

-- 2. Material Folders View with security invoker
CREATE OR REPLACE VIEW public.material_folders_with_counts 
WITH (security_invoker = true) AS
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
