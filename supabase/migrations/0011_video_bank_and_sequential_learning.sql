-- ============================================================================
-- Migration: 0011_video_bank_and_sequential_learning.sql
-- Description:
-- 1. Adds video_provider column to public.tenants (defaults to 'youtube').
-- 2. Makes public.content.group_id nullable for Central Video Bank storage.
-- 3. Adds associated_exam_id and prerequisite_exam_id to public.content for all-in-one lesson units.
-- 4. Adds enforce_sequential_learning column to public.groups (defaults to true).
-- 5. Creates public.content_groups junction table for multi-group distribution.
-- 6. Updates get_video_playback_url to strictly enforce prerequisite exam passing before playback.
-- 7. Adds atomic RPC public.assign_content_to_groups.
-- ============================================================================

-- 1. Tenant video provider configuration
ALTER TABLE public.tenants
ADD COLUMN IF NOT EXISTS video_provider text NOT NULL DEFAULT 'youtube'
CHECK (video_provider IN ('youtube', 'bunny'));

UPDATE public.tenants
SET video_provider = 'youtube'
WHERE video_provider IS NULL OR video_provider = '';

-- 2. Groups sequential progression configuration
ALTER TABLE public.groups
ADD COLUMN IF NOT EXISTS enforce_sequential_learning boolean NOT NULL DEFAULT true;

-- 3. Content table schema evolution
ALTER TABLE public.content
ALTER COLUMN group_id DROP NOT NULL;

ALTER TABLE public.content
ADD COLUMN IF NOT EXISTS associated_exam_id uuid REFERENCES public.exams(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS prerequisite_exam_id uuid REFERENCES public.exams(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_content_associated_exam ON public.content(associated_exam_id);
CREATE INDEX IF NOT EXISTS idx_content_prerequisite_exam ON public.content(prerequisite_exam_id);

-- Add title column directly on public.exams for unified querying
ALTER TABLE public.exams ADD COLUMN IF NOT EXISTS title text;

UPDATE public.exams e 
SET title = c.title 
FROM public.content c 
WHERE e.content_id = c.id;

CREATE OR REPLACE FUNCTION public.trg_sync_exam_title()
RETURNS trigger AS $$
BEGIN
  IF TG_TABLE_NAME = 'exams' THEN
    SELECT title INTO NEW.title FROM public.content WHERE id = NEW.content_id;
  ELSIF TG_TABLE_NAME = 'content' THEN
    UPDATE public.exams SET title = NEW.title WHERE content_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_exams_sync_title ON public.exams;
CREATE TRIGGER trg_exams_sync_title
BEFORE INSERT OR UPDATE OF content_id ON public.exams
FOR EACH ROW EXECUTE FUNCTION public.trg_sync_exam_title();

DROP TRIGGER IF EXISTS trg_content_sync_exam_title ON public.content;
CREATE TRIGGER trg_content_sync_exam_title
AFTER UPDATE OF title ON public.content
FOR EACH ROW EXECUTE FUNCTION public.trg_sync_exam_title();

-- 4. Multi-group junction table
CREATE TABLE IF NOT EXISTS public.content_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  content_id uuid NOT NULL REFERENCES public.content(id) ON DELETE CASCADE,
  group_id uuid NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT content_groups_unique UNIQUE (content_id, group_id)
);

CREATE INDEX IF NOT EXISTS idx_content_groups_content ON public.content_groups(content_id);
CREATE INDEX IF NOT EXISTS idx_content_groups_group ON public.content_groups(group_id);
CREATE INDEX IF NOT EXISTS idx_content_groups_tenant ON public.content_groups(tenant_id);

-- Enable RLS on content_groups
ALTER TABLE public.content_groups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS content_groups_teacher_all ON public.content_groups;
CREATE POLICY content_groups_teacher_all ON public.content_groups
  FOR ALL TO authenticated
  USING (public.has_role('teacher') AND public.tenant_is_active() AND tenant_id = public.my_tenant_id())
  WITH CHECK (public.has_role('teacher') AND public.tenant_is_active() AND tenant_id = public.my_tenant_id());

DROP POLICY IF EXISTS content_groups_student_read ON public.content_groups;
CREATE POLICY content_groups_student_read ON public.content_groups
  FOR SELECT TO authenticated
  USING (
    public.has_role('student') AND public.tenant_is_active() AND EXISTS (
      SELECT 1 FROM public.group_members gm
      WHERE gm.group_id = content_groups.group_id
        AND gm.student_id = auth.uid()
        AND gm.status = 'active'
    )
  );

DROP POLICY IF EXISTS content_groups_parent_read ON public.content_groups;
CREATE POLICY content_groups_parent_read ON public.content_groups
  FOR SELECT TO authenticated
  USING (
    public.has_role('parent') AND public.tenant_is_active() AND EXISTS (
      SELECT 1 FROM public.group_members gm
      JOIN public.parent_students ps ON ps.student_id = gm.student_id AND ps.parent_id = auth.uid()
      WHERE gm.group_id = content_groups.group_id
        AND gm.status = 'active'
    )
  );

-- 5. Update public.content student read policy
DROP POLICY IF EXISTS content_student_read_published ON public.content;

CREATE POLICY content_student_read_published ON public.content
  FOR SELECT TO authenticated
  USING (
    public.has_role('student') AND public.tenant_is_active() AND status = 'published' AND (
      (group_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.group_members gm
        WHERE gm.student_id = auth.uid() AND gm.group_id = content.group_id AND gm.status = 'active'
          AND (gm.joined_at <= content.published_at OR (
            SELECT g.previous_content_access FROM public.groups g WHERE g.id = content.group_id) = 'allow')
      ))
      OR
      EXISTS (
        SELECT 1 FROM public.content_groups cg
        JOIN public.group_members gm ON gm.group_id = cg.group_id
        WHERE cg.content_id = content.id AND gm.student_id = auth.uid() AND gm.status = 'active'
          AND (gm.joined_at <= content.published_at OR (
            SELECT g.previous_content_access FROM public.groups g WHERE g.id = cg.group_id) = 'allow')
      )
    )
  );

