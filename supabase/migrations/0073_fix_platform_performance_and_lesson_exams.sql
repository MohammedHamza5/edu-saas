-- ==============================================================================
-- Migration 0073: Fix Platform Performance, PL/pgSQL 55000, and lesson_exams table
-- ==============================================================================

-- 1. Fix public.notifications RLS policy WITH CHECK to allow teacher broadcasts
DROP POLICY IF EXISTS notif_teacher_all ON public.notifications;
CREATE POLICY notif_teacher_all ON public.notifications
    FOR ALL
    USING (has_role('teacher') AND tenant_is_active() AND tenant_id = my_tenant_id())
    WITH CHECK (has_role('teacher') AND tenant_is_active() AND tenant_id = my_tenant_id());

-- 2. Drop duplicate index on public.exam_versions (idx_exam_versions_tenant duplicate of idx_exam_versions_exam)
DROP INDEX IF EXISTS public.idx_exam_versions_tenant;

-- 3. Ensure public.lesson_exams table exists for multi-exam lesson attachment
CREATE TABLE IF NOT EXISTS public.lesson_exams (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    content_id uuid NOT NULL REFERENCES public.content(id) ON DELETE CASCADE,
    exam_id uuid NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    group_id uuid NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_lesson_exams_content_exam_group UNIQUE (content_id, exam_id, group_id)
);

CREATE INDEX IF NOT EXISTS idx_lesson_exams_lookup ON public.lesson_exams(content_id, group_id);
CREATE INDEX IF NOT EXISTS idx_lesson_exams_exam ON public.lesson_exams(exam_id);
CREATE INDEX IF NOT EXISTS idx_lesson_exams_tenant ON public.lesson_exams(tenant_id);

ALTER TABLE public.lesson_exams ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS lesson_exams_teacher ON public.lesson_exams;
CREATE POLICY lesson_exams_teacher ON public.lesson_exams
    FOR ALL
    USING (has_role('teacher') AND tenant_is_active() AND tenant_id = my_tenant_id())
    WITH CHECK (has_role('teacher') AND tenant_is_active() AND tenant_id = my_tenant_id());

DROP POLICY IF EXISTS lesson_exams_student ON public.lesson_exams;
CREATE POLICY lesson_exams_student ON public.lesson_exams
    FOR SELECT
    USING (
        has_role('student')
        AND tenant_is_active()
        AND tenant_id = my_tenant_id()
        AND EXISTS (
            SELECT 1 FROM public.group_members gm
            WHERE gm.group_id = lesson_exams.group_id
              AND gm.student_id = auth.uid()
              AND gm.status = 'active'
        )
    );

DROP POLICY IF EXISTS lesson_exams_parent ON public.lesson_exams;
CREATE POLICY lesson_exams_parent ON public.lesson_exams
    FOR SELECT
    USING (
        has_role('parent')
        AND tenant_is_active()
        AND tenant_id = my_tenant_id()
        AND EXISTS (
            SELECT 1 FROM public.parent_students ps
            JOIN public.group_members gm ON gm.student_id = ps.student_id
            WHERE ps.parent_id = auth.uid()
              AND gm.group_id = lesson_exams.group_id
              AND gm.status = 'active'
        )
    );

GRANT SELECT, INSERT, UPDATE, DELETE ON public.lesson_exams TO authenticated;

-- Backfill lesson_exams from content_groups if any are missing
INSERT INTO public.lesson_exams (content_id, exam_id, group_id, tenant_id, sort_order)
SELECT cg.content_id, cg.associated_exam_id, cg.group_id, cg.tenant_id, 0
FROM public.content_groups cg
WHERE cg.associated_exam_id IS NOT NULL
ON CONFLICT (content_id, exam_id, group_id) DO NOTHING;

-- 4. Fix get_lesson_context (PL/pgSQL Error 55000: record is not assigned yet)
CREATE OR REPLACE FUNCTION public.get_lesson_context(
    p_content_id uuid,
    p_group_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_cg record;
    v_user_role text;
    v_tenant_id uuid;
    v_exam_id uuid := NULL;
    v_exam_title text := NULL;
    v_pdf_path text := NULL;
    v_pdf_name text := NULL;
    v_passing_score integer := 0;
    v_attached_exams jsonb := '[]'::jsonb;
    v_result jsonb;
BEGIN
    SELECT role, tenant_id INTO v_user_role, v_tenant_id
    FROM public.users
    WHERE id = auth.uid();

    IF v_tenant_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    SELECT 
        cg.associated_exam_id,
        cg.prerequisite_exam_id,
        cg.passing_score,
        cg.pdf_storage_path,
        cg.pdf_file_name
    INTO v_cg
    FROM public.content_groups cg
    WHERE cg.content_id = p_content_id
      AND cg.group_id = p_group_id
      AND cg.tenant_id = v_tenant_id;

    IF v_cg.associated_exam_id IS NOT NULL THEN
        v_exam_id := v_cg.associated_exam_id;
        SELECT c.title INTO v_exam_title
        FROM public.exams e
        JOIN public.content c ON c.id = e.content_id
        WHERE e.id = v_exam_id;
    END IF;

    SELECT 
        COALESCE(v_cg.pdf_storage_path, f.storage_path),
        COALESCE(v_cg.pdf_file_name, f.file_name)
    INTO v_pdf_path, v_pdf_name
    FROM public.files f
    WHERE f.content_id = p_content_id
      AND f.file_type = 'pdf'
    LIMIT 1;

    IF v_pdf_path IS NULL AND v_cg.pdf_storage_path IS NOT NULL THEN
        v_pdf_path := v_cg.pdf_storage_path;
        v_pdf_name := v_cg.pdf_file_name;
    END IF;

    v_passing_score := COALESCE(v_cg.passing_score, 0);

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'exam_id', le.exam_id,
                'exam_title', c.title,
                'sort_order', le.sort_order,
                'passing_score', COALESCE(e.passing_score, 0),
                'max_score', COALESCE(e.max_score, 0),
                'duration_minutes', COALESCE(e.duration_minutes, 0)
            ) ORDER BY le.sort_order ASC, le.created_at ASC
        ),
        '[]'::jsonb
    ) INTO v_attached_exams
    FROM public.lesson_exams le
    JOIN public.exams e ON e.id = le.exam_id
    JOIN public.content c ON c.id = e.content_id
    WHERE le.content_id = p_content_id
      AND le.group_id = p_group_id
      AND le.tenant_id = v_tenant_id;

    v_result := jsonb_build_object(
        'pdf_storage_path', v_pdf_path,
        'pdf_file_name', v_pdf_name,
        'passing_score', v_passing_score,
        'lesson_exam_id', v_exam_id,
        'lesson_exam_title', v_exam_title,
        'prerequisite_exam_id', v_cg.prerequisite_exam_id,
        'attached_exams', v_attached_exams
    );

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_lesson_context(uuid, uuid) TO authenticated;
