-- Migration 0075: Create get_teacher_radar_alerts RPC & Optimize Composite Indexes
-- Radical slowness fix for Teacher Action Radar and Content Group Feeds (Zero caching dependency)

-- 1. Create atomic, single-round-trip RPC for Teacher Radar Alerts
CREATE OR REPLACE FUNCTION public.get_teacher_radar_alerts(p_teacher_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant_id UUID;
  v_low_scores JSONB;
  v_unwatched JSONB;
  v_overdue JSONB;
BEGIN
  -- Get teacher's tenant
  SELECT tenant_id INTO v_tenant_id FROM public.users WHERE id = p_teacher_id;
  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'low_scores', '[]'::jsonb,
      'unwatched_videos', '[]'::jsonb,
      'overdue_assignments', '[]'::jsonb
    );
  END IF;

  -- 1. Low Score Alerts (Exams < 60%)
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'student_id', s.id,
    'name', s.full_name,
    'group', COALESCE((
      SELECT g.name 
      FROM public.group_members gm 
      JOIN public.groups g ON g.id = gm.group_id 
      WHERE gm.student_id = s.id AND gm.status = 'active' 
      LIMIT 1
    ), 'General'),
    'detail', COALESCE(e.title, 'Exam') || ': ' || ea.percentage || '%'
  )), '[]'::jsonb) INTO v_low_scores
  FROM (
    SELECT ea.student_id, ea.exam_id, ea.percentage
    FROM public.exam_attempts ea
    JOIN public.users u ON u.id = ea.student_id
    WHERE u.tenant_id = v_tenant_id 
      AND ea.status = 'submitted' 
      AND ea.percentage < 60
    ORDER BY ea.submitted_at DESC
    LIMIT 10
  ) ea
  JOIN public.users s ON s.id = ea.student_id
  LEFT JOIN public.exams e ON e.id = ea.exam_id;

  -- 2. Unwatched Videos (Started but < 50% watched in past 7 days)
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'student_id', s.id,
    'name', s.full_name,
    'group', COALESCE((
      SELECT g.name 
      FROM public.group_members gm 
      JOIN public.groups g ON g.id = gm.group_id 
      WHERE gm.student_id = s.id AND gm.status = 'active' 
      LIMIT 1
    ), 'General'),
    'detail', COALESCE(vl.title, c.title, 'Video') || ' (' || vp.percentage || '%)'
  )), '[]'::jsonb) INTO v_unwatched
  FROM (
    SELECT vp.student_id, vp.video_id, vp.percentage
    FROM public.video_progress vp
    JOIN public.users u ON u.id = vp.student_id
    WHERE u.tenant_id = v_tenant_id 
      AND vp.percentage < 50
      AND vp.last_watched_at > (NOW() - INTERVAL '7 days')
    ORDER BY vp.last_watched_at DESC
    LIMIT 10
  ) vp
  JOIN public.users s ON s.id = vp.student_id
  LEFT JOIN public.videos v ON v.id = vp.video_id
  LEFT JOIN public.content c ON c.id = v.content_id
  LEFT JOIN public.video_library vl ON vl.id = vp.video_id;

  -- 3. Overdue Assignments (marked late or past due)
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'student_id', s.id,
    'name', s.full_name,
    'group', COALESCE((
      SELECT g.name 
      FROM public.group_members gm 
      JOIN public.groups g ON g.id = gm.group_id 
      WHERE gm.student_id = s.id AND gm.status = 'active' 
      LIMIT 1
    ), 'General'),
    'detail', COALESCE(c.title, 'Assignment') || ' (Late)'
  )), '[]'::jsonb) INTO v_overdue
  FROM (
    SELECT asub.student_id, asub.assignment_id
    FROM public.assignment_submissions asub
    JOIN public.users u ON u.id = asub.student_id
    WHERE u.tenant_id = v_tenant_id 
      AND asub.status = 'late'
    ORDER BY asub.submitted_at DESC
    LIMIT 10
  ) asub
  JOIN public.users s ON s.id = asub.student_id
  JOIN public.assignments a ON a.id = asub.assignment_id
  LEFT JOIN public.content c ON c.id = a.content_id;

  RETURN jsonb_build_object(
    'low_scores', v_low_scores,
    'unwatched_videos', v_unwatched,
    'overdue_assignments', v_overdue
  );
END;
$$;

-- Grant execution permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_teacher_radar_alerts(UUID) TO authenticated;

-- 2. Composite indexes for high-speed feeds and queries
CREATE INDEX IF NOT EXISTS idx_content_groups_group_pub_sort 
  ON public.content_groups (group_id, is_published, sort_order);

CREATE INDEX IF NOT EXISTS idx_exam_attempts_student_status_pct 
  ON public.exam_attempts (student_id, status, percentage);

CREATE INDEX IF NOT EXISTS idx_video_progress_student_pct 
  ON public.video_progress (student_id, percentage, last_watched_at);
