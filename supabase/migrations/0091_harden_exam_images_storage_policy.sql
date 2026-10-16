-- Migration 0091: Harden exam images and content storage policy on group-content bucket
-- Ensures active teachers can insert, update, select, and delete exam images, questions, 
-- and content across all standard directories (test, exam_images, exams, materials, bank, groups, content).
-- Uses InitPlans (SELECT has_role...) and index-friendly prefix matches to avoid statement timeouts.

DROP POLICY IF EXISTS "Teacher manage exam-images on group-content" ON storage.objects;
CREATE POLICY "Teacher manage exam-images on group-content"
ON storage.objects FOR ALL TO authenticated
USING (
  bucket_id = 'group-content'
  AND (SELECT public.tenant_is_active())
  AND (SELECT public.has_role('teacher'))
  AND (
    name LIKE 'test/%'
    OR name LIKE 'exam_images/%'
    OR name LIKE 'exams/%'
    OR name LIKE 'materials/%'
    OR name LIKE 'bank/%'
    OR name LIKE 'groups/%'
    OR name LIKE 'content/%'
  )
)
WITH CHECK (
  bucket_id = 'group-content'
  AND (SELECT public.tenant_is_active())
  AND (SELECT public.has_role('teacher'))
  AND (
    name LIKE 'test/%'
    OR name LIKE 'exam_images/%'
    OR name LIKE 'exams/%'
    OR name LIKE 'materials/%'
    OR name LIKE 'bank/%'
    OR name LIKE 'groups/%'
    OR name LIKE 'content/%'
  )
);
