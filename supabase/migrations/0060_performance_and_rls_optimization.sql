-- ============================================================================
-- 0060_performance_and_rls_optimization.sql
-- Enterprise Performance Tuning:
-- 1. High-Performance SQL inlinable helper functions for RLS (Language SQL + InitPlan).
-- 2. Targeted B-Tree & composite indexes on high-frequency join/filter paths.
-- 3. Elimination of Seq Scans on exams, content, attempts, and group members.
-- ============================================================================

-- ── 1. Fast Inlinable RLS Helper Functions ───────────────────────────────────
-- Replacing PL/pgSQL with LANGUAGE sql STABLE allows the Postgres query planner
-- to inline execution, avoiding context switching overhead and caching (select auth.uid()).

CREATE OR REPLACE FUNCTION public.my_tenant_id()
RETURNS uuid 
LANGUAGE sql 
STABLE 
SECURITY DEFINER 
SET search_path = public AS $$
  SELECT u.tenant_id 
  FROM public.users u 
  WHERE u.id = (SELECT auth.uid());
$$;

CREATE OR REPLACE FUNCTION public.has_role(r text)
RETURNS boolean 
LANGUAGE sql 
STABLE 
SECURITY DEFINER 
SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM public.users u
    WHERE u.id = (SELECT auth.uid()) 
      AND u.role = r 
      AND u.status = 'active'
  );
$$;

CREATE OR REPLACE FUNCTION public.tenant_is_active()
RETURNS boolean 
LANGUAGE sql 
STABLE 
SECURITY DEFINER 
SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM public.users u
    JOIN public.tenants t ON t.id = u.tenant_id
    WHERE u.id = (SELECT auth.uid()) 
      AND t.status = 'active'
  );
$$;

CREATE OR REPLACE FUNCTION public.user_belongs_to_my_tenant(p_user_id uuid)
RETURNS boolean 
LANGUAGE sql 
STABLE 
SECURITY DEFINER 
SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM public.users target
    WHERE target.id = p_user_id 
      AND target.tenant_id = (SELECT u.tenant_id FROM public.users u WHERE u.id = (SELECT auth.uid()))
  );
$$;

-- ── 2. Performance Indexes on Foreign Keys & Frequent Filters ────────────────

-- Exams & Content joins and filters
CREATE INDEX IF NOT EXISTS idx_exams_content_id 
  ON public.exams(content_id);

CREATE INDEX IF NOT EXISTS idx_exams_created_desc 
  ON public.exams(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_content_group_status 
  ON public.content(group_id, status);

CREATE INDEX IF NOT EXISTS idx_content_tenant_status 
  ON public.content(tenant_id, status);

-- Attempts & Student history
CREATE INDEX IF NOT EXISTS idx_exam_attempts_student_exam 
  ON public.exam_attempts(student_id, exam_id, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_exam_attempts_exam_started 
  ON public.exam_attempts(exam_id, started_at DESC);

-- Group memberships (frequently filtered by student_id and active status)
CREATE INDEX IF NOT EXISTS idx_group_members_student_active 
  ON public.group_members(student_id, status);

CREATE INDEX IF NOT EXISTS idx_group_members_group_student 
  ON public.group_members(group_id, student_id);

-- Exam versions and questions hierarchy
CREATE INDEX IF NOT EXISTS idx_exam_questions_version_sort 
  ON public.exam_questions(exam_version_id, sort_order);

CREATE INDEX IF NOT EXISTS idx_question_options_q_sort 
  ON public.question_options(question_id, sort_order);

-- Content groups linking
CREATE INDEX IF NOT EXISTS idx_content_groups_associated_exam 
  ON public.content_groups(associated_exam_id) 
  WHERE associated_exam_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_content_groups_group_assoc 
  ON public.content_groups(group_id, associated_exam_id);

-- User table fast index for RLS lookups
CREATE INDEX IF NOT EXISTS idx_users_id_role_status 
  ON public.users(id, role, status, tenant_id);
