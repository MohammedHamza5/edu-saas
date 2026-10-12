-- ==============================================================================
-- Migration 0076: Link Content Groups To Academic Chapters & Optimize Teacher Policies
-- ==============================================================================

-- 1. Optimize teacher policies with InitPlan (SELECT ...) to prevent statement timeouts
DROP POLICY IF EXISTS eq_teacher_all ON public.exam_questions;
CREATE POLICY eq_teacher_all ON public.exam_questions
    FOR ALL
    USING (
        (SELECT has_role('teacher'))
        AND (SELECT tenant_is_active())
        AND get_exam_version_tenant_id(exam_version_id) = (SELECT my_tenant_id())
    )
    WITH CHECK (
        (SELECT has_role('teacher'))
        AND (SELECT tenant_is_active())
        AND get_exam_version_tenant_id(exam_version_id) = (SELECT my_tenant_id())
    );

DROP POLICY IF EXISTS content_teacher_all ON public.content;
CREATE POLICY content_teacher_all ON public.content
    FOR ALL
    USING (
        (SELECT has_role('teacher'))
        AND (SELECT tenant_is_active())
        AND tenant_id = (SELECT my_tenant_id())
    )
    WITH CHECK (
        (SELECT has_role('teacher'))
        AND (SELECT tenant_is_active())
        AND tenant_id = (SELECT my_tenant_id())
    );

DROP POLICY IF EXISTS content_groups_teacher_all ON public.content_groups;
CREATE POLICY content_groups_teacher_all ON public.content_groups
    FOR ALL
    USING (
        (SELECT has_role('teacher'))
        AND (SELECT tenant_is_active())
        AND tenant_id = (SELECT my_tenant_id())
    )
    WITH CHECK (
        (SELECT has_role('teacher'))
        AND (SELECT tenant_is_active())
        AND tenant_id = (SELECT my_tenant_id())
    );

DROP POLICY IF EXISTS exams_teacher_all ON public.exams;
CREATE POLICY exams_teacher_all ON public.exams
    FOR ALL
    USING (
        (SELECT has_role('teacher'))
        AND (SELECT tenant_is_active())
        AND tenant_id = (SELECT my_tenant_id())
    )
    WITH CHECK (
        (SELECT has_role('teacher'))
        AND (SELECT tenant_is_active())
        AND tenant_id = (SELECT my_tenant_id())
    );

DROP POLICY IF EXISTS teacher_manage_lesson_exams ON public.lesson_exams;
CREATE POLICY teacher_manage_lesson_exams ON public.lesson_exams
    FOR ALL
    USING (
        (SELECT has_role('teacher'))
        AND (SELECT tenant_is_active())
        AND tenant_id = (SELECT my_tenant_id())
    )
    WITH CHECK (
        (SELECT has_role('teacher'))
        AND (SELECT tenant_is_active())
        AND tenant_id = (SELECT my_tenant_id())
    );

-- 2. Associate existing curriculum items to their designated academic chapters
UPDATE public.content_groups
SET chapter_id = '14b301cb-4966-4415-976b-042f9ec89c86'
WHERE group_id = '266d0e81-55e6-493e-98b6-76d6d3769bac'
  AND content_id = '2523fa53-0435-48f6-bf1e-712e34a501ae';

UPDATE public.content_groups
SET chapter_id = '12937e1d-6bde-4493-91aa-921af38bb848'
WHERE group_id = '266d0e81-55e6-493e-98b6-76d6d3769bac'
  AND content_id IN (
    'c809dad8-fa61-4bc8-8ed0-0575f660a498',
    '6a503e06-a700-4ab3-aeb0-6957b496430e',
    'b6905c22-4248-4f62-9fd5-340e908d0a02',
    '072a0da9-005e-4068-b29a-af6ed54a962e',
    '9ce08ebf-9363-48cd-a5f8-4485de310922',
    '87589294-f184-4e9a-83f3-02ff626c2ecb'
  );

UPDATE public.content_groups
SET chapter_id = 'df78c4f4-ab02-45db-bce7-04392cde8f3e'
WHERE group_id = '8a501a59-a187-430c-8eee-b879ee2c2310'
  AND content_id = '36f4eb4a-6ce6-42d2-a795-9415f7f6923d';
