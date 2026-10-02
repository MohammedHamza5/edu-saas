-- ============================================================================
-- 0028_student_dashboard_rpc.sql — Fast Student Dashboard RPC
-- Replaces 5-7 parallel HTTP round-trips with a single fast, indexed query.
-- Returns: core stats, urgent tasks (assignments + exams), and enrolled groups.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_student_dashboard(p_student_id UUID)
RETURNS JSON
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_result JSON;
  v_group_ids UUID[];
  v_primary_group_name TEXT := 'No Active Group';
  v_primary_group_level TEXT := 'N/A';
BEGIN
  -- 1. Get active group IDs for this student
  SELECT array_agg(group_id)
  INTO v_group_ids
  FROM public.group_members
  WHERE student_id = p_student_id AND status = 'active';

  -- 2. Get primary group info
  IF v_group_ids IS NOT NULL AND array_length(v_group_ids, 1) > 0 THEN
    SELECT g.name, g.level
    INTO v_primary_group_name, v_primary_group_level
    FROM public.groups g
    WHERE g.id = v_group_ids[1];
  END IF;

  SELECT json_build_object(
    -- 1. Enrolled groups
    'groups', (
      SELECT COALESCE(
        json_agg(
          json_build_object(
            'id', g.id,
            'name', g.name,
            'level', g.level,
            'description', COALESCE(g.description, ''),
            'previous_content_access', g.previous_content_access,
            'status', g.status,
            'created_at', g.created_at,
            'enforce_sequential_learning', COALESCE(g.enforce_sequential_learning, false),
            'default_passing_score', COALESCE(g.default_passing_score, 70),
            'members_count', (
              SELECT COUNT(*) FROM public.group_members WHERE group_id = g.id AND status = 'active'
            )
          ) ORDER BY g.created_at DESC
        ),
        '[]'::json
      )
      FROM public.groups g
      WHERE g.id = ANY(v_group_ids)
    ),

    -- 2. Core Metrics
    'active_group_name', v_primary_group_name,
    'active_group_level', v_primary_group_level,
    
    'attendance_percentage', (
      SELECT CASE 
        WHEN COUNT(*) > 0 THEN (COUNT(*) FILTER (WHERE status = 'present')::FLOAT / COUNT(*)::FLOAT) * 100.0
        ELSE 0.0
      END
      FROM public.attendance
      WHERE student_id = p_student_id
    ),

    'exam_avg_percentage', COALESCE((
      SELECT AVG(percentage)
      FROM public.exam_attempts
      WHERE student_id = p_student_id AND status = 'submitted'
    ), 0.0),

    'assignments_submitted', (
      SELECT COUNT(*)
      FROM public.assignment_submissions
      WHERE student_id = p_student_id
    ),

    'video_completion_percentage', COALESCE((
      SELECT AVG(percentage)
      FROM public.video_progress
      WHERE student_id = p_student_id
    ), 0.0),

    -- 3. Continue Learning Item
    'continue_learning_item', (
      SELECT json_build_object(
        'video_id', vp.video_id,
        'content_id', c.id,
        'title', c.title,
        'group_name', COALESCE(g.name, v_primary_group_name),
        'progress_seconds', vp.progress_seconds,
        'duration_seconds', COALESCE(vp.duration_seconds, v.duration, 0),
        'percentage', vp.percentage
      )
      FROM public.video_progress vp
      JOIN public.videos v ON v.id = vp.video_id
      JOIN public.content c ON c.id = v.content_id
      LEFT JOIN public.groups g ON g.id = c.group_id
      WHERE vp.student_id = p_student_id
        AND vp.completed = false
        AND vp.progress_seconds > 0
        AND c.status = 'published'
      ORDER BY vp.last_watched_at DESC
      LIMIT 1
    ),

    -- 4. Urgent Tasks (Combined unsubmitted assignments & unattempted exams)
    'urgent_tasks', (
      SELECT COALESCE(
        json_agg(task ORDER BY task.due_at ASC NULLS LAST),
        '[]'::json
      )
      FROM (
        -- Urgent Assignments (unsubmitted)
        SELECT 
          a.id,
          c.title,
          g.name AS group_name,
          'assignment' AS task_type,
          a.due_at,
          'pending' AS status,
          a.max_score
        FROM public.assignments a
        JOIN public.content c ON c.id = a.content_id
        JOIN public.groups g ON g.id = c.group_id
        WHERE c.group_id = ANY(v_group_ids)
          AND c.status = 'published'
          AND NOT EXISTS (
            SELECT 1 FROM public.assignment_submissions sub
            WHERE sub.assignment_id = a.id AND sub.student_id = p_student_id
          )

        UNION ALL

        -- Urgent Exams (unattempted)
        SELECT 
          ex.id,
          c.title,
          g.name AS group_name,
          'exam' AS task_type,
          ex.end_at AS due_at,
          'available' AS status,
          ex.max_score
        FROM public.exams ex
        JOIN public.content c ON c.id = ex.content_id
        JOIN public.groups g ON g.id = c.group_id
        WHERE c.group_id = ANY(v_group_ids)
          AND c.status = 'published'
          AND NOT EXISTS (
            SELECT 1 FROM public.exam_attempts att
            WHERE att.exam_id = ex.id AND att.student_id = p_student_id AND att.status = 'submitted'
          )
        ORDER BY due_at ASC NULLS LAST
        LIMIT 10
      ) task
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_student_dashboard(UUID) TO authenticated;
