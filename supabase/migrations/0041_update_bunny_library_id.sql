-- Migration 0041: Update Bunny Library ID to 770018
CREATE OR REPLACE FUNCTION public.get_video_playback_url(p_video_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_caller_role text;
  v_caller_status text;
  v_caller_tenant uuid;

  v_video record;
  v_is_authorized boolean := false;
  v_matched_group_id uuid;
  v_enforce_seq boolean := true;

  -- Prerequisite exam checking
  v_prereq_exam_id uuid;
  v_prereq_exam_title text;
  v_passing_score integer;
  v_student_passed boolean := false;

  -- Bunny Stream Vault configuration
  v_library_id text := '770018';
  v_token_key text := 'cbd15974-8efd-4555-af5d-dc2a22a8e96e';

  v_expires bigint;
  v_hash_input text;
  v_token text;
  v_playback_url text;
  v_provider text;
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

  -- 4. Fetch video and content metadata
  SELECT
    v.id AS video_id,
    COALESCE(v.provider, 'bunny') AS provider,
    v.provider_video_id,
    v.status AS video_status,
    c.id AS content_id,
    c.tenant_id AS content_tenant_id,
    c.group_id,
    c.status AS content_status,
    c.sort_order,
    c.published_at,
    c.prerequisite_exam_id
  INTO v_video
  FROM public.videos v
  JOIN public.content c ON c.id = v.content_id
  WHERE v.id = p_video_id OR v.content_id = p_video_id
  LIMIT 1;

  IF v_video.video_id IS NULL THEN
    RAISE EXCEPTION 'VIDEO_NOT_FOUND: Video record does not exist';
  END IF;

  IF v_video.provider_video_id IS NULL OR length(trim(v_video.provider_video_id)) = 0 THEN
    RAISE EXCEPTION 'VIDEO_NOT_READY: Video has not been uploaded or linked yet';
  END IF;

  -- Verify tenant ownership
  IF v_video.content_tenant_id != v_caller_tenant THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Video belongs to another tenant';
  END IF;

  -- 5. Role-specific authorization checks
  IF v_caller_role = 'teacher' THEN
    -- Teacher always has access to their tenant videos
    v_is_authorized := true;

  ELSIF v_caller_role = 'student' THEN
    -- A) Content must be published
    IF v_video.content_status != 'published' THEN
      RAISE EXCEPTION 'CONTENT_NOT_PUBLISHED: Video content is not yet published';
    END IF;

    -- B) Video must be ready
    IF v_video.video_status != 'ready' THEN
      RAISE EXCEPTION 'VIDEO_NOT_READY: Video is currently processing';
    END IF;

    -- C) Check active membership in primary group OR any junction group
    SELECT g.id, g.enforce_sequential_learning INTO v_matched_group_id, v_enforce_seq
    FROM public.groups g
    JOIN public.group_members gm ON gm.group_id = g.id
    WHERE gm.student_id = v_caller_id
      AND gm.status = 'active'
      AND (
        g.id = v_video.group_id
        OR EXISTS (
          SELECT 1 FROM public.content_groups cg
          WHERE cg.content_id = v_video.content_id AND cg.group_id = g.id
        )
      )
      AND (
        v_video.published_at IS NULL
        OR gm.joined_at <= v_video.published_at
        OR g.previous_content_access = 'allow'
      )
    LIMIT 1;

    IF v_matched_group_id IS NULL THEN
      RAISE EXCEPTION 'NOT_AUTHORIZED: You are not an active member of any group authorized to view this video';
    END IF;

    -- D) Strict Prerequisite Exam Lock:
    v_prereq_exam_id := v_video.prerequisite_exam_id;

    IF v_prereq_exam_id IS NULL AND v_enforce_seq IS TRUE AND v_video.sort_order > 0 THEN
      SELECT COALESCE(prev_c.associated_exam_id, e.id)
      INTO v_prereq_exam_id
      FROM public.content prev_c
      LEFT JOIN public.exams e ON e.content_id = prev_c.id
      WHERE (
        prev_c.group_id = v_matched_group_id
        OR EXISTS (
          SELECT 1 FROM public.content_groups cg
          WHERE cg.content_id = prev_c.id AND cg.group_id = v_matched_group_id
        )
      )
      AND prev_c.sort_order < v_video.sort_order
      AND prev_c.status = 'published'
      AND (prev_c.associated_exam_id IS NOT NULL OR e.id IS NOT NULL)
      ORDER BY prev_c.sort_order DESC
      LIMIT 1;
    END IF;

    IF v_prereq_exam_id IS NOT NULL THEN
      SELECT e.passing_score, c_exam.title
      INTO v_passing_score, v_prereq_exam_title
      FROM public.exams e
      JOIN public.content c_exam ON c_exam.id = e.content_id
      WHERE e.id = v_prereq_exam_id;

      v_passing_score := COALESCE(v_passing_score, 60);

      SELECT EXISTS (
        SELECT 1 FROM public.exam_attempts ea
        WHERE ea.exam_id = v_prereq_exam_id
          AND ea.student_id = v_caller_id
          AND ea.status = 'submitted'
          AND (
            ea.score >= v_passing_score
            OR ea.percentage >= v_passing_score
          )
      ) INTO v_student_passed;

      IF NOT v_student_passed THEN
        RAISE EXCEPTION 'PREREQUISITE_EXAM_NOT_PASSED: You must pass the exam "%" before accessing this lecture',
          COALESCE(v_prereq_exam_title, 'Previous Lesson Exam');
      END IF;
    END IF;

    v_is_authorized := true;

  ELSIF v_caller_role = 'parent' THEN
    SELECT g.id INTO v_matched_group_id
    FROM public.groups g
    JOIN public.group_members gm ON gm.group_id = g.id
    JOIN public.parent_students ps ON ps.student_id = gm.student_id AND ps.parent_id = v_caller_id
    WHERE gm.status = 'active'
      AND (
        g.id = v_video.group_id
        OR EXISTS (
          SELECT 1 FROM public.content_groups cg
          WHERE cg.content_id = v_video.content_id AND cg.group_id = g.id
        )
      )
    LIMIT 1;

    IF v_matched_group_id IS NOT NULL THEN
      v_is_authorized := true;
    ELSE
      RAISE EXCEPTION 'NOT_AUTHORIZED: No linked child has access to this group video';
    END IF;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Access denied';
  END IF;

  -- 6. Generate playback URL
  v_provider := lower(trim(v_video.provider));

  IF v_provider = 'youtube' THEN
    v_playback_url := 'https://www.youtube-nocookie.com/embed/' || v_video.provider_video_id || '?enablejsapi=1&rel=0&modestbranding=1&iv_load_policy=3&controls=1';

    INSERT INTO public.audit_logs (tenant_id, user_id, action, resource_type, resource_id, metadata)
    VALUES (
      v_caller_tenant,
      v_caller_id,
      'video_playback_authorized',
      'videos',
      v_video.video_id,
      jsonb_build_object(
        'provider', 'youtube',
        'youtube_id', v_video.provider_video_id,
        'caller_role', v_caller_role
      )
    );

    RETURN jsonb_build_object(
      'video_id', v_video.video_id,
      'provider', 'youtube',
      'playback_url', v_playback_url,
      'expires_at', null,
      'watermark_student_id', v_caller_id
    );

  ELSE
    v_expires := extract(epoch from (now() + interval '4 hours'))::bigint;
    v_hash_input := v_token_key || v_video.provider_video_id || v_expires::text;
    v_token := encode(digest(v_hash_input, 'sha256'), 'hex');

    v_playback_url := 'https://iframe.mediadelivery.net/embed/'
      || v_library_id || '/' || v_video.provider_video_id
      || '?token=' || v_token
      || '&expires=' || v_expires::text
      || '&autoplay=false&preload=true';

    INSERT INTO public.audit_logs (tenant_id, user_id, action, resource_type, resource_id, metadata)
    VALUES (
      v_caller_tenant,
      v_caller_id,
      'video_playback_authorized',
      'videos',
      v_video.video_id,
      jsonb_build_object(
        'provider', 'bunny',
        'expires', v_expires,
        'caller_role', v_caller_role
      )
    );

    RETURN jsonb_build_object(
      'video_id', v_video.video_id,
      'provider', 'bunny',
      'playback_url', v_playback_url,
      'expires_at', v_expires,
      'watermark_student_id', v_caller_id
    );
  END IF;
END;
$$;
