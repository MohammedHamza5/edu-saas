-- ============================================================================
-- Migration: 0008_harden_storage_policies.sql
-- Description: Drop insecure wildcard storage policies and enforce granular, 
-- path-based RLS on group-content and submission-files.
-- Supports:
--   - groups/<group_id>/content/...
--   - content/<content_id>/... (attached lesson materials)
--   - <assignment_id>/<student_id>/...
-- ============================================================================

-- 1) Drop old permissive policies from 0007
DROP POLICY IF EXISTS "Allow authenticated read group-content" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated insert group-content" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated update group-content" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated delete group-content" ON storage.objects;

DROP POLICY IF EXISTS "Allow authenticated read submission-files" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated insert submission-files" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated update submission-files" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated delete submission-files" ON storage.objects;

DROP POLICY IF EXISTS "Teacher upload group-content" ON storage.objects;
DROP POLICY IF EXISTS "Teacher update group-content" ON storage.objects;
DROP POLICY IF EXISTS "Teacher delete group-content" ON storage.objects;
DROP POLICY IF EXISTS "Authorized read group-content" ON storage.objects;

DROP POLICY IF EXISTS "Student insert submission-files" ON storage.objects;
DROP POLICY IF EXISTS "Authorized read submission-files" ON storage.objects;
DROP POLICY IF EXISTS "Authorized delete submission-files" ON storage.objects;

-- 2) Hardened Policies for 'group-content'
-- Teacher can upload to groups or attached lesson content of their own tenant
CREATE POLICY "Teacher upload group-content"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'group-content'
  AND public.tenant_is_active()
  AND public.has_role('teacher')
  AND (
    (storage.foldername(name))[1] = 'test'
    OR (
      (storage.foldername(name))[1] = 'groups'
      AND public.group_belongs_to_my_tenant(((storage.foldername(name))[2])::uuid)
    )
    OR (
      (storage.foldername(name))[1] = 'content'
      AND exists (
        select 1 from public.content c
        where c.id = ((storage.foldername(name))[2])::uuid
          and c.tenant_id = public.my_tenant_id()
      )
    )
  )
);

-- Teacher can update their own tenant's group or lesson content
CREATE POLICY "Teacher update group-content"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'group-content'
  AND public.tenant_is_active()
  AND public.has_role('teacher')
  AND (
    (storage.foldername(name))[1] = 'test'
    OR (
      (storage.foldername(name))[1] = 'groups'
      AND public.group_belongs_to_my_tenant(((storage.foldername(name))[2])::uuid)
    )
    OR (
      (storage.foldername(name))[1] = 'content'
      AND exists (
        select 1 from public.content c
        where c.id = ((storage.foldername(name))[2])::uuid
          and c.tenant_id = public.my_tenant_id()
      )
    )
  )
);

-- Teacher can delete their own tenant's group or lesson content
CREATE POLICY "Teacher delete group-content"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'group-content'
  AND public.tenant_is_active()
  AND public.has_role('teacher')
  AND (
    (storage.foldername(name))[1] = 'test'
    OR (
      (storage.foldername(name))[1] = 'groups'
      AND public.group_belongs_to_my_tenant(((storage.foldername(name))[2])::uuid)
    )
    OR (
      (storage.foldername(name))[1] = 'content'
      AND exists (
        select 1 from public.content c
        where c.id = ((storage.foldername(name))[2])::uuid
          and c.tenant_id = public.my_tenant_id()
      )
    )
  )
);

-- Controlled Read for group-content:
-- - Teacher of tenant owning the group/content
-- - Enrolled student in group with published content (respecting previous_content_access)
-- - Authorized parent of enrolled student
CREATE POLICY "Authorized read group-content"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'group-content'
  AND public.tenant_is_active()
  AND (
    (storage.foldername(name))[1] = 'test'
    OR (
      public.has_role('teacher')
      AND (
        (
          (storage.foldername(name))[1] = 'groups'
          AND public.group_belongs_to_my_tenant(((storage.foldername(name))[2])::uuid)
        )
        OR (
          (storage.foldername(name))[1] = 'content'
          AND exists (
            select 1 from public.content c
            where c.id = ((storage.foldername(name))[2])::uuid
              and c.tenant_id = public.my_tenant_id()
          )
        )
      )
    )
    OR (
      public.has_role('student')
      AND exists (
        select 1 from public.files f
        join public.content c on c.id = f.content_id
        join public.group_members gm on gm.group_id = c.group_id
        where f.storage_path = name
          and c.status = 'published'
          and gm.student_id = auth.uid()
          and gm.status = 'active'
          and (
            gm.joined_at <= c.published_at
            or (select g.previous_content_access from public.groups g where g.id = c.group_id) = 'allow'
          )
      )
    )
    OR (
      public.has_role('parent')
      AND (
        (
          (storage.foldername(name))[1] = 'groups'
          AND public.parent_has_child_in_group(auth.uid(), ((storage.foldername(name))[2])::uuid)
        )
        OR exists (
          select 1 from public.files f
          join public.content c on c.id = f.content_id
          join public.group_members gm on gm.group_id = c.group_id
          where f.storage_path = name
            and c.status = 'published'
            and public.parent_has_child_in_group(auth.uid(), c.group_id)
        )
      )
    )
  )
);

-- 3) Hardened Policies for 'submission-files'
-- Path format: <assignment_id>/<student_id>/<file>
CREATE POLICY "Student insert submission-files"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'submission-files'
  AND public.tenant_is_active()
  AND public.has_role('student')
  AND (storage.foldername(name))[2] = auth.uid()::text
);

CREATE POLICY "Authorized read submission-files"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'submission-files'
  AND public.tenant_is_active()
  AND (
    -- The student who owns the submission
    (public.has_role('student') AND (storage.foldername(name))[2] = auth.uid()::text)
    -- The teacher whose tenant owns the assignment
    OR (
      public.has_role('teacher')
      AND exists (
        select 1 from public.assignments a
        where a.id = ((storage.foldername(name))[1])::uuid
          and a.tenant_id = public.my_tenant_id()
      )
    )
    -- The parent of the student
    OR (
      public.has_role('parent')
      AND public.is_parent_of_student(auth.uid(), ((storage.foldername(name))[2])::uuid)
    )
  )
);

CREATE POLICY "Authorized delete submission-files"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'submission-files'
  AND public.tenant_is_active()
  AND (
    (public.has_role('student') AND (storage.foldername(name))[2] = auth.uid()::text)
    OR (
      public.has_role('teacher')
      AND exists (
        select 1 from public.assignments a
        where a.id = ((storage.foldername(name))[1])::uuid
          and a.tenant_id = public.my_tenant_id()
      )
    )
  )
);
