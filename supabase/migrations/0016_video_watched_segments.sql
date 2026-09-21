-- ============================================================================
-- Migration: 0016_video_watched_segments.sql
-- Description:
-- 1. Add watched_segments to video_progress
-- 2. Add watched_coverage_percentage to video_progress
-- 3. Create update_video_progress_v2 for segment merging
-- ============================================================================

-- 1. Add columns to video_progress
ALTER TABLE public.video_progress
  ADD COLUMN IF NOT EXISTS watched_segments jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS watched_coverage_percentage numeric(5,2) NOT NULL DEFAULT 0;

-- 2. RPC: update_video_progress_v2
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

  -- Calculate coverage
  IF p_duration_seconds > 0 THEN
    v_watched_coverage := LEAST(100.0, (v_total_watched::numeric / p_duration_seconds::numeric) * 100.0);
  ELSE
    v_watched_coverage := 0.0;
  END IF;

  v_completed := v_watched_coverage >= 90.0;

  -- Calculate new furthest position
  SELECT GREATEST(v_furthest_position, max((elem->>1)::int))
  INTO v_furthest_position
  FROM jsonb_array_elements(v_final_segments) as elem;

  -- Update DB
  UPDATE public.video_progress
  SET 
    progress_seconds = p_resume_position_seconds,
    duration_seconds = p_duration_seconds,
    watched_segments = v_final_segments,
    watched_coverage_percentage = v_watched_coverage,
    furthest_position_seconds = COALESCE(v_furthest_position, 0),
    actual_watch_seconds = actual_watch_seconds + p_actual_watch_seconds_added,
    is_skipped = is_skipped OR p_is_skipped,
    completed = v_completed,
    last_watched_at = now()
  WHERE video_id = p_video_id AND student_id = v_user_id;

  RETURN jsonb_build_object(
    'status', 'ok',
    'progress_seconds', p_resume_position_seconds,
    'furthest_position_seconds', COALESCE(v_furthest_position, 0),
    'watched_coverage_percentage', v_watched_coverage,
    'actual_watch_seconds', (SELECT actual_watch_seconds FROM public.video_progress WHERE video_id = p_video_id AND student_id = v_user_id),
    'completed', v_completed
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_video_progress_v2(uuid, int, int, jsonb, int, boolean) TO authenticated;
