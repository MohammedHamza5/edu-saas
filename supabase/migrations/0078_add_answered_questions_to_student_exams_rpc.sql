-- Migration: 0078_add_answered_questions_to_student_exams_rpc.sql
-- Description: Adds answered_questions_count to student attempts in get_student_exams RPC for student progress display.

CREATE OR REPLACE FUNCTION public.get_student_exams(
    p_page int DEFAULT 0,
    p_page_size int DEFAULT 15
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id uuid;
    v_tenant_id uuid;
    v_user_role text;
    v_result jsonb;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: authentication required';
    END IF;

    -- 1. Derive real user role and tenant strictly from database truth
    SELECT role, tenant_id INTO v_user_role, v_tenant_id
    FROM public.users
    WHERE id = v_user_id;

    IF v_tenant_id IS NULL OR (v_user_role != 'student' AND v_user_role != 'teacher') THEN
        RAISE EXCEPTION 'Unauthorized: user is not a student in an active tenant';
    END IF;

    -- 2. Fast single-pass execution with zero RLS recursion
    WITH student_groups AS (
        SELECT 
            gm.group_id,
            gm.joined_at,
            g.previous_content_access,
            g.name AS group_name
        FROM public.group_members gm
        JOIN public.groups g ON g.id = gm.group_id
        WHERE gm.student_id = v_user_id
          AND gm.status = 'active'
          AND g.tenant_id = v_tenant_id
    ),
    accessible_exams AS (
        -- Group-assigned exams
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
            c.title AS exam_title,
            c.group_id AS content_group_id,
            c.description AS content_description,
            c.status AS content_status,
            sg.group_name
        FROM public.exams e
        JOIN public.content c ON c.id = e.content_id
        JOIN student_groups sg ON sg.group_id = c.group_id
        WHERE e.tenant_id = v_tenant_id
          AND c.status = 'published'
          AND (
            c.published_at IS NULL 
            OR sg.joined_at <= c.published_at 
            OR sg.previous_content_access = 'allow'
          )
        UNION
        -- Lecture-associated exams (via content_groups)
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
            c.title AS exam_title,
            cg.group_id AS content_group_id,
            c.description AS content_description,
            c.status AS content_status,
            sg.group_name
        FROM public.exams e
        JOIN public.content c ON c.id = e.content_id
        JOIN public.content_groups cg ON cg.associated_exam_id = e.id
        JOIN student_groups sg ON sg.group_id = cg.group_id
        WHERE e.tenant_id = v_tenant_id
          AND c.status = 'published'
          AND (
            c.published_at IS NULL 
            OR sg.joined_at <= c.published_at 
            OR sg.previous_content_access = 'allow'
          )
        UNION
        -- Lecture-associated exams (via lesson_exams)
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
            c.title AS exam_title,
            le.group_id AS content_group_id,
            c.description AS content_description,
            c.status AS content_status,
            sg.group_name
        FROM public.exams e
        JOIN public.content c ON c.id = e.content_id
        JOIN public.lesson_exams le ON le.exam_id = e.id
        JOIN student_groups sg ON sg.group_id = le.group_id
        WHERE e.tenant_id = v_tenant_id
          AND c.status = 'published'
          AND (
            c.published_at IS NULL 
            OR sg.joined_at <= c.published_at 
            OR sg.previous_content_access = 'allow'
          )
        UNION
        -- General published exams (no specific group attached)
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
            c.title AS exam_title,
            NULL::uuid AS content_group_id,
            c.description AS content_description,
            c.status AS content_status,
            NULL::text AS group_name
        FROM public.exams e
        JOIN public.content c ON c.id = e.content_id
        WHERE e.tenant_id = v_tenant_id
          AND c.group_id IS NULL
          AND c.status = 'published'
    ),
    paged_exams AS (
        SELECT *
        FROM accessible_exams
        ORDER BY created_at DESC
        LIMIT p_page_size OFFSET (p_page * p_page_size)
    ),
    student_attempts AS (
        SELECT 
            ea.exam_id,
            jsonb_agg(
                jsonb_build_object(
                    'id', ea.id,
                    'exam_id', ea.exam_id,
                    'exam_version_id', ea.exam_version_id,
                    'student_id', ea.student_id,
                    'started_at', ea.started_at,
                    'submitted_at', ea.submitted_at,
                    'status', ea.status,
                    'score', ea.score,
                    'percentage', ea.percentage,
                    'answered_questions_count', (
                        SELECT count(*)::int
                        FROM public.exam_answers ans
                        WHERE ans.attempt_id = ea.id
                          AND ans.selected_option_id IS NOT NULL
                    )
                ) ORDER BY ea.started_at DESC
            ) AS attempts_json,
            count(*)::int AS attempts_count,
            max(ea.score) AS best_score
        FROM public.exam_attempts ea
        WHERE ea.student_id = v_user_id
          AND ea.exam_id IN (SELECT id FROM paged_exams)
        GROUP BY ea.exam_id
    ),
    versions_agg AS (
        SELECT 
            ev.exam_id,
            jsonb_agg(
                jsonb_build_object(
                    'id', ev.id,
                    'exam_id', ev.exam_id,
                    'version_number', ev.version_number,
                    'status', ev.status,
                    'created_at', ev.created_at,
                    'published_at', ev.published_at,
                    'exam_questions', jsonb_build_array(
                        jsonb_build_object('count', (
                            SELECT count(*)::int
                            FROM public.exam_questions eq
                            WHERE eq.exam_version_id = ev.id
                        ))
                    )
                ) ORDER BY ev.version_number DESC
            ) AS versions_json
        FROM public.exam_versions ev
        WHERE ev.exam_id IN (SELECT id FROM paged_exams)
          AND ev.status = 'published'
        GROUP BY ev.exam_id
    )
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', pe.id,
                'content_id', pe.content_id,
                'tenant_id', pe.tenant_id,
                'duration_minutes', pe.duration_minutes,
                'max_score', pe.max_score,
                'passing_score', pe.passing_score,
                'shuffle_questions', pe.shuffle_questions,
                'show_result', pe.show_result,
                'allow_retake', pe.allow_retake,
                'start_at', pe.start_at,
                'end_at', pe.end_at,
                'created_at', pe.created_at,
                'updated_at', pe.updated_at,
                'title', pe.exam_title,
                'folder_id', pe.folder_id,
                'group_id', pe.content_group_id,
                'group_name', pe.group_name,
                'folder', (
                    SELECT jsonb_build_object('id', ef.id, 'name', ef.name, 'color', ef.color, 'icon', ef.icon)
                    FROM public.exam_folders ef
                    WHERE ef.id = pe.folder_id
                ),
                'content', jsonb_build_object(
                    'id', pe.content_id,
                    'group_id', pe.content_group_id,
                    'title', pe.exam_title,
                    'description', pe.content_description,
                    'status', pe.content_status,
                    'groups', CASE WHEN pe.group_name IS NOT NULL THEN jsonb_build_object('name', pe.group_name) ELSE NULL END
                ),
                'exam_versions', COALESCE(va.versions_json, '[]'::jsonb),
                'exam_attempts', COALESCE(sa.attempts_json, '[]'::jsonb),
                'attempts_count', COALESCE(sa.attempts_count, 0),
                'my_best_score', sa.best_score,
                'is_lecture_exam', (
                    EXISTS (
                        SELECT 1 FROM public.content_groups cg
                        WHERE cg.associated_exam_id = pe.id
                    ) OR EXISTS (
                        SELECT 1 FROM public.lesson_exams le
                        WHERE le.exam_id = pe.id
                    )
                ),
                'linked_lesson_id', COALESCE(
                    (SELECT cg.content_id::text FROM public.content_groups cg WHERE cg.associated_exam_id = pe.id LIMIT 1),
                    (SELECT le.content_id::text FROM public.lesson_exams le WHERE le.exam_id = pe.id LIMIT 1)
                ),
                'linked_lesson_title', COALESCE(
                    (SELECT c_linked.title FROM public.content_groups cg JOIN public.content c_linked ON c_linked.id = cg.content_id WHERE cg.associated_exam_id = pe.id LIMIT 1),
                    (SELECT c_linked.title FROM public.lesson_exams le JOIN public.content c_linked ON c_linked.id = le.content_id WHERE le.exam_id = pe.id LIMIT 1)
                )
            ) ORDER BY pe.created_at DESC
        ),
        '[]'::jsonb
    ) INTO v_result
    FROM paged_exams pe
    LEFT JOIN student_attempts sa ON sa.exam_id = pe.id
    LEFT JOIN versions_agg va ON va.exam_id = pe.id;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_student_exams(int, int) TO authenticated;
