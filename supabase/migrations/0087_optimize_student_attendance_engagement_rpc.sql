-- 0087_optimize_student_attendance_engagement_rpc.sql
-- High-performance, single-roundtrip RPC for student attendance and video watch engagement dashboard.
-- Eliminates sequential PostgREST roundtrips and RLS recursion overhead on content/videos.

-- 1. Covering index for published video lectures in groups
CREATE INDEX IF NOT EXISTS idx_content_published_videos 
  ON public.content(group_id, sort_order, created_at) 
  WHERE type = 'video' AND status = 'published';

-- 2. Covering index for student attendance records
CREATE INDEX IF NOT EXISTS idx_attendance_student_group_date 
  ON public.attendance(student_id, group_id, date DESC);

-- 3. Consolidated Student Attendance & Engagement RPC
CREATE OR REPLACE FUNCTION public.get_student_attendance_engagement(
  p_student_id UUID,
  p_group_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id UUID;
  v_caller_role TEXT;
  v_caller_tenant_id UUID;
  v_target_tenant_id UUID;
  v_is_authorized BOOLEAN := FALSE;
  
  v_all_enrolled_groups JSONB := '[]'::jsonb;
  v_target_group_ids UUID[];
  
  v_latest_activity TIMESTAMPTZ;
  v_most_recent_watch TIMESTAMPTZ;
  v_final_last_active TIMESTAMPTZ;
  
  v_lectures_count INT := 0;
  v_watch_seconds INT := 0;
  v_duration_seconds INT := 0;
  v_completed_count INT := 0;
  v_in_progress_count INT := 0;
  v_not_started_count INT := 0;
  v_commitment_pct NUMERIC(5,2) := 0.0;
  
  v_items JSONB := '[]'::jsonb;
  v_engagement_summary JSONB;
  
  v_att_total INT := 0;
  v_att_present INT := 0;
  v_att_absent INT := 0;
  v_att_late INT := 0;
  v_att_excused INT := 0;
  v_att_stats JSONB;
  v_att_history JSONB := '[]'::jsonb;
  
  v_result JSONB;
BEGIN
  v_caller_id := auth.uid();
  
  -- 1. Authorization check
  SELECT tenant_id INTO v_target_tenant_id
  FROM public.users WHERE id = p_student_id;
  
  IF v_target_tenant_id IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_FOUND: Target student not found';
  END IF;
  
  IF v_caller_id = p_student_id THEN
    v_is_authorized := TRUE;
  ELSIF v_caller_id IS NULL THEN
    IF current_user = 'postgres' OR current_setting('request.jwt.claim.role', true) = 'service_role' THEN
      v_is_authorized := TRUE;
    ELSE
      RAISE EXCEPTION 'AUTH_REQUIRED: User must be authenticated';
    END IF;
  ELSE
    SELECT role, tenant_id INTO v_caller_role, v_caller_tenant_id
    FROM public.users WHERE id = v_caller_id;
    
    IF v_caller_role = 'teacher' AND v_caller_tenant_id = v_target_tenant_id THEN
      v_is_authorized := TRUE;
    ELSIF v_caller_role = 'parent' AND EXISTS (
      SELECT 1 FROM public.parent_students ps
      WHERE ps.parent_id = v_caller_id AND ps.student_id = p_student_id
    ) THEN
      v_is_authorized := TRUE;
    END IF;
  END IF;
  
  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: You do not have permission to view this engagement record';
  END IF;

  -- 2. Fetch all active enrolled groups
  SELECT 
    COALESCE(jsonb_agg(jsonb_build_object(
      'id', g.id,
      'name', g.name,
      'level', COALESCE(g.level, '')
    ) ORDER BY g.name ASC), '[]'::jsonb),
    COALESCE(array_agg(g.id), ARRAY[]::UUID[])
  INTO v_all_enrolled_groups, v_target_group_ids
  FROM public.group_members gm
  JOIN public.groups g ON g.id = gm.group_id
  WHERE gm.student_id = p_student_id
    AND gm.status = 'active';

  -- If filter group provided, filter target groups
  IF p_group_id IS NOT NULL THEN
    v_target_group_ids := ARRAY[p_group_id];
  END IF;

  -- 3. If enrolled groups exist, compute lecture engagement
  IF array_length(v_target_group_ids, 1) > 0 THEN
    WITH enrolled_info AS (
      SELECT 
        gm.group_id,
        g.name AS group_name
      FROM public.group_members gm
      JOIN public.groups g ON g.id = gm.group_id
      WHERE gm.student_id = p_student_id
        AND gm.status = 'active'
    ),
    raw_lectures AS (
      SELECT 
        c.id AS content_id,
        c.title AS lecture_title,
        COALESCE(c.group_id, (SELECT group_id FROM enrolled_info LIMIT 1)) AS group_id,
        COALESCE(eg.group_name, '') AS group_name,
        v.id AS video_id,
        COALESCE(v.duration, 0) AS duration_seconds,
        COALESCE(
          CASE 
            WHEN vp.actual_watch_seconds > 0 THEN vp.actual_watch_seconds 
            ELSE vp.progress_seconds 
          END, 0
        ) AS watch_seconds,
        ROUND(COALESCE(vp.watched_coverage_percentage, vp.percentage, 0)::numeric, 1) AS watch_progress_percent,
        (COALESCE(vp.completed, false) OR COALESCE(vp.watched_coverage_percentage, vp.percentage, 0) >= 80.0) AS is_completed,
        vp.last_watched_at,
        COALESCE(c.sort_order, 0) AS sort_order,
        c.created_at
      FROM public.content c
      LEFT JOIN enrolled_info eg ON eg.group_id = c.group_id
      LEFT JOIN public.videos v ON v.content_id = c.id
      LEFT JOIN public.video_progress vp ON vp.video_id = v.id AND vp.student_id = p_student_id
      WHERE (
        c.group_id = ANY(v_target_group_ids)
        OR EXISTS (
          SELECT 1 FROM public.content_groups cg
          WHERE cg.content_id = c.id
            AND cg.group_id = ANY(v_target_group_ids)
            AND cg.is_published = true
        )
      )
      AND c.type = 'video'
      AND c.status = 'published'
      ORDER BY c.sort_order ASC, c.created_at ASC
    )
    SELECT 
      COUNT(*),
      COALESCE(SUM(duration_seconds), 0),
      COALESCE(SUM(watch_seconds), 0),
      COUNT(*) FILTER (WHERE is_completed = true),
      COUNT(*) FILTER (WHERE is_completed = false AND watch_progress_percent > 0),
      COUNT(*) FILTER (WHERE watch_progress_percent = 0),
      MAX(last_watched_at),
      COALESCE(jsonb_agg(jsonb_build_object(
        'content_id', content_id,
        'lecture_title', lecture_title,
        'group_id', group_id,
        'group_name', group_name,
        'video_id', video_id,
        'duration_seconds', duration_seconds,
        'watch_seconds', watch_seconds,
        'watch_progress_percent', watch_progress_percent,
        'is_completed', is_completed,
        'last_watched_at', last_watched_at,
        'sort_order', sort_order
      ) ORDER BY sort_order ASC, created_at ASC), '[]'::jsonb)
    INTO 
      v_lectures_count,
      v_duration_seconds,
      v_watch_seconds,
      v_completed_count,
      v_in_progress_count,
      v_not_started_count,
      v_most_recent_watch,
      v_items
    FROM raw_lectures;
  END IF;

  -- 4. Calculate overall commitment percentage
  IF v_duration_seconds > 0 THEN
    v_commitment_pct := ROUND(((v_watch_seconds::numeric / v_duration_seconds::numeric) * 100.0), 1);
  ELSIF v_lectures_count > 0 THEN
    v_commitment_pct := ROUND(((v_completed_count::numeric / v_lectures_count::numeric) * 100.0), 1);
  ELSE
    v_commitment_pct := 0.0;
  END IF;
  
  IF v_commitment_pct > 100.0 THEN
    v_commitment_pct := 100.0;
  END IF;

  -- 5. Last active platform activity
  SELECT created_at INTO v_latest_activity
  FROM public.activity_events
  WHERE user_id = p_student_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_latest_activity IS NOT NULL AND (v_most_recent_watch IS NULL OR v_latest_activity > v_most_recent_watch) THEN
    v_final_last_active := v_latest_activity;
  ELSE
    v_final_last_active := v_most_recent_watch;
  END IF;

  -- Build Engagement Summary JSON
  v_engagement_summary := jsonb_build_object(
    'total_watch_seconds', v_watch_seconds,
    'total_duration_seconds', v_duration_seconds,
    'total_lectures_count', v_lectures_count,
    'completed_lectures_count', v_completed_count,
    'in_progress_lectures_count', v_in_progress_count,
    'not_started_lectures_count', v_not_started_count,
    'overall_commitment_percentage', v_commitment_pct,
    'last_active_at', v_final_last_active,
    'enrolled_groups', v_all_enrolled_groups,
    'items', v_items
  );

  -- 6. Physical Attendance Stats & History
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE status = 'present'),
    COUNT(*) FILTER (WHERE status = 'absent'),
    COUNT(*) FILTER (WHERE status = 'late'),
    COUNT(*) FILTER (WHERE status = 'excused')
  INTO 
    v_att_total,
    v_att_present,
    v_att_absent,
    v_att_late,
    v_att_excused
  FROM public.attendance
  WHERE student_id = p_student_id
    AND (p_group_id IS NULL OR group_id = p_group_id);

  v_att_stats := jsonb_build_object(
    'total_sessions', v_att_total,
    'present_count', v_att_present,
    'absent_count', v_att_absent,
    'late_count', v_att_late,
    'excused_count', v_att_excused,
    'average_watch_percentage', 0.0
  );

  SELECT COALESCE(jsonb_agg(h), '[]'::jsonb) INTO v_att_history
  FROM (
    SELECT 
      a.id,
      a.tenant_id,
      a.group_id,
      a.student_id,
      a.date,
      a.status,
      a.marked_by,
      a.note,
      a.marked_at,
      g.name AS group_name,
      u.full_name AS student_name
    FROM public.attendance a
    LEFT JOIN public.groups g ON g.id = a.group_id
    LEFT JOIN public.users u ON u.id = a.student_id
    WHERE a.student_id = p_student_id
      AND (p_group_id IS NULL OR a.group_id = p_group_id)
    ORDER BY a.date DESC
    LIMIT 20
  ) h;

  -- 7. Final JSON response
  v_result := jsonb_build_object(
    'engagement_summary', v_engagement_summary,
    'attendance_stats', v_att_stats,
    'attendance_history', v_att_history
  );

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_student_attendance_engagement(UUID, UUID) TO authenticated, service_role;
