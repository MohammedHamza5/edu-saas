-- ============================================================================
-- Migration 0032: Automatic Notifications System
-- Dispatches notifications to students & parents on critical lifecycle events:
-- 1. New lecture / material published (new_content)
-- 2. New exam published (exam_published)
-- 3. New assignment created (assignment_created)
-- 4. Assignment graded (assignment_reviewed)
-- 5. Attendance marked (attendance_marked)
-- 6. Exam result available (exam_result)
-- ============================================================================

-- 1. RPC to dispatch group notification to all active students + parents
CREATE OR REPLACE FUNCTION public.dispatch_group_notification(
  p_group_id uuid,
  p_title text,
  p_body text,
  p_type text,
  p_data jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_tenant_id uuid;
  v_notif_id uuid;
  v_student_ids uuid[];
  v_parent_ids uuid[];
  v_all_recipient_ids uuid[];
BEGIN
  -- Derive tenant_id from group
  SELECT tenant_id INTO v_tenant_id
  FROM public.groups
  WHERE id = p_group_id;

  IF v_tenant_id IS NULL THEN
    -- Fallback to caller's tenant
    SELECT tenant_id INTO v_tenant_id
    FROM public.users
    WHERE id = auth.uid();
  END IF;

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'NOT_FOUND: Tenant could not be resolved for group %', p_group_id;
  END IF;

  -- 1. Insert notification record
  INSERT INTO public.notifications (tenant_id, title, body, type, data)
  VALUES (
    v_tenant_id,
    p_title,
    p_body,
    p_type,
    COALESCE(p_data, '{}'::jsonb) || jsonb_build_object('group_id', p_group_id)
  )
  RETURNING id INTO v_notif_id;

  -- 2. Gather active student IDs in this group
  SELECT array_agg(student_id) INTO v_student_ids
  FROM public.group_members
  WHERE group_id = p_group_id AND status = 'active';

  -- 3. Gather parent IDs linked to these students
  IF v_student_ids IS NOT NULL AND array_length(v_student_ids, 1) > 0 THEN
    SELECT array_agg(DISTINCT parent_id) INTO v_parent_ids
    FROM public.parent_students
    WHERE student_id = ANY(v_student_ids);

    -- Combine unique recipients (students + parents)
    SELECT array_agg(DISTINCT uid) INTO v_all_recipient_ids
    FROM (
      SELECT unnest(v_student_ids) AS uid
      UNION
      SELECT unnest(COALESCE(v_parent_ids, ARRAY[]::uuid[])) AS uid
    ) combined;

    -- 4. Batch insert into notification_recipients
    IF v_all_recipient_ids IS NOT NULL AND array_length(v_all_recipient_ids, 1) > 0 THEN
      INSERT INTO public.notification_recipients (notification_id, user_id)
      SELECT v_notif_id, uid
      FROM unnest(v_all_recipient_ids) AS uid
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;

  RETURN v_notif_id;
END;
$$;

-- 2. RPC to dispatch user notification directly (student or parent)
CREATE OR REPLACE FUNCTION public.dispatch_user_notification(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_type text,
  p_data jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_tenant_id uuid;
  v_notif_id uuid;
  v_parent_ids uuid[];
  v_all_recipient_ids uuid[];
BEGIN
  -- Derive tenant_id from target user
  SELECT tenant_id INTO v_tenant_id
  FROM public.users
  WHERE id = p_user_id;

  IF v_tenant_id IS NULL THEN
    SELECT tenant_id INTO v_tenant_id
    FROM public.users
    WHERE id = auth.uid();
  END IF;

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'NOT_FOUND: User % not found', p_user_id;
  END IF;

  -- 1. Insert notification record
  INSERT INTO public.notifications (tenant_id, title, body, type, data)
  VALUES (
    v_tenant_id,
    p_title,
    p_body,
    p_type,
    COALESCE(p_data, '{}'::jsonb) || jsonb_build_object('target_user_id', p_user_id)
  )
  RETURNING id INTO v_notif_id;

  -- 2. Also find parents if target is a student
  SELECT array_agg(DISTINCT parent_id) INTO v_parent_ids
  FROM public.parent_students
  WHERE student_id = p_user_id;

  SELECT array_agg(DISTINCT uid) INTO v_all_recipient_ids
  FROM (
    SELECT p_user_id AS uid
    UNION
    SELECT unnest(COALESCE(v_parent_ids, ARRAY[]::uuid[])) AS uid
  ) combined;

  -- 3. Batch insert
  INSERT INTO public.notification_recipients (notification_id, user_id)
  SELECT v_notif_id, uid
  FROM unnest(v_all_recipient_ids) AS uid
  ON CONFLICT DO NOTHING;

  RETURN v_notif_id;
END;
$$;
