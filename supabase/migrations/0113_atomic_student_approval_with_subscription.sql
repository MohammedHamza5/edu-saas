-- ============================================================================
-- Migration 0113: Atomic Student Approval with Subscription Duration
-- ============================================================================
-- 1. Updates public.approve_student RPC to accept p_expires_at TIMESTAMPTZ DEFAULT NULL.
-- 2. When teacher approves or activates a student, subscription_expires_at is set
--    atomically within the same database transaction.
-- 3. Logs subscription duration changes to audit_logs.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.approve_student(
  p_student_id UUID,
  p_action TEXT,
  p_expires_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID;
  v_caller_role TEXT;
  v_caller_status TEXT;
  v_caller_tenant UUID;
  v_student_tenant UUID;
  v_student_status TEXT;
  v_student_name TEXT;
  v_old_expires_at TIMESTAMPTZ;
  v_new_status TEXT;
  v_notif_id UUID;
BEGIN
  -- 1. Identify caller
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: Caller is not authenticated';
  END IF;

  -- 2. Validate caller is an active teacher
  SELECT role, status, tenant_id
  INTO v_caller_role, v_caller_status, v_caller_tenant
  FROM public.users
  WHERE id = v_caller_id;

  IF v_caller_role IS NULL OR v_caller_role != 'teacher' OR v_caller_status != 'active' THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only active teachers can perform this action';
  END IF;

  -- 3. Validate tenant is active
  IF NOT EXISTS (SELECT 1 FROM public.tenants WHERE id = v_caller_tenant AND status = 'active') THEN
    RAISE EXCEPTION 'TENANT_SUSPENDED: Tenant is not active';
  END IF;

  -- 4. Map action to status
  IF p_action = 'approve' THEN
    v_new_status := 'active';
  ELSIF p_action = 'reject' THEN
    v_new_status := 'rejected';
  ELSIF p_action = 'suspend' THEN
    v_new_status := 'suspended';
  ELSIF p_action = 'activate' THEN
    v_new_status := 'active';
  ELSE
    RAISE EXCEPTION 'VALIDATION_ERROR: Invalid action %', p_action;
  END IF;

  -- 5. Validate target student exists in same tenant
  SELECT tenant_id, status, full_name, subscription_expires_at
  INTO v_student_tenant, v_student_status, v_student_name, v_old_expires_at
  FROM public.users
  WHERE id = p_student_id;

  IF v_student_tenant IS NULL THEN
    RAISE EXCEPTION 'STUDENT_NOT_FOUND: Student record not found';
  END IF;

  IF v_student_tenant != v_caller_tenant THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Student belongs to another tenant';
  END IF;

  -- 6. Update student status and subscription atomically
  UPDATE public.users
  SET 
    status = v_new_status,
    subscription_expires_at = CASE 
      WHEN p_expires_at IS NOT NULL THEN p_expires_at
      ELSE subscription_expires_at
    END,
    updated_at = NOW()
  WHERE id = p_student_id;

  -- 6b. Auto-confirm email in auth.users so student can immediately log in
  IF p_action IN ('approve', 'activate') THEN
    UPDATE auth.users
    SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
    WHERE id = p_student_id;
  END IF;

  -- 7. Audit log
  INSERT INTO public.audit_logs (tenant_id, actor_user_id, action, entity_type, entity_id, metadata)
  VALUES (
    v_caller_tenant,
    v_caller_id,
    'student_' || p_action,
    'users',
    p_student_id,
    jsonb_build_object(
      'previous_status', v_student_status, 
      'new_status', v_new_status,
      'subscription_expires_at', CASE WHEN p_expires_at IS NOT NULL THEN p_expires_at ELSE v_old_expires_at END
    )
  );

  -- 8. Create notification
  IF p_action IN ('approve', 'reject') THEN
    INSERT INTO public.notifications (tenant_id, title, body, type, data)
    VALUES (
      v_caller_tenant,
      CASE WHEN p_action = 'approve' THEN 'Student Account Approved' ELSE 'Student Account Rejected' END,
      'Student ' || v_student_name || ' has been ' || p_action || 'd.',
      'student_lifecycle',
      jsonb_build_object(
        'student_id', p_student_id, 
        'action', p_action, 
        'actor_id', v_caller_id,
        'subscription_expires_at', CASE WHEN p_expires_at IS NOT NULL THEN p_expires_at ELSE v_old_expires_at END
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'student_id', p_student_id,
    'status', v_new_status,
    'subscription_expires_at', CASE WHEN p_expires_at IS NOT NULL THEN p_expires_at ELSE v_old_expires_at END
  );
END;
$$;

-- Permissions Lockdown
REVOKE ALL ON FUNCTION public.approve_student(UUID, TEXT, TIMESTAMPTZ) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.approve_student(UUID, TEXT, TIMESTAMPTZ) TO authenticated;

COMMENT ON FUNCTION public.approve_student(UUID, TEXT, TIMESTAMPTZ) IS
  'Atomically approves or updates student status and optional subscription expiration duration.';
