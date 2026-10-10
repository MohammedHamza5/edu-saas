-- 0062_fix_general_exams_and_questions_rls.sql
-- Fix general exams (group_id IS NULL) and multi-group content_groups accessibility for students

-- 1. Content table policy
DROP POLICY IF EXISTS content_student_read_published ON public.content;
CREATE POLICY content_student_read_published ON public.content
FOR SELECT TO authenticated
USING (
  has_role('student')
  AND tenant_is_active()
  AND status = 'published'
  AND tenant_id = my_tenant_id()
  AND (
    group_id IS NULL
    OR EXISTS (
      SELECT 1 FROM public.group_members gm
      WHERE gm.student_id = auth.uid()
        AND gm.group_id = content.group_id
        AND gm.status = 'active'
        AND (
          content.published_at IS NULL
          OR gm.joined_at <= content.published_at
          OR (SELECT g.previous_content_access FROM public.groups g WHERE g.id = content.group_id) = 'allow'
        )
    )
    OR EXISTS (
      SELECT 1 FROM public.content_groups cg
      JOIN public.group_members gm ON gm.group_id = cg.group_id
      WHERE cg.content_id = content.id
        AND gm.student_id = auth.uid()
        AND gm.status = 'active'
        AND (
          content.published_at IS NULL
          OR gm.joined_at <= content.published_at
          OR (SELECT g.previous_content_access FROM public.groups g WHERE g.id = cg.group_id) = 'allow'
        )
    )
  )
);

-- 2. Exams table policy
DROP POLICY IF EXISTS exams_student_read_published ON public.exams;
CREATE POLICY exams_student_read_published ON public.exams
FOR SELECT TO authenticated
USING (
  has_role('student')
  AND tenant_is_active()
  AND EXISTS (
    SELECT 1 FROM public.content c
    WHERE c.id = exams.content_id
      AND c.status = 'published'
      AND c.tenant_id = my_tenant_id()
      AND (
        c.group_id IS NULL
        OR EXISTS (
          SELECT 1 FROM public.group_members gm
          WHERE gm.student_id = auth.uid()
            AND gm.group_id = c.group_id
            AND gm.status = 'active'
            AND (
              c.published_at IS NULL
              OR gm.joined_at <= c.published_at
              OR (SELECT g.previous_content_access FROM public.groups g WHERE g.id = c.group_id) = 'allow'
            )
        )
        OR EXISTS (
          SELECT 1 FROM public.content_groups cg
          JOIN public.group_members gm ON gm.group_id = cg.group_id
          WHERE (cg.content_id = c.id OR cg.associated_exam_id = exams.id)
            AND gm.student_id = auth.uid()
            AND gm.status = 'active'
            AND (
              c.published_at IS NULL
              OR gm.joined_at <= c.published_at
              OR (SELECT g.previous_content_access FROM public.groups g WHERE g.id = cg.group_id) = 'allow'
            )
        )
      )
  )
);

-- 3. Exam versions table policy
DROP POLICY IF EXISTS ev_student_read_published ON public.exam_versions;
CREATE POLICY ev_student_read_published ON public.exam_versions
FOR SELECT TO authenticated
USING (
  has_role('student')
  AND tenant_is_active()
  AND status = 'published'
  AND EXISTS (
    SELECT 1 FROM public.exams e
    JOIN public.content c ON c.id = e.content_id
    WHERE e.id = exam_versions.exam_id
      AND c.status = 'published'
      AND c.tenant_id = my_tenant_id()
      AND (
        c.group_id IS NULL
        OR EXISTS (
          SELECT 1 FROM public.group_members gm
          WHERE gm.student_id = auth.uid()
            AND gm.group_id = c.group_id
            AND gm.status = 'active'
            AND (
              c.published_at IS NULL
              OR gm.joined_at <= c.published_at
              OR (SELECT g.previous_content_access FROM public.groups g WHERE g.id = c.group_id) = 'allow'
            )
        )
        OR EXISTS (
          SELECT 1 FROM public.content_groups cg
          JOIN public.group_members gm ON gm.group_id = cg.group_id
          WHERE (cg.content_id = c.id OR cg.associated_exam_id = e.id)
            AND gm.student_id = auth.uid()
            AND gm.status = 'active'
            AND (
              c.published_at IS NULL
              OR gm.joined_at <= c.published_at
              OR (SELECT g.previous_content_access FROM public.groups g WHERE g.id = cg.group_id) = 'allow'
            )
        )
      )
  )
);

-- 4. Question options table policy
DROP POLICY IF EXISTS qo_student_read_published ON public.question_options;
CREATE POLICY qo_student_read_published ON public.question_options
FOR SELECT TO authenticated
USING (
  has_role('student')
  AND tenant_is_active()
  AND EXISTS (
    SELECT 1
    FROM public.exam_questions q
    JOIN public.exam_versions v ON v.id = q.exam_version_id
    JOIN public.exams e ON e.id = v.exam_id
    JOIN public.content c ON c.id = e.content_id
    WHERE q.id = question_options.question_id
      AND v.status = 'published'
      AND c.status = 'published'
      AND c.tenant_id = my_tenant_id()
      AND (
        c.group_id IS NULL
        OR EXISTS (
          SELECT 1 FROM public.group_members gm
          WHERE gm.student_id = auth.uid()
            AND gm.group_id = c.group_id
            AND gm.status = 'active'
            AND (
              c.published_at IS NULL
              OR gm.joined_at <= c.published_at
              OR (SELECT g.previous_content_access FROM public.groups g WHERE g.id = c.group_id) = 'allow'
            )
        )
        OR EXISTS (
          SELECT 1 FROM public.content_groups cg
          JOIN public.group_members gm ON gm.group_id = cg.group_id
          WHERE (cg.content_id = c.id OR cg.associated_exam_id = e.id)
            AND gm.student_id = auth.uid()
            AND gm.status = 'active'
            AND (
              c.published_at IS NULL
              OR gm.joined_at <= c.published_at
              OR (SELECT g.previous_content_access FROM public.groups g WHERE g.id = cg.group_id) = 'allow'
            )
        )
      )
  )
);
