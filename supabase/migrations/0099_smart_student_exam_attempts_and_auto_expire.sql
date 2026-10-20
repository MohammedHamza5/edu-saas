-- ==============================================================================
-- Migration: 0099_smart_student_exam_attempts_and_auto_expire.sql
-- Description:
--   1. Auto-expires timed-out in_progress attempts on student exams query.
--   2. In student_latest_attempt, prioritizes active in_progress attempts (1),
--      then submitted attempts with scores (2), then expired attempts (3).
--   3. Calculates has_active_attempt with strict time-window validation.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.get_student_exams(
    p_page integer DEFAULT 0,
    p_page_size integer DEFAULT 20
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_role text;
    v_tenant_id uuid;
    v_result jsonb;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN '[]'::jsonb;
    END IF;

    SELECT role, tenant_id INTO v_role, v_tenant_id
    FROM public.users
    WHERE id = v_user_id;

    IF v_role != 'student' THEN
        RETURN '[]'::jsonb;
    END IF;

    -- 1. Auto-expire any stale in_progress attempts whose timer has expired (+5 min grace)
    UPDATE public.exam_attempts ea
    SET status = 'expired'
    FROM public.exams e
    WHERE ea.exam_id = e.id
      AND ea.student_id = v_user_id
      AND ea.status = 'in_progress'
      AND e.duration_minutes > 0
      AND (ea.started_at + (e.duration_minutes || ' minutes')::interval + interval '5 minutes') < now();

    WITH student_groups AS (
        SELECT group_id
        FROM public.group_members
        WHERE student_id = v_user_id
          AND status = 'active'
    ),
    accessible_exams AS (
        -- 1) Group-specific exams
        SELECT DISTINCT
            e.id,
            e.content_id,
            e.tenant_id,
            e.duration_minutes,
            e.max_score,
            e.passing_score,
            e.shuffle_questions,
            e.show_result,
            e.allow_retake,
            e.start_at,
            e.end_at,
            e.created_at,
            e.updated_at,
            e.folder_id,
            e.pdf_file_id,
            c.title AS exam_title,
            c.group_id AS content_group_id,
            c.description AS content_description,
            c.status AS content_status,
            g.name AS group_name
        FROM public.exams e
        JOIN public.content c ON c.id = e.content_id
        JOIN student_groups sg ON sg.group_id = c.group_id
        JOIN public.groups g ON g.id = c.group_id
        WHERE e.tenant_id = v_tenant_id
          AND c.status = 'published'
          AND NOT EXISTS (
            SELECT 1 FROM public.content_groups cg
            WHERE (cg.associated_exam_id = e.id OR cg.prerequisite_exam_id = e.id)
          )
          AND NOT EXISTS (
            SELECT 1 FROM public.lesson_exams le
            WHERE le.exam_id = e.id
          )
          AND NOT EXISTS (
            SELECT 1 FROM public.content c2
            WHERE (c2.associated_exam_id = e.id OR c2.prerequisite_exam_id = e.id)
          )
        UNION
        -- 2) Tenant-wide General exams (group_id IS NULL)
        SELECT DISTINCT
            e.id,
            e.content_id,
            e.tenant_id,
            e.duration_minutes,
            e.max_score,
            e.passing_score,
            e.shuffle_questions,
            e.show_result,
            e.allow_retake,
            e.start_at,
            e.end_at,
            e.created_at,
            e.updated_at,
            e.folder_id,
            e.pdf_file_id,
            c.title AS exam_title,
            c.group_id AS content_group_id,
            c.description AS content_description,
            c.status AS content_status,
            'All Groups' AS group_name
        FROM public.exams e
        JOIN public.content c ON c.id = e.content_id
        WHERE e.tenant_id = v_tenant_id
          AND c.group_id IS NULL
          AND c.status = 'published'
          AND EXISTS (SELECT 1 FROM student_groups)
          AND NOT EXISTS (
            SELECT 1 FROM public.content_groups cg
            WHERE (cg.associated_exam_id = e.id OR cg.prerequisite_exam_id = e.id)
          )
          AND NOT EXISTS (
            SELECT 1 FROM public.lesson_exams le
            WHERE le.exam_id = e.id
          )
          AND NOT EXISTS (
            SELECT 1 FROM public.content c2
            WHERE (c2.associated_exam_id = e.id OR c2.prerequisite_exam_id = e.id)
          )
    ),
    paged_exams AS (
        SELECT *
        FROM accessible_exams
        ORDER BY created_at DESC
        LIMIT p_page_size
        OFFSET (p_page * p_page_size)
    ),
    exam_stats AS (
        SELECT 
            pe.id AS exam_id,
            COALESCE((
                SELECT count(*)::int
                FROM public.exam_questions eq
                WHERE eq.exam_version_id = (
                    SELECT ev.id
                    FROM public.exam_versions ev
                    WHERE ev.exam_id = pe.id
                    ORDER BY ev.version_number DESC
                    LIMIT 1
                )
            ), 0) AS questions_count
        FROM paged_exams pe
    ),
    student_latest_attempt AS (
        SELECT DISTINCT ON (ea.exam_id)
            ea.exam_id,
            ea.id AS attempt_id,
            ea.exam_version_id,
            ea.status AS attempt_status,
            ea.score,
            ea.percentage,
            ea.started_at,
            ea.submitted_at,
            COALESCE((
                SELECT count(DISTINCT ea_ans.question_id)::int
                FROM public.exam_answers ea_ans
                WHERE ea_ans.attempt_id = ea.id
            ), 0) AS answered_questions_count
        FROM public.exam_attempts ea
        JOIN paged_exams pe ON pe.id = ea.exam_id
        WHERE ea.student_id = v_user_id
        ORDER BY ea.exam_id,
                 CASE 
                   WHEN ea.status = 'in_progress' AND (pe.duration_minutes <= 0 OR (ea.started_at + (pe.duration_minutes || ' minutes')::interval + interval '5 minutes') > now()) THEN 1
                   WHEN ea.status = 'submitted' THEN 2
                   ELSE 3
                 END,
                 ea.started_at DESC
    ),
    student_exam_aggregates AS (
        SELECT
            ea.exam_id,
            count(ea.id)::int AS attempts_count,
            max(ea.score) FILTER (WHERE ea.status = 'submitted') AS best_score,
            max(ea.percentage) FILTER (WHERE ea.status = 'submitted') AS best_percentage,
            bool_or(
                ea.status = 'in_progress' AND (
                    pe.duration_minutes <= 0 OR 
                    (ea.started_at + (pe.duration_minutes || ' minutes')::interval + interval '5 minutes') > now()
                )
            ) AS has_active_attempt
        FROM public.exam_attempts ea
        JOIN paged_exams pe ON pe.id = ea.exam_id
        WHERE ea.student_id = v_user_id
        GROUP BY ea.exam_id
    ),
    exam_pdf_data AS (
        SELECT
            pe.id AS exam_id,
            COALESCE(ml.file_name, ml.title, f.file_name) AS pdf_file_name,
            COALESCE(ml.file_size, f.file_size) AS pdf_file_size,
            COALESCE(ml.storage_path, f.storage_path) AS pdf_storage_path,
            COALESCE(ml.storage_provider, f.storage_provider, 'supabase') AS pdf_storage_provider
        FROM paged_exams pe
        LEFT JOIN public.material_library ml ON ml.id = pe.pdf_file_id
        LEFT JOIN public.files f ON f.id = pe.pdf_file_id AND ml.id IS NULL
    )
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', pe.id,
                'content_id', pe.content_id,
                'group_id', pe.content_group_id,
                'group_name', pe.group_name,
                'title', pe.exam_title,
                'description', pe.content_description,
                'status', pe.content_status,
                'duration_minutes', pe.duration_minutes,
                'max_score', pe.max_score,
                'passing_score', pe.passing_score,
                'shuffle_questions', pe.shuffle_questions,
                'show_result', pe.show_result,
                'allow_retake', pe.allow_retake,
                'start_at', pe.start_at,
                'end_at', pe.end_at,
                'folder_id', pe.folder_id,
                'created_at', pe.created_at,
                'updated_at', pe.updated_at,
                'pdf_file_id', pe.pdf_file_id,
                'pdf_file_name', epd.pdf_file_name,
                'pdf_file_size', epd.pdf_file_size,
                'pdf_storage_path', epd.pdf_storage_path,
                'pdf_storage_provider', epd.pdf_storage_provider,
                'questions_count', COALESCE(es.questions_count, 0),
                'attempts_count', COALESCE(sea.attempts_count, 0),
                'has_active_attempt', COALESCE(sea.has_active_attempt, false),
                'has_passed', CASE 
                    WHEN sea.best_score IS NOT NULL AND pe.passing_score IS NOT NULL AND sea.best_score >= pe.passing_score THEN true 
                    ELSE false 
                END,
                'my_best_score', sea.best_score,
                'best_score', sea.best_score,
                'student_score', COALESCE(sea.best_score, sla.score),
                'my_best_percentage', sea.best_percentage,
                'student_percentage', COALESCE(sea.best_percentage, sla.percentage),
                'latest_attempt_id', sla.attempt_id,
                'latest_attempt_status', sla.attempt_status,
                'answered_questions_count', COALESCE(sla.answered_questions_count, 0),
                'latest_attempt', CASE 
                    WHEN sla.attempt_id IS NOT NULL THEN jsonb_build_object(
                        'id', sla.attempt_id,
                        'exam_id', pe.id,
                        'exam_version_id', sla.exam_version_id,
                        'student_id', v_user_id,
                        'status', sla.attempt_status,
                        'score', sla.score,
                        'percentage', sla.percentage,
                        'started_at', sla.started_at,
                        'submitted_at', sla.submitted_at
                    )
                    ELSE null
                END,
                'my_latest_attempt', CASE 
                    WHEN sla.attempt_id IS NOT NULL THEN jsonb_build_object(
                        'id', sla.attempt_id,
                        'exam_id', pe.id,
                        'exam_version_id', sla.exam_version_id,
                        'student_id', v_user_id,
                        'status', sla.attempt_status,
                        'score', sla.score,
                        'percentage', sla.percentage,
                        'started_at', sla.started_at,
                        'submitted_at', sla.submitted_at
                    )
                    ELSE null
                END
            )
        ),
        '[]'::jsonb
    ) INTO v_result
    FROM paged_exams pe
    LEFT JOIN exam_stats es ON es.exam_id = pe.id
    LEFT JOIN student_latest_attempt sla ON sla.exam_id = pe.id
    LEFT JOIN student_exam_aggregates sea ON sea.exam_id = pe.id
    LEFT JOIN exam_pdf_data epd ON epd.exam_id = pe.id;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_student_exams(integer, integer) TO authenticated;
