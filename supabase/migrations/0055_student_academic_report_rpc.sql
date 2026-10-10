-- 0055_student_academic_report_rpc.sql
-- High-performance, period-aware Academic Report generator for Parent WhatsApp & Portal

CREATE OR REPLACE FUNCTION public.get_student_academic_report(
  p_student_id UUID,
  p_days INT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cutoff_ts TIMESTAMPTZ := NULL;
  v_cutoff_date DATE := NULL;
  v_result JSONB;
BEGIN
  IF p_days IS NOT NULL AND p_days > 0 THEN
    v_cutoff_ts := NOW() - (p_days || ' days')::INTERVAL;
    v_cutoff_date := CURRENT_DATE - p_days;
  END IF;

  WITH student_info AS (
    SELECT 
      u.id,
      u.full_name,
      u.phone,
      u.parent_phone,
      (
        SELECT string_agg(g.name, ', ')
        FROM group_members gm
        JOIN groups g ON g.id = gm.group_id
        WHERE gm.student_id = u.id AND gm.status = 'active'
      ) AS group_names
    FROM users u
    WHERE u.id = p_student_id
  ),
  total_group_videos AS (
    SELECT COUNT(DISTINCT v.id) AS total_assigned
    FROM videos v
    JOIN content c ON c.id = v.content_id
    WHERE c.status = 'published'
      AND (
        c.group_id IN (SELECT group_id FROM group_members WHERE student_id = p_student_id AND status = 'active')
        OR EXISTS (
          SELECT 1 FROM content_groups cg 
          JOIN group_members gm ON gm.group_id = cg.group_id 
          WHERE cg.content_id = c.id AND gm.student_id = p_student_id AND gm.status = 'active'
        )
      )
      AND (v_cutoff_ts IS NULL OR c.created_at >= v_cutoff_ts)
  ),
  video_stats AS (
    SELECT 
      COUNT(*) AS videos_watched,
      COUNT(*) FILTER (WHERE completed = true) AS videos_completed,
      ROUND(COALESCE(AVG(percentage), 0), 1) AS avg_video_percentage
    FROM video_progress
    WHERE student_id = p_student_id
      AND (v_cutoff_ts IS NULL OR last_watched_at >= v_cutoff_ts)
  ),
  total_group_assignments AS (
    SELECT COUNT(DISTINCT a.id) AS total_assigned
    FROM assignments a
    JOIN content c ON c.id = a.content_id
    WHERE c.status = 'published'
      AND (
        c.group_id IN (SELECT group_id FROM group_members WHERE student_id = p_student_id AND status = 'active')
        OR EXISTS (
          SELECT 1 FROM content_groups cg 
          JOIN group_members gm ON gm.group_id = cg.group_id 
          WHERE cg.content_id = c.id AND gm.student_id = p_student_id AND gm.status = 'active'
        )
      )
      AND (v_cutoff_ts IS NULL OR c.created_at >= v_cutoff_ts)
  ),
  assignment_stats AS (
    SELECT 
      COUNT(*) AS assignments_submitted,
      COUNT(*) FILTER (WHERE status = 'reviewed') AS assignments_reviewed
    FROM assignment_submissions
    WHERE student_id = p_student_id
      AND (v_cutoff_ts IS NULL OR submitted_at >= v_cutoff_ts)
  ),
  exam_stats AS (
    SELECT 
      COUNT(*) AS exams_submitted,
      ROUND(COALESCE(AVG(percentage), 0), 1) AS avg_exam_percentage
    FROM exam_attempts
    WHERE student_id = p_student_id 
      AND status = 'submitted'
      AND (v_cutoff_ts IS NULL OR submitted_at >= v_cutoff_ts)
  ),
  latest_exam AS (
    SELECT 
      e.title,
      ea.score,
      e.max_score,
      ea.percentage,
      ea.submitted_at
    FROM exam_attempts ea
    JOIN exams e ON e.id = ea.exam_id
    WHERE ea.student_id = p_student_id 
      AND ea.status = 'submitted'
      AND (v_cutoff_ts IS NULL OR ea.submitted_at >= v_cutoff_ts)
    ORDER BY ea.submitted_at DESC
    LIMIT 1
  ),
  engagement_stats AS (
    SELECT 
      COALESCE(ROUND(SUM(active_seconds) / 60.0), 0) AS active_minutes,
      MAX(last_seen_at) AS last_seen_at
    FROM student_daily_engagement
    WHERE student_id = p_student_id
      AND (v_cutoff_date IS NULL OR date >= v_cutoff_date)
  ),
  attendance_stats AS (
    SELECT 
      COUNT(*) AS total_sessions,
      COUNT(*) FILTER (WHERE status = 'present') AS attended_sessions,
      COUNT(*) FILTER (WHERE status = 'absent') AS absent_sessions
    FROM attendance
    WHERE student_id = p_student_id
      AND (v_cutoff_date IS NULL OR date >= v_cutoff_date)
  )
  SELECT jsonb_build_object(
    'student', (SELECT row_to_json(si) FROM student_info si),
    'period_days', p_days,
    'videos', jsonb_build_object(
      'watched', (SELECT videos_watched FROM video_stats),
      'completed', (SELECT videos_completed FROM video_stats),
      'avg_percentage', (SELECT avg_video_percentage FROM video_stats),
      'total_assigned', (SELECT total_assigned FROM total_group_videos)
    ),
    'assignments', jsonb_build_object(
      'submitted', (SELECT assignments_submitted FROM assignment_stats),
      'reviewed', (SELECT assignments_reviewed FROM assignment_stats),
      'total_assigned', (SELECT total_assigned FROM total_group_assignments)
    ),
    'exams', jsonb_build_object(
      'submitted', (SELECT exams_submitted FROM exam_stats),
      'avg_percentage', (SELECT avg_exam_percentage FROM exam_stats),
      'latest_exam', (SELECT row_to_json(le) FROM latest_exam le)
    ),
    'engagement', jsonb_build_object(
      'active_minutes', (SELECT active_minutes FROM engagement_stats),
      'last_seen_at', (SELECT last_seen_at FROM engagement_stats)
    ),
    'attendance', jsonb_build_object(
      'total_sessions', (SELECT total_sessions FROM attendance_stats),
      'attended', (SELECT attended_sessions FROM attendance_stats),
      'absent', (SELECT absent_sessions FROM attendance_stats)
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- Future-ready bulk dispatch helper for group-wide parent reports
CREATE OR REPLACE FUNCTION public.get_group_academic_reports(
  p_group_id UUID,
  p_days INT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_reports JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(public.get_student_academic_report(gm.student_id, p_days)), '[]'::jsonb)
  INTO v_reports
  FROM public.group_members gm
  WHERE gm.group_id = p_group_id AND gm.status = 'active';

  RETURN v_reports;
END;
$$;