-- 6. Atomic RPC to assign content to one or more groups
CREATE OR REPLACE FUNCTION public.assign_content_to_groups(
  p_content_id uuid,
  p_group_ids uuid[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_caller_tenant uuid;
  v_content_tenant uuid;
  v_target_group_id uuid;
  v_primary_group uuid := NULL;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: Caller must be authenticated';
  END IF;

  SELECT tenant_id INTO v_caller_tenant
  FROM public.users
  WHERE id = v_caller_id AND role = 'teacher' AND status = 'active';

  IF v_caller_tenant IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only active teachers can assign content to groups';
  END IF;

  SELECT tenant_id INTO v_content_tenant
  FROM public.content
  WHERE id = p_content_id;

  IF v_content_tenant IS NULL THEN
    RAISE EXCEPTION 'CONTENT_NOT_FOUND: Content record does not exist';
  END IF;

  IF v_content_tenant != v_caller_tenant THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Content belongs to another tenant';
  END IF;

  -- Delete existing group junction entries for this content
  DELETE FROM public.content_groups
  WHERE content_id = p_content_id;

  -- If groups provided, insert new junction entries and update primary group_id
  IF p_group_ids IS NOT NULL AND array_length(p_group_ids, 1) > 0 THEN
    v_primary_group := p_group_ids[1];

    FOREACH v_target_group_id IN ARRAY p_group_ids
    LOOP
      IF EXISTS (SELECT 1 FROM public.groups WHERE id = v_target_group_id AND tenant_id = v_caller_tenant) THEN
        INSERT INTO public.content_groups (tenant_id, content_id, group_id)
        VALUES (v_caller_tenant, p_content_id, v_target_group_id)
        ON CONFLICT (content_id, group_id) DO NOTHING;
      END IF;
    END LOOP;
  END IF;

  -- Update primary group_id on content
  UPDATE public.content
  SET group_id = v_primary_group,
      updated_at = now()
  WHERE id = p_content_id;

  RETURN jsonb_build_object(
    'success', true,
    'content_id', p_content_id,
    'primary_group_id', v_primary_group,
    'assigned_count', COALESCE(array_length(p_group_ids, 1), 0)
  );
END;
$$;

-- 7. High-Integrity Playback Authorization: Checks group membership AND prerequisite exam passing
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
  v_is_authorized boolean := false;
  v_matched_group_id uuid;
  v_enforce_seq boolean := true;

  -- Prerequisite exam checking
  v_prereq_exam_id uuid;
  v_prereq_exam_title text;
  v_passing_score integer;
  v_student_passed boolean := false;

  -- Bunny Stream Vault configuration
  v_library_id text := '747497';
  v_token_key text := 'd472d690-df72-45d1-8233-a5a9a8ccd155';

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
    -- Determine if there is an explicit prerequisite_exam_id, OR if sequential progression requires passing the previous lesson's exam
    v_prereq_exam_id := v_video.prerequisite_exam_id;

    -- If no explicit prerequisite_exam_id, but group enforces sequential learning:
    IF v_prereq_exam_id IS NULL AND v_enforce_seq IS TRUE AND v_video.sort_order > 0 THEN
      -- Find the exam associated with the immediately preceding lesson in this group
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

    -- If a prerequisite exam exists, verify that student has passed it
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
