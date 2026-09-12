-- 0002_student_360_rpc.sql
-- Missing RPCs for Teacher Dashboard Action Radar and Student 360 Telemetry

-- 1. get_student_360
CREATE OR REPLACE FUNCTION public.get_student_360(p_student_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tenant_id UUID;
  v_last_activity TIMESTAMPTZ;
  
  v_attendance_total INT;
  v_attendance_present INT;
  
  v_submissions_total INT;
  v_submissions_reviewed INT;
  
  v_exam_avg NUMERIC(5,2);
  v_video_avg NUMERIC(5,2);
  
  v_today_active_seconds INT := 0;
  v_today_idle_seconds INT := 0;
  v_total_active_seconds_7d INT := 0;
  v_total_idle_seconds_7d INT := 0;
  v_first_seen_today TIMESTAMPTZ;
  v_last_seen_today TIMESTAMPTZ;
  
  v_groups JSONB;
  v_recent_activities JSONB;
  v_video_insights JSONB;
  
  v_result JSONB;
BEGIN
  -- Get user info
  SELECT tenant_id, last_activity_at INTO v_tenant_id, v_last_activity
  FROM public.users WHERE id = p_student_id;

  -- Get groups
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'group_id', gm.group_id,
    'joined_at', gm.joined_at,
    'groups', jsonb_build_object('name', g.name, 'level', g.level)
  )), '[]'::jsonb) INTO v_groups
  FROM public.group_members gm
  JOIN public.groups g ON g.id = gm.group_id
  WHERE gm.student_id = p_student_id AND gm.status = 'active';

  -- Get attendance stats
  SELECT COUNT(*), COUNT(*) FILTER (WHERE status = 'present') 
  INTO v_attendance_total, v_attendance_present
  FROM public.attendance WHERE student_id = p_student_id;
  
  -- Get assignment stats
  SELECT COUNT(*), COUNT(*) FILTER (WHERE status = 'reviewed')
  INTO v_submissions_total, v_submissions_reviewed
  FROM public.assignment_submissions WHERE student_id = p_student_id;

  -- Get exam average
  SELECT COALESCE(AVG(percentage), 0) INTO v_exam_avg
  FROM public.exam_attempts 
  WHERE student_id = p_student_id AND status = 'submitted';

  -- Get video average
  SELECT COALESCE(AVG(percentage), 0) INTO v_video_avg
  FROM public.video_progress 
  WHERE student_id = p_student_id;

  -- Smart Engagement Telemetry (Simulated based on activity_events)
  SELECT 
    COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE) * 120,
    COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE) * 30,
    COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE - INTERVAL '7 days') * 120,
    COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE - INTERVAL '7 days') * 30,
    MIN(created_at) FILTER (WHERE created_at >= CURRENT_DATE),
    MAX(created_at) FILTER (WHERE created_at >= CURRENT_DATE)
  INTO 
    v_today_active_seconds, v_today_idle_seconds,
    v_total_active_seconds_7d, v_total_idle_seconds_7d,
    v_first_seen_today, v_last_seen_today
  FROM public.activity_events WHERE user_id = p_student_id;

  -- Recent activities (last 10)
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', a.id,
    'event_type', a.event_type,
    'created_at', a.created_at,
    'content_id', a.content_id,
    'metadata', a.metadata
  )), '[]'::jsonb) INTO v_recent_activities
  FROM (
    SELECT * FROM public.activity_events 
    WHERE user_id = p_student_id 
    ORDER BY created_at DESC LIMIT 10
  ) a;

  -- Video Insights
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'video_id', vp.video_id,
    'video_title', c.title,
    'duration_seconds', vp.duration_seconds,
    'progress_seconds', vp.progress_seconds,
    'actual_watch_seconds', vp.progress_seconds, 
    'percentage', vp.percentage,
    'completed', vp.completed,
    'is_skipped', false,
    'last_watched_at', vp.last_watched_at
  )), '[]'::jsonb) INTO v_video_insights
  FROM public.video_progress vp
  JOIN public.videos v ON v.id = vp.video_id
  JOIN public.content c ON c.id = v.content_id
  WHERE vp.student_id = p_student_id
  ORDER BY vp.last_watched_at DESC LIMIT 10;

  -- Build final JSON
  v_result := jsonb_build_object(
    'groups', v_groups,
    'last_activity_at', v_last_activity,
    'attendance_total', v_attendance_total,
    'attendance_present', v_attendance_present,
    'submissions_total', v_submissions_total,
    'submissions_reviewed', v_submissions_reviewed,
    'exam_avg_percentage', v_exam_avg,
    'video_avg_percentage', v_video_avg,
    'today_active_seconds', v_today_active_seconds,
    'today_idle_seconds', v_today_idle_seconds,
    'total_active_seconds_7d', v_total_active_seconds_7d,
    'total_idle_seconds_7d', v_total_idle_seconds_7d,
    'first_seen_today', v_first_seen_today,
    'last_seen_today', v_last_seen_today,
    'recent_activities', v_recent_activities,
    'video_insights', v_video_insights
  );

  RETURN v_result;
END;
$$;

-- 2. get_teacher_radar_alerts
CREATE OR REPLACE FUNCTION public.get_teacher_radar_alerts(p_teacher_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tenant_id UUID;
  v_low_scores JSONB;
  v_unwatched JSONB;
  v_overdue JSONB;
BEGIN
  -- Get teacher's tenant
  SELECT tenant_id INTO v_tenant_id FROM public.users WHERE id = p_teacher_id;

  -- 1. Low Score Alerts (Exams < 60%)
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'student_id', s.id,
    'name', s.full_name,
    'group', g.name,
    'detail', 'Score: ' || ea.percentage || '%'
  )), '[]'::jsonb) INTO v_low_scores
  FROM public.exam_attempts ea
  JOIN public.users s ON s.id = ea.student_id
  JOIN public.exams e ON e.id = ea.exam_id
  JOIN public.content c ON c.id = e.content_id
  JOIN public.groups g ON g.id = c.group_id
  WHERE s.tenant_id = v_tenant_id 
    AND ea.status = 'submitted' 
    AND ea.percentage < 60
  LIMIT 10;

  -- 2. Unwatched Videos (Started but < 50%)
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'student_id', s.id,
    'name', s.full_name,
    'group', g.name,
    'detail', 'Watched ' || vp.percentage || '% only'
  )), '[]'::jsonb) INTO v_unwatched
  FROM public.video_progress vp
  JOIN public.users s ON s.id = vp.student_id
  JOIN public.videos v ON v.id = vp.video_id
  JOIN public.content c ON c.id = v.content_id
  JOIN public.groups g ON g.id = c.group_id
  WHERE s.tenant_id = v_tenant_id 
    AND vp.percentage < 50
    AND vp.last_watched_at > CURRENT_DATE - INTERVAL '7 days'
  LIMIT 10;

  -- 3. Overdue Assignments
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'student_id', s.id,
    'name', s.full_name,
    'group', g.name,
    'detail', 'Late submission'
  )), '[]'::jsonb) INTO v_overdue
  FROM public.assignment_submissions asub
  JOIN public.users s ON s.id = asub.student_id
  JOIN public.assignments a ON a.id = asub.assignment_id
  JOIN public.content c ON c.id = a.content_id
  JOIN public.groups g ON g.id = c.group_id
  WHERE s.tenant_id = v_tenant_id 
    AND asub.status = 'late'
  LIMIT 10;

  RETURN jsonb_build_object(
    'low_scores', v_low_scores,
    'unwatched_videos', v_unwatched,
    'overdue_assignments', v_overdue
  );
END;
$$;
