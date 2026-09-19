-- ============================================================================
-- Migration: 0009_video_playback_rpc.sql
-- Description: Server-side secure authorization and token signing for Bunny Stream video playback.
-- Keeps BUNNY_TOKEN_KEY and signing logic inside PostgreSQL SECURITY DEFINER,
-- eliminating secrets from client-side Flutter binaries.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION public.get_video_playback_url(p_video_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_caller_role text;
  v_caller_status text;
  v_caller_tenant uuid;

  v_video record;
  v_gm_status text;
  v_joined_at timestamptz;

  -- Bunny Stream Vault configuration
  v_library_id text := '747497';
  v_token_key text := 'd472d690-df72-45d1-8233-a5a9a8ccd155';

  v_expires bigint;
  v_hash_input text;
  v_token text;
  v_playback_url text;
BEGIN
  -- 1. Authentication check
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: Caller must be authenticated';
  END IF;

  -- 2. Fetch caller profile
  SELECT role, status, tenant_id
  INTO v_caller_role, v_caller_status, v_caller_tenant
  FROM public.users
  WHERE id = v_caller_id;

  IF v_caller_status IS NULL OR v_caller_status != 'active' THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Active user profile required';
  END IF;

  -- 3. Verify tenant is active
  IF NOT EXISTS (SELECT 1 FROM public.tenants WHERE id = v_caller_tenant AND status = 'active') THEN
    RAISE EXCEPTION 'TENANT_SUSPENDED: Tenant account is not active';
  END IF;

  -- 4. Fetch video and related content & group metadata
  SELECT
    v.id AS video_id,
    v.provider,
    v.provider_video_id,
    v.status AS video_status,
    c.id AS content_id,
    c.group_id,
    c.status AS content_status,
    c.published_at,
    g.previous_content_access,
    g.tenant_id AS group_tenant_id
  INTO v_video
  FROM public.videos v
  JOIN public.content c ON c.id = v.content_id
  JOIN public.groups g ON g.id = c.group_id
  WHERE v.id = p_video_id OR v.content_id = p_video_id
  LIMIT 1;

  IF v_video.video_id IS NULL THEN
    RAISE EXCEPTION 'VIDEO_NOT_FOUND: Video record does not exist';
  END IF;

  -- Verify tenant ownership
  IF v_video.group_tenant_id != v_caller_tenant THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Video belongs to another tenant';
  END IF;

  -- 5. Role-specific authorization checks
  IF v_caller_role = 'student' THEN
    -- A) Content must be published
    IF v_video.content_status != 'published' THEN
      RAISE EXCEPTION 'CONTENT_NOT_PUBLISHED: Video content is not yet published';
    END IF;

    -- B) Video must be ready for streaming
    IF v_video.video_status != 'ready' THEN
      RAISE EXCEPTION 'VIDEO_NOT_READY: Video is currently processing';
    END IF;

    -- C) Student must be an active member of this group
    SELECT status, joined_at
    INTO v_gm_status, v_joined_at
    FROM public.group_members
    WHERE group_id = v_video.group_id AND student_id = v_caller_id;

    IF v_gm_status IS NULL OR v_gm_status != 'active' THEN
      RAISE EXCEPTION 'NOT_AUTHORIZED: You are not an active member of this group';
    END IF;

    -- D) Enforce previous_content_access policy
    IF v_video.published_at IS NOT NULL
       AND v_joined_at > v_video.published_at
       AND v_video.previous_content_access = 'deny' THEN
      RAISE EXCEPTION 'NOT_AUTHORIZED: Access to previous group content is restricted';
    END IF;

  ELSIF v_caller_role = 'parent' THEN
    -- Parent must have an enrolled child in this group
    IF NOT EXISTS (
      SELECT 1 FROM public.parent_students ps
      JOIN public.group_members gm ON gm.student_id = ps.student_id
      WHERE ps.parent_id = v_caller_id
        AND gm.group_id = v_video.group_id
        AND gm.status = 'active'
    ) THEN
      RAISE EXCEPTION 'NOT_AUTHORIZED: No linked child in this group';
    END IF;

  ELSIF v_caller_role != 'teacher' THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Unrecognized role';
  END IF;

  -- 6. Generate time-limited secure tokenized playback URL (2 hours = 7200s)
  v_expires := extract(epoch from (now() + interval '2 hours'))::bigint;
  v_hash_input := v_token_key || v_video.provider_video_id || v_expires::text;
  v_token := encode(digest(v_hash_input, 'sha256'), 'hex');

  v_playback_url := 'https://iframe.mediadelivery.net/embed/'
    || v_library_id || '/' || v_video.provider_video_id
    || '?token=' || v_token
    || '&expires=' || v_expires::text
    || '&autoplay=true&preload=true&responsive=true&playerjs=true';

  -- 7. Record activity event (audit trail)
  INSERT INTO public.activity_events (
    tenant_id,
    user_id,
    group_id,
    content_id,
    event_type,
    metadata
  ) VALUES (
    v_video.group_tenant_id,
    v_caller_id,
    v_video.group_id,
    v_video.content_id,
    'video_started',
    jsonb_build_object(
      'video_id', v_video.video_id,
      'provider_video_id', v_video.provider_video_id,
      'expires_at', v_expires
    )
  );

  RETURN jsonb_build_object(
    'playback_url', v_playback_url,
    'provider_video_id', v_video.provider_video_id,
    'expires_at', v_expires,
    'video_id', v_video.video_id,
    'content_id', v_video.content_id,
    'status', v_video.video_status
  );
END;
$$;
