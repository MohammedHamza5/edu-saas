-- ============================================================================
-- Migration: 0039_fix_video_progress_percentage_and_completion.sql
-- Description:
-- 1. Fix update_video_progress_v2 to update 'percentage' column (previously omitted,
--    causing percentage to remain 0.00 in public.video_progress).
-- 2. Enhance coverage calculation to include furthest/resume position, preventing
--    videos from being stuck at 0% or uncompleted when students reach the end.
-- 3. Update get_student_dashboard to select effective percentage and exclude finished videos.
-- 4. Backfill existing video_progress rows to repair 0% states.
-- ============================================================================

-- 1. Update update_video_progress_v2
CREATE OR REPLACE FUNCTION public.update_video_progress_v2(
  p_video_id uuid,
  p_duration_seconds int,
  p_resume_position_seconds int,
  p_new_segments jsonb, -- e.g. [[0, 10], [15, 20]]
  p_actual_watch_seconds_added int DEFAULT 0,
  p_is_skipped boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_tenant_id uuid;
  v_existing_segments jsonb;
  v_all_segments jsonb;
  v_final_segments jsonb;
  v_total_watched int;
  v_watched_coverage numeric(5,2);
  v_position_coverage numeric(5,2);
  v_effective_percentage numeric(5,2);
  v_completed boolean;
  v_furthest_position int;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT tenant_id INTO v_tenant_id
  FROM public.users
  WHERE id = v_user_id AND status = 'active';

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  -- Ensure record exists
  INSERT INTO public.video_progress (tenant_id, video_id, student_id, duration_seconds)
  VALUES (v_tenant_id, p_video_id, v_user_id, p_duration_seconds)
  ON CONFLICT (video_id, student_id) DO NOTHING;

  -- Get current state
  SELECT watched_segments, furthest_position_seconds
  INTO v_existing_segments, v_furthest_position
  FROM public.video_progress
  WHERE video_id = p_video_id AND student_id = v_user_id;

  -- Merge segments logic
  v_all_segments := CASE 
    WHEN jsonb_array_length(v_existing_segments) > 0 THEN v_existing_segments || COALESCE(p_new_segments, '[]'::jsonb)
    ELSE COALESCE(p_new_segments, '[]'::jsonb)
  END;

  IF jsonb_array_length(v_all_segments) = 0 THEN
    v_final_segments := '[]'::jsonb;
    v_total_watched := 0;
  ELSE
    WITH unnested AS (
      SELECT (elem->>0)::int as start_sec, (elem->>1)::int as end_sec
      FROM jsonb_array_elements(v_all_segments) as elem
    ),
    ordered AS (
      SELECT start_sec, end_sec
      FROM unnested
      ORDER BY start_sec, end_sec
    ),
    merged AS (
      SELECT start_sec, end_sec,
             max(end_sec) OVER (ORDER BY start_sec, end_sec ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) as prev_max_end
      FROM ordered
    ),
    groups AS (
      SELECT start_sec, end_sec,
             count(*) FILTER (WHERE prev_max_end IS NULL OR start_sec > prev_max_end) OVER (ORDER BY start_sec, end_sec) as grp
      FROM merged
    ),
    final_segs AS (
      SELECT min(start_sec) as start_sec, max(end_sec) as end_sec
      FROM groups
      GROUP BY grp
      ORDER BY min(start_sec)
    )
    SELECT COALESCE(jsonb_agg(jsonb_build_array(start_sec, end_sec)), '[]'::jsonb),
           COALESCE(sum(end_sec - start_sec), 0)::int
    INTO v_final_segments, v_total_watched
    FROM final_segs;
  END IF;

  -- Calculate segment-based coverage
  IF p_duration_seconds > 0 THEN
    v_watched_coverage := LEAST(100.0, (v_total_watched::numeric / p_duration_seconds::numeric) * 100.0);
  ELSE
    v_watched_coverage := 0.0;
  END IF;

  -- Calculate position-based coverage
  v_furthest_position := GREATEST(COALESCE(v_furthest_position, 0), p_resume_position_seconds);
  IF jsonb_array_length(v_final_segments) > 0 THEN
    SELECT GREATEST(v_furthest_position, max((elem->>1)::int))
    INTO v_furthest_position
    FROM jsonb_array_elements(v_final_segments) as elem;
  END IF;

  IF p_duration_seconds > 0 THEN
    v_position_coverage := LEAST(100.0, (GREATEST(p_resume_position_seconds, v_furthest_position)::numeric / p_duration_seconds::numeric) * 100.0);
  ELSE
    v_position_coverage := 0.0;
  END IF;

  -- Effective percentage is the maximum of coverage and position
  v_effective_percentage := GREATEST(v_watched_coverage, v_position_coverage);

  -- Completion rule (monotonic: reaching 90%+ in coverage or position marks it complete)
  v_completed := (v_effective_percentage >= 90.0)
              OR (v_watched_coverage >= 90.0)
              OR (p_duration_seconds > 0 AND p_resume_position_seconds >= (p_duration_seconds * 0.90))
              OR (p_duration_seconds > 0 AND v_furthest_position >= (p_duration_seconds * 0.90));

  -- Update DB (both percentage and watched_coverage_percentage)
  UPDATE public.video_progress
  SET 
    progress_seconds = p_resume_position_seconds,
    duration_seconds = p_duration_seconds,
    percentage = v_effective_percentage,
    watched_segments = v_final_segments,
    watched_coverage_percentage = v_effective_percentage,
    furthest_position_seconds = v_furthest_position,
    actual_watch_seconds = actual_watch_seconds + p_actual_watch_seconds_added,
    is_skipped = is_skipped OR p_is_skipped,
    completed = (completed OR v_completed),
    last_watched_at = now()
  WHERE video_id = p_video_id AND student_id = v_user_id;

  RETURN jsonb_build_object(
    'status', 'ok',
    'progress_seconds', p_resume_position_seconds,
    'furthest_position_seconds', v_furthest_position,
    'watched_coverage_percentage', v_effective_percentage,
    'actual_watch_seconds', (SELECT actual_watch_seconds FROM public.video_progress WHERE video_id = p_video_id AND student_id = v_user_id),
    'completed', (SELECT completed FROM public.video_progress WHERE video_id = p_video_id AND student_id = v_user_id)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_video_progress_v2(uuid, int, int, jsonb, int, boolean) TO authenticated;

-- 2. Update get_student_dashboard RPC
CREATE OR REPLACE FUNCTION public.get_student_dashboard(p_student_id UUID)
RETURNS JSON
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
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
      SELECT AVG(GREATEST(
        COALESCE(percentage, 0),
        COALESCE(watched_coverage_percentage, 0),
        CASE WHEN duration_seconds > 0 THEN LEAST(100.0, (GREATEST(progress_seconds, COALESCE(furthest_position_seconds, 0))::numeric / duration_seconds::numeric) * 100.0) ELSE 0.0 END
      ))
      FROM public.video_progress
      WHERE student_id = p_student_id
    ), 0.0),

    -- 3. Continue Learning Item (only uncompleted, non-finished videos)
    'continue_learning_item', (
      SELECT json_build_object(
        'video_id', vp.video_id,
        'content_id', c.id,
        'title', c.title,
        'group_name', COALESCE(g.name, v_primary_group_name),
        'progress_seconds', vp.progress_seconds,
        'duration_seconds', COALESCE(vp.duration_seconds, v.duration, 0),
        'percentage', GREATEST(
          COALESCE(vp.percentage, 0),
          COALESCE(vp.watched_coverage_percentage, 0),
          CASE 
            WHEN COALESCE(vp.duration_seconds, v.duration, 0) > 0 
            THEN LEAST(100.0, (GREATEST(vp.progress_seconds, COALESCE(vp.furthest_position_seconds, 0))::numeric / COALESCE(vp.duration_seconds, v.duration, 1)::numeric) * 100.0)
            ELSE 0.0 
          END
        )
      )
      FROM public.video_progress vp
      JOIN public.videos v ON v.id = vp.video_id
      JOIN public.content c ON c.id = v.content_id
      LEFT JOIN public.groups g ON g.id = c.group_id
      WHERE vp.student_id = p_student_id
        AND vp.completed = false
        AND vp.progress_seconds > 0
        AND (vp.duration_seconds = 0 OR vp.progress_seconds < (vp.duration_seconds * 0.95))
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
            WHERE att.exam_id = ex.id AND att.student_id = p_student_id AND att.status IN ('submitted', 'completed')
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

-- 3. Backfill existing video_progress records
UPDATE public.video_progress
SET 
  percentage = GREATEST(
    COALESCE(percentage, 0),
    COALESCE(watched_coverage_percentage, 0),
    CASE WHEN duration_seconds > 0 THEN LEAST(100.0, (GREATEST(progress_seconds, COALESCE(furthest_position_seconds, 0))::numeric / duration_seconds::numeric) * 100.0) ELSE 0.0 END
  ),
  watched_coverage_percentage = GREATEST(
    COALESCE(watched_coverage_percentage, 0),
    COALESCE(percentage, 0),
    CASE WHEN duration_seconds > 0 THEN LEAST(100.0, (GREATEST(progress_seconds, COALESCE(furthest_position_seconds, 0))::numeric / duration_seconds::numeric) * 100.0) ELSE 0.0 END
  ),
  completed = completed OR (
    (duration_seconds > 0 AND progress_seconds >= duration_seconds * 0.90) OR
    (duration_seconds > 0 AND furthest_position_seconds >= duration_seconds * 0.90) OR
    watched_coverage_percentage >= 90.0
  );
