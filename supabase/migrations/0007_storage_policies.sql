-- ============================================================================
-- Migration: 0007_storage_policies.sql
-- Description: Enable and enforce storage policies for group-content and submission-files
-- ============================================================================

-- Policies for group-content
DROP POLICY IF EXISTS "Allow authenticated read group-content" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated insert group-content" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated update group-content" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated delete group-content" ON storage.objects;

CREATE POLICY "Allow authenticated read group-content"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'group-content');

CREATE POLICY "Allow authenticated insert group-content"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'group-content');

CREATE POLICY "Allow authenticated update group-content"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'group-content');

CREATE POLICY "Allow authenticated delete group-content"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'group-content');

-- Policies for submission-files
DROP POLICY IF EXISTS "Allow authenticated read submission-files" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated insert submission-files" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated update submission-files" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated delete submission-files" ON storage.objects;

CREATE POLICY "Allow authenticated read submission-files"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'submission-files');

CREATE POLICY "Allow authenticated insert submission-files"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'submission-files');

CREATE POLICY "Allow authenticated update submission-files"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'submission-files');

CREATE POLICY "Allow authenticated delete submission-files"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'submission-files');
