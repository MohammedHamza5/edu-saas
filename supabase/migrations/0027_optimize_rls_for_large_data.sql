-- ============================================================================
-- 0027_optimize_rls_for_large_data.sql
-- Optimizes RLS policies to prevent statement timeouts on large datasets by
-- replacing correlated EXISTS subqueries with scalar subqueries and adding
-- missing tenant_id indexes.
-- ============================================================================

-- 1. Add missing index on exams table
CREATE INDEX IF NOT EXISTS idx_exams_tenant ON public.exams(tenant_id);
CREATE INDEX IF NOT EXISTS idx_exam_versions_tenant ON public.exam_versions(exam_id);
CREATE INDEX IF NOT EXISTS idx_exam_questions_question ON public.question_options(question_id);

-- 2. Optimize exam_versions RLS
DROP POLICY IF EXISTS ev_teacher_all ON public.exam_versions;
CREATE POLICY ev_teacher_all ON public.exam_versions FOR ALL TO authenticated
  USING (
    public.has_role('teacher') AND public.tenant_is_active() AND 
    (SELECT tenant_id FROM public.exams e WHERE e.id = exam_versions.exam_id) = public.my_tenant_id()
  );

-- 3. Optimize exam_questions RLS
DROP POLICY IF EXISTS eq_teacher_all ON public.exam_questions;
CREATE POLICY eq_teacher_all ON public.exam_questions FOR ALL TO authenticated
  USING (
    public.has_role('teacher') AND public.tenant_is_active() AND 
    (
      SELECT e.tenant_id 
      FROM public.exam_versions v 
      JOIN public.exams e ON e.id = v.exam_id 
      WHERE v.id = exam_questions.exam_version_id
    ) = public.my_tenant_id()
  );

-- 4. Optimize question_options RLS
DROP POLICY IF EXISTS qo_teacher_all ON public.question_options;
CREATE POLICY qo_teacher_all ON public.question_options FOR ALL TO authenticated
  USING (
    public.has_role('teacher') AND public.tenant_is_active() AND 
    (
      SELECT e.tenant_id 
      FROM public.exam_questions q 
      JOIN public.exam_versions v ON v.id = q.exam_version_id
      JOIN public.exams e ON e.id = v.exam_id 
      WHERE q.id = question_options.question_id
    ) = public.my_tenant_id()
  );

