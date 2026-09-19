-- ============================================================================
-- Migration: 0012_fix_content_cascade_and_relationships.sql
-- Description:
-- 1. Updates foreign keys referencing public.content and their child tables
--    with ON DELETE CASCADE to allow clean deletion of content, videos,
--    files, assignments, and exams without foreign key constraint violations.
-- ============================================================================

-- 1. Videos and progress cascade
ALTER TABLE public.videos 
  DROP CONSTRAINT IF EXISTS videos_content_id_fkey,
  ADD CONSTRAINT videos_content_id_fkey 
    FOREIGN KEY (content_id) REFERENCES public.content(id) ON DELETE CASCADE;

ALTER TABLE public.video_progress 
  DROP CONSTRAINT IF EXISTS video_progress_video_id_fkey,
  ADD CONSTRAINT video_progress_video_id_fkey 
    FOREIGN KEY (video_id) REFERENCES public.videos(id) ON DELETE CASCADE;

-- 2. Files cascade
ALTER TABLE public.files 
  DROP CONSTRAINT IF EXISTS files_content_id_fkey,
  ADD CONSTRAINT files_content_id_fkey 
    FOREIGN KEY (content_id) REFERENCES public.content(id) ON DELETE CASCADE;

-- 3. Assignments and submissions cascade
ALTER TABLE public.assignments 
  DROP CONSTRAINT IF EXISTS assignments_content_id_fkey,
  ADD CONSTRAINT assignments_content_id_fkey 
    FOREIGN KEY (content_id) REFERENCES public.content(id) ON DELETE CASCADE;

ALTER TABLE public.assignment_submissions 
  DROP CONSTRAINT IF EXISTS assignment_submissions_assignment_id_fkey,
  ADD CONSTRAINT assignment_submissions_assignment_id_fkey 
    FOREIGN KEY (assignment_id) REFERENCES public.assignments(id) ON DELETE CASCADE;

ALTER TABLE public.submission_files 
  DROP CONSTRAINT IF EXISTS submission_files_submission_id_fkey,
  ADD CONSTRAINT submission_files_submission_id_fkey 
    FOREIGN KEY (submission_id) REFERENCES public.assignment_submissions(id) ON DELETE CASCADE;

-- 4. Exams and exam versions / questions / attempts cascade
ALTER TABLE public.exams 
  DROP CONSTRAINT IF EXISTS exams_content_id_fkey,
  ADD CONSTRAINT exams_content_id_fkey 
    FOREIGN KEY (content_id) REFERENCES public.content(id) ON DELETE CASCADE;

ALTER TABLE public.exam_versions 
  DROP CONSTRAINT IF EXISTS exam_versions_exam_id_fkey,
  ADD CONSTRAINT exam_versions_exam_id_fkey 
    FOREIGN KEY (exam_id) REFERENCES public.exams(id) ON DELETE CASCADE;

ALTER TABLE public.exam_questions 
  DROP CONSTRAINT IF EXISTS exam_questions_exam_version_id_fkey,
  ADD CONSTRAINT exam_questions_exam_version_id_fkey 
    FOREIGN KEY (exam_version_id) REFERENCES public.exam_versions(id) ON DELETE CASCADE;

ALTER TABLE public.question_options 
  DROP CONSTRAINT IF EXISTS question_options_question_id_fkey,
  ADD CONSTRAINT question_options_question_id_fkey 
    FOREIGN KEY (question_id) REFERENCES public.exam_questions(id) ON DELETE CASCADE;

ALTER TABLE public.exam_attempts 
  DROP CONSTRAINT IF EXISTS exam_attempts_exam_id_fkey,
  ADD CONSTRAINT exam_attempts_exam_id_fkey 
    FOREIGN KEY (exam_id) REFERENCES public.exams(id) ON DELETE CASCADE;

ALTER TABLE public.exam_attempts 
  DROP CONSTRAINT IF EXISTS exam_attempts_exam_version_id_fkey,
  ADD CONSTRAINT exam_attempts_exam_version_id_fkey 
    FOREIGN KEY (exam_version_id) REFERENCES public.exam_versions(id) ON DELETE CASCADE;

ALTER TABLE public.exam_answers 
  DROP CONSTRAINT IF EXISTS exam_answers_attempt_id_fkey,
  ADD CONSTRAINT exam_answers_attempt_id_fkey 
    FOREIGN KEY (attempt_id) REFERENCES public.exam_attempts(id) ON DELETE CASCADE;

ALTER TABLE public.exam_answers 
  DROP CONSTRAINT IF EXISTS exam_answers_question_id_fkey,
  ADD CONSTRAINT exam_answers_question_id_fkey 
    FOREIGN KEY (question_id) REFERENCES public.exam_questions(id) ON DELETE CASCADE;

-- 5. Activity log preserve record on delete
ALTER TABLE public.activity_events 
  DROP CONSTRAINT IF EXISTS activity_events_content_id_fkey,
  ADD CONSTRAINT activity_events_content_id_fkey 
    FOREIGN KEY (content_id) REFERENCES public.content(id) ON DELETE SET NULL;

-- 6. Storage RLS policies for Central Video Bank handouts and materials
DROP POLICY IF EXISTS "Teacher upload group-content" ON storage.objects;
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
    OR (storage.foldername(name))[1] IN ('bank', 'bank_handouts', 'materials', 'content')
  )
);

DROP POLICY IF EXISTS "Teacher update group-content" ON storage.objects;
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
    OR (storage.foldername(name))[1] IN ('bank', 'bank_handouts', 'materials', 'content')
  )
);

DROP POLICY IF EXISTS "Teacher delete group-content" ON storage.objects;
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
    OR (storage.foldername(name))[1] IN ('bank', 'bank_handouts', 'materials', 'content')
  )
);

DROP POLICY IF EXISTS "Authorized read group-content" ON storage.objects;
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
        OR (storage.foldername(name))[1] IN ('bank', 'bank_handouts', 'materials', 'content')
      )
    )
    OR (
      public.has_role('student')
      AND exists (
        select 1 from public.files f
        join public.content c on c.id = f.content_id
        left join public.group_members gm on (
          gm.group_id = c.group_id
          OR exists (
            select 1 from public.content_groups cg
            where cg.content_id = c.id and cg.group_id = gm.group_id
          )
        )
        where f.storage_path = storage.objects.name
          and c.status = 'published'
          and gm.student_id = auth.uid()
          and gm.status = 'active'
          and (
            gm.joined_at <= c.published_at
            or (select g.previous_content_access from public.groups g where g.id = gm.group_id) = 'allow'
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
          left join public.group_members gm on (
            gm.group_id = c.group_id
            OR exists (
              select 1 from public.content_groups cg
              where cg.content_id = c.id and cg.group_id = gm.group_id
            )
          )
          where f.storage_path = storage.objects.name
            and c.status = 'published'
            and public.parent_has_child_in_group(auth.uid(), gm.group_id)
        )
      )
    )
  )
);

