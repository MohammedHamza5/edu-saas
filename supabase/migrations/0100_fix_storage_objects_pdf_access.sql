-- ==============================================================================
-- Migration: 0100_fix_storage_objects_pdf_access.sql
-- Description:
--   Updates the storage.objects RLS policy on bucket 'group-content' to use
--   public.can_access_file(name). This allows students and parents to access
--   PDF booklets attached to exams in addition to lectures.
-- ==============================================================================

-- 1. Update Authorized read group-content policy on storage.objects
DROP POLICY IF EXISTS "Authorized read group-content" ON storage.objects;

CREATE POLICY "Authorized read group-content"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'group-content'
  AND (
    (storage.foldername(name))[1] = 'test'
    OR public.can_access_file(name)
  )
);

-- 2. Notify PostgREST
NOTIFY pgrst, 'reload schema';
