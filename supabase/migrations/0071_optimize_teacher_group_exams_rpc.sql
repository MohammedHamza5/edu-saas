-- Migration: 0071_optimize_teacher_group_exams_rpc.sql
-- Description: High-performance single-pass RPC for teacher exams list to prevent statement timeout and recursive RLS planning.

CREATE OR REPLACE FUNCTION public.get_teacher_group_exams(
    p_group_id uuid,
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
    v_tenant_id uuid;
    v_user_role text;
    v_result jsonb;
BEGIN
    -- 1. Derive real user role and tenant strictly from database truth
    SELECT role, tenant_id INTO v_user_role, v_tenant_id
    FROM public.users
    WHERE id = auth.uid();

    IF v_user_role != 'teacher' OR v_tenant_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: only teachers can view teacher exams';
    END IF;

    -- 2. Fast single-pass execution with zero RLS recursion
    WITH matched_exams AS (
        SELECT e.*
        FROM public.exams e
        JOIN public.content c ON c.id = e.content_id
        WHERE c.group_id = p_group_id
          AND e.tenant_id = v_tenant_id
          AND c.status != 'archived'
        UNION
        SELECT e.*
        FROM public.exams e
        JOIN public.content_groups cg ON cg.associated_exam_id = e.id
        WHERE cg.group_id = p_group_id
          AND e.tenant_id = v_tenant_id
        ORDER BY created_at DESC
        LIMIT p_page_size OFFSET (p_page * p_page_size)
    ),
    exam_stats AS (
        SELECT 
            me.id AS exam_id,
            COALESCE(count(DISTINCT ea.id), 0) AS attempts_count
        FROM matched_exams me
        LEFT JOIN public.exam_attempts ea ON ea.exam_id = me.id
        GROUP BY me.id
    ),
    exam_versions_agg AS (
        SELECT 
            me.id AS exam_id,
            COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'id', ev.id,
                        'exam_id', ev.exam_id,
                        'version_number', ev.version_number,
                        'status', ev.status,
                        'created_at', ev.created_at,
                        'published_at', ev.published_at,
                        'exam_questions', (
                            SELECT jsonb_build_array(jsonb_build_object('count', count(*)))
                            FROM public.exam_questions eq
                            WHERE eq.exam_version_id = ev.id
                        )
                    ) ORDER BY ev.version_number DESC
                ) FILTER (WHERE ev.id IS NOT NULL),
                '[]'::jsonb
            ) AS versions_json
        FROM matched_exams me
        LEFT JOIN public.exam_versions ev ON ev.exam_id = me.id
        GROUP BY me.id
    )
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', me.id,
                'content_id', me.content_id,
                'tenant_id', me.tenant_id,
                'duration_minutes', me.duration_minutes,
                'max_score', me.max_score,
                'passing_score', me.passing_score,
                'shuffle_questions', me.shuffle_questions,
                'show_result', me.show_result,
                'allow_retake', me.allow_retake,
                'start_at', me.start_at,
                'end_at', me.end_at,
                'created_at', me.created_at,
                'updated_at', me.updated_at,
                'title', me.title,
                'folder_id', me.folder_id,
                'folder', (
                    SELECT jsonb_build_object('id', ef.id, 'name', ef.name, 'color', ef.color, 'icon', ef.icon)
                    FROM public.exam_folders ef
                    WHERE ef.id = me.folder_id
                ),
                'content', (
                    SELECT jsonb_build_object(
                        'id', c.id,
                        'group_id', c.group_id,
                        'title', c.title,
                        'description', c.description,
                        'status', c.status,
                        'groups', (SELECT jsonb_build_object('name', g.name) FROM public.groups g WHERE g.id = c.group_id)
                    )
                    FROM public.content c
                    WHERE c.id = me.content_id
                ),
                'exam_versions', COALESCE(eva.versions_json, '[]'::jsonb),
                'attempts_count', COALESCE(es.attempts_count, 0),
                'linked_lesson_id', (
                    SELECT cg.content_id::text
                    FROM public.content_groups cg
                    WHERE cg.associated_exam_id = me.id AND cg.group_id = p_group_id
                    LIMIT 1
                ),
                'linked_lesson_title', (
                    SELECT c_linked.title
                    FROM public.content_groups cg
                    JOIN public.content c_linked ON c_linked.id = cg.content_id
                    WHERE cg.associated_exam_id = me.id AND cg.group_id = p_group_id
                    LIMIT 1
                ),
                'is_lecture_exam', (
                    EXISTS (
                        SELECT 1 FROM public.content_groups cg
                        WHERE cg.associated_exam_id = me.id AND cg.group_id = p_group_id
                    )
                )
            ) ORDER BY me.created_at DESC
        ),
        '[]'::jsonb
    ) INTO v_result
    FROM matched_exams me
    LEFT JOIN exam_stats es ON es.exam_id = me.id
    LEFT JOIN exam_versions_agg eva ON eva.exam_id = me.id;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_teacher_group_exams(uuid, int, int) TO authenticated;
