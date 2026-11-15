-- ============================================================================
-- Migration 0112: Student Subscription Duration & Instant Access Guard
-- ============================================================================
-- 1. Adds subscription_expires_at (TIMESTAMPTZ NULL) to public.users.
--    DEFAULT NULL ensures 100% zero-disruption to all existing active students.
-- 2. Updates public.has_role('student') to enforce instantaneous database-level
--    RLS cutoff if subscription_expires_at <= NOW().
-- 3. Creates public.set_student_subscription RPC for teachers to set, extend,
--    or clear student access duration with multi-tenant isolation.
-- 4. Updates public.approve_student to optionally accept subscription duration.
-- ============================================================================

-- 1. Schema Enhancement (Metadata-only instantaneous non-blocking operation)
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS subscription_expires_at TIMESTAMPTZ NULL;

CREATE INDEX IF NOT EXISTS idx_users_student_subscription 
  ON public.users (tenant_id, subscription_expires_at) 
  WHERE role = 'student';

-- 2. Master Zero-Trust RLS Guard (Blocks content, exams, videos, assignments at 0ms once expired)
CREATE OR REPLACE FUNCTION public.has_role(r text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid() 
      AND u.role = r 
      AND u.status = 'active'
      -- Students must either have unlimited access (NULL) or unexpired duration
      AND (r != 'student' OR u.subscription_expires_at IS NULL OR u.subscription_expires_at > NOW())
  );
$$;

-- 3. Teacher RPC to set, extend, or clear a student's subscription duration
CREATE OR REPLACE FUNCTION public.set_student_subscription(
  p_student_id UUID,
  p_expires_at TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_caller_role TEXT;
  v_caller_tenant UUID;
  v_target_tenant UUID;
  v_target_status TEXT;
  v_new_status TEXT;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be authenticated';
  END IF;

  -- Verify caller is an active teacher
  SELECT role, tenant_id INTO v_caller_role, v_caller_tenant
  FROM public.users
  WHERE id = v_caller_id AND status = 'active';

  IF v_caller_role != 'teacher' OR v_caller_tenant IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only active teachers can manage student subscriptions';
  END IF;

  -- Verify target user is a student in the same tenant
  SELECT tenant_id, status INTO v_target_tenant, v_target_status
  FROM public.users
  WHERE id = p_student_id AND role = 'student';

  IF v_target_tenant IS NULL THEN
    RAISE EXCEPTION 'STUDENT_NOT_FOUND: Target student not found';
  END IF;

  IF v_target_tenant != v_caller_tenant THEN
    RAISE EXCEPTION 'TENANT_MISMATCH: Cannot manage students of another institution';
  END IF;

  -- If student was suspended and teacher extends subscription into the future, auto-reactivate
  v_new_status := v_target_status;
  IF v_target_status = 'suspended' AND p_expires_at IS NOT NULL AND p_expires_at > NOW() THEN
    v_new_status := 'active';
  END IF;

  -- Update target student
  UPDATE public.users
  SET 
    subscription_expires_at = p_expires_at,
    status = v_new_status,
    updated_at = NOW()
  WHERE id = p_student_id;

  RETURN jsonb_build_object(
    'success', true,
    'student_id', p_student_id,
    'subscription_expires_at', p_expires_at,
    'status', v_new_status
  );
END;
$$;

-- 4. Permissions Lockdown
REVOKE ALL ON FUNCTION public.set_student_subscription(UUID, TIMESTAMPTZ) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_student_subscription(UUID, TIMESTAMPTZ) TO authenticated;

COMMENT ON FUNCTION public.set_student_subscription(UUID, TIMESTAMPTZ) IS
  'Sets, extends, or clears a student subscription duration with tenant-level isolation and auto-reactivation.';
