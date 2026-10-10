-- 0063_exam_parent_dispatch_roster_rpc.sql
-- High-performance, atomic RPC for teacher exam results & parent WhatsApp dispatch hub

CREATE OR REPLACE FUNCTION public.get_exam_parent_dispatch_roster(
  p_exam_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_teacher_id UUID := auth.uid();
  v_tenant_id UUID;
  v_role TEXT;
  v_result JSONB;
BEGIN
  -- 1. Security Check: caller must be authenticated teacher
  SELECT role, tenant_id INTO v_role, v_tenant_id
  FROM public.users
  WHERE id = v_teacher_id;

  IF v_role != 'teacher' OR v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: Only teachers can access the exam parent dispatch roster.';
  END IF;

  -- 2. Build JSON Roster
  WITH exam_data AS (
    SELECT 
      e.id,
      e.title,
      e.content_id,
      e.tenant_id,
      e.max_score,
      e.passing_score,
      e.duration_minutes,
      e.created_at,
      c.status AS content_status
    FROM public.exams e
    LEFT JOIN public.content c ON c.id = e.content_id
    WHERE e.id = p_exam_id AND e.tenant_id = v_tenant_id
  ),
  exam_groups AS (
    SELECT DISTINCT g.id AS group_id, g.name AS group_name
    FROM public.content_groups cg
    JOIN public.groups g ON g.id = cg.group_id
    WHERE cg.content_id = (SELECT content_id FROM exam_data)
       OR cg.associated_exam_id = p_exam_id
  ),
  enrolled_students AS (
    SELECT DISTINCT u.id AS student_id,
      COALESCE(
        (SELECT g.name 
         FROM public.group_members gm 
         JOIN public.groups g ON g.id = gm.group_id 
         JOIN exam_groups eg ON eg.group_id = g.id
         WHERE gm.student_id = u.id AND gm.status = 'active' 
         LIMIT 1),
        (SELECT g.name 
         FROM public.group_members gm 
         JOIN public.groups g ON g.id = gm.group_id 
         WHERE gm.student_id = u.id AND gm.status = 'active' 
         LIMIT 1),
        'عام'
      ) AS group_name
    FROM public.users u
    WHERE u.tenant_id = v_tenant_id
      AND u.role = 'student'
      AND (
        u.id IN (
          SELECT gm.student_id 
          FROM public.group_members gm 
          JOIN exam_groups eg ON eg.group_id = gm.group_id 
          WHERE gm.status = 'active'
        )
        OR u.id IN (
          SELECT ea.student_id 
          FROM public.exam_attempts ea 
          WHERE ea.exam_id = p_exam_id
        )
      )
  ),
  student_attempts AS (
    SELECT 
      es.student_id,
      es.group_name,
      u.full_name,
      u.phone,
      u.parent_phone,
      u.avatar_url,
      COUNT(ea.id) AS attempts_count,
      MAX(ea.score) AS best_score,
      MAX(ea.percentage) AS best_percentage,
      CASE 
        WHEN COUNT(ea.id) FILTER (WHERE ea.status = 'submitted') > 0 THEN 'submitted'
        WHEN COUNT(ea.id) FILTER (WHERE ea.status = 'in_progress') > 0 THEN 'in_progress'
        ELSE 'not_started'
      END AS status,
      MAX(ea.submitted_at) AS latest_submitted_at,
      -- Get latest attempt id
      (
        SELECT ea2.id 
        FROM public.exam_attempts ea2 
        WHERE ea2.exam_id = p_exam_id AND ea2.student_id = es.student_id 
        ORDER BY ea2.submitted_at DESC NULLS LAST, ea2.started_at DESC 
        LIMIT 1
      ) AS latest_attempt_id
    FROM enrolled_students es
    JOIN public.users u ON u.id = es.student_id
    LEFT JOIN public.exam_attempts ea ON ea.exam_id = p_exam_id AND ea.student_id = es.student_id
    GROUP BY es.student_id, es.group_name, u.full_name, u.phone, u.parent_phone, u.avatar_url
  ),
  students_json AS (
    SELECT 
      COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'student_id', sa.student_id,
            'student_name', sa.full_name,
            'student_phone', sa.phone,
            'parent_phone', sa.parent_phone,
            'avatar_url', sa.avatar_url,
            'group_name', sa.group_name,
            'status', sa.status,
            'attempts_count', sa.attempts_count,
            'best_score', sa.best_score,
            'best_percentage', ROUND(sa.best_percentage::numeric, 1),
            'latest_submitted_at', sa.latest_submitted_at,
            'latest_attempt_id', sa.latest_attempt_id,
            'is_passed', CASE 
              WHEN sa.best_score IS NOT NULL AND (SELECT passing_score FROM exam_data) IS NOT NULL 
                THEN sa.best_score >= (SELECT passing_score FROM exam_data)
              WHEN sa.best_score IS NOT NULL 
                THEN true
              ELSE false
            END
          )
          ORDER BY sa.best_score DESC NULLS LAST, sa.full_name ASC
        ),
        '[]'::jsonb
      ) AS list
    FROM student_attempts sa
  ),
  stats_json AS (
    SELECT jsonb_build_object(
      'total_assigned_students', COUNT(*),
      'submitted_count', COUNT(*) FILTER (WHERE sa.status = 'submitted'),
      'in_progress_count', COUNT(*) FILTER (WHERE sa.status = 'in_progress'),
      'not_started_count', COUNT(*) FILTER (WHERE sa.status = 'not_started'),
      'passed_count', COUNT(*) FILTER (
        WHERE sa.status = 'submitted' 
          AND (
            (SELECT passing_score FROM exam_data) IS NULL 
            OR sa.best_score >= (SELECT passing_score FROM exam_data)
          )
      ),
      'failed_count', COUNT(*) FILTER (
        WHERE sa.status = 'submitted' 
          AND (SELECT passing_score FROM exam_data) IS NOT NULL 
          AND sa.best_score < (SELECT passing_score FROM exam_data)
      ),
      'average_score', ROUND(COALESCE(AVG(sa.best_score) FILTER (WHERE sa.status = 'submitted'), 0)::numeric, 1),
      'average_percentage', ROUND(COALESCE(AVG(sa.best_percentage) FILTER (WHERE sa.status = 'submitted'), 0)::numeric, 1),
      'highest_score', COALESCE(MAX(sa.best_score) FILTER (WHERE sa.status = 'submitted'), 0),
      'lowest_score', COALESCE(MIN(sa.best_score) FILTER (WHERE sa.status = 'submitted'), 0)
    ) AS stats
    FROM student_attempts sa
  )
  SELECT jsonb_build_object(
    'exam', jsonb_build_object(
      'id', ed.id,
      'title', ed.title,
      'max_score', ed.max_score,
      'passing_score', ed.passing_score,
      'duration_minutes', ed.duration_minutes,
      'created_at', ed.created_at,
      'primary_group_name', (SELECT string_agg(group_name, ', ') FROM exam_groups)
    ),
    'stats', (SELECT stats FROM stats_json),
    'students', (SELECT list FROM students_json)
  )
  INTO v_result
  FROM exam_data ed;

  IF v_result IS NULL THEN
    RAISE EXCEPTION 'Exam not found or inaccessible for tenant';
  END IF;

  RETURN v_result;
END;
$$;

-- Function for teachers to quickly update a student's parent phone
CREATE OR REPLACE FUNCTION public.update_student_parent_phone(
  p_student_id UUID,
  p_parent_phone TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_teacher_id UUID := auth.uid();
  v_tenant_id UUID;
  v_role TEXT;
  v_clean_phone TEXT;
BEGIN
  -- 1. Security Check
  SELECT role, tenant_id INTO v_role, v_tenant_id
  FROM public.users
  WHERE id = v_teacher_id;

  IF v_role != 'teacher' OR v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: Only teachers can update student parent phone.';
  END IF;

  v_clean_phone := NULLIF(TRIM(p_parent_phone), '');

  -- 2. Update student in same tenant
  UPDATE public.users
  SET 
    parent_phone = v_clean_phone,
    updated_at = NOW()
  WHERE id = p_student_id 
    AND tenant_id = v_tenant_id 
    AND role = 'student';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Student not found in your tenant.';
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'student_id', p_student_id,
    'parent_phone', v_clean_phone
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_exam_parent_dispatch_roster(UUID) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.get_exam_parent_dispatch_roster(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.update_student_parent_phone(UUID, TEXT) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.update_student_parent_phone(UUID, TEXT) TO authenticated;
