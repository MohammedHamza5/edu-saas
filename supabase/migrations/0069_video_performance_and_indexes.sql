-- ============================================================================
-- Migration: 0069_video_performance_and_indexes.sql
-- Purpose:
-- 1. Add covering indexes for high-frequency foreign keys (videos.content_id, etc.)
-- 2. Optimize record_activity_event RPC to throttle last_activity_at row locking on public.users
-- 3. Cleanup redundant ghost events from activity_events table
-- ============================================================================

-- 1. Missing Indexes on High-Traffic Tables
CREATE INDEX IF NOT EXISTS idx_videos_content_id 
  ON public.videos(content_id);

CREATE INDEX IF NOT EXISTS idx_activity_events_content_id 
  ON public.activity_events(content_id);

CREATE INDEX IF NOT EXISTS idx_activity_events_group_id 
  ON public.activity_events(group_id);

CREATE INDEX IF NOT EXISTS idx_video_progress_tenant_id 
  ON public.video_progress(tenant_id);

CREATE INDEX IF NOT EXISTS idx_manual_lesson_unlocks_group_id 
  ON public.manual_lesson_unlocks(group_id);

-- 2. Optimize record_activity_event RPC
-- Prevent excessive row locks on public.users by throttling last_activity_at updates to once per 60 seconds
CREATE OR REPLACE FUNCTION public.record_activity_event(
  p_event_type text, 
  p_content_id uuid DEFAULT NULL::uuid, 
  p_group_id uuid DEFAULT NULL::uuid, 
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_tenant_id UUID;
  v_event_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  IF p_event_type NOT IN (
    'login', 'content_opened', 'video_started', 'video_completed',
    'assignment_submitted', 'exam_started', 'exam_submitted'
  ) THEN
    RAISE EXCEPTION 'VALIDATION_ERROR: Invalid event_type %', p_event_type;
  END IF;

  SELECT tenant_id INTO v_tenant_id
  FROM public.users
  WHERE id = v_user_id AND status = 'active';

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  -- Only lock & update user row if more than 60s passed since last update
  UPDATE public.users
  SET last_activity_at = now()
  WHERE id = v_user_id
    AND (last_activity_at IS NULL OR last_activity_at < (now() - INTERVAL '60 seconds'));

  -- Deduplicate: For video_completed, do not insert duplicate events for the same content_id within 10 minutes
  IF p_event_type = 'video_completed' AND p_content_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.activity_events
      WHERE user_id = v_user_id
        AND content_id = p_content_id
        AND event_type = 'video_completed'
        AND created_at > (now() - INTERVAL '10 minutes')
    ) THEN
      -- Already recorded recently; return existing id to remain idempotent
      SELECT id INTO v_event_id
      FROM public.activity_events
      WHERE user_id = v_user_id
        AND content_id = p_content_id
        AND event_type = 'video_completed'
      ORDER BY created_at DESC
      LIMIT 1;

      RETURN v_event_id;
    END IF;
  END IF;

  INSERT INTO public.activity_events (
    tenant_id,
    user_id,
    group_id,
    content_id,
    event_type,
    metadata,
    created_at
  ) VALUES (
    v_tenant_id,
    v_user_id,
    p_group_id,
    p_content_id,
    p_event_type,
    COALESCE(p_metadata, '{}'::jsonb),
    now()
  ) RETURNING id INTO v_event_id;

  RETURN v_event_id;
END;
$function$;

-- 3. Cleanup redundant burst events (retaining earliest valid event per user/content)
DELETE FROM public.activity_events
WHERE event_type = 'video_completed'
  AND id NOT IN (
    SELECT DISTINCT ON (user_id, content_id) id
    FROM public.activity_events
    WHERE event_type = 'video_completed'
    ORDER BY user_id, content_id, created_at ASC
  );
