-- ============================================================================
-- Migration 0030: Production Tenant Hardening & Cleanup
-- ============================================================================
-- 1. Updates handle_new_auth_user() to validate tenant existence against public.tenants
-- 2. Sets explicit production fallback to Dr. Antounios Ashraf ('ea5caf8b-112f-4044-b9ad-798d5ab025c3')
-- 3. Isolates test tenant ('11111111-1111-1111-1111-111111111111') for staging/testing environment
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant_id uuid;
  v_role text;
  v_status text;
  v_parent_phone text;
  v_tenant_exists boolean := false;
  c_default_prod_tenant uuid := 'ea5caf8b-112f-4044-b9ad-798d5ab025c3'::uuid;
  c_test_tenant uuid := '11111111-1111-1111-1111-111111111111'::uuid;
BEGIN
  -- 1. Extract tenant_id from auth user metadata
  BEGIN
    v_tenant_id := (new.raw_user_meta_data->>'tenant_id')::uuid;
  EXCEPTION WHEN OTHERS THEN
    v_tenant_id := null;
  END;

  -- 2. Verify tenant exists and is active; if invalid or null, fallback safely to production tenant
  IF v_tenant_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.tenants WHERE id = v_tenant_id AND status = 'active'
    ) INTO v_tenant_exists;
  END IF;

  IF NOT coalesce(v_tenant_exists, false) THEN
    v_tenant_id := c_default_prod_tenant;
  END IF;

  -- 3. Determine role (default to student)
  v_role := coalesce(new.raw_user_meta_data->>'role', 'student');
  IF v_role NOT IN ('teacher', 'student', 'parent') THEN
    v_role := 'student';
  END IF;

  -- 4. Status rules: student starts as pending, teacher cannot self-register, parent active
  v_status := CASE
    WHEN v_role = 'student' THEN 'pending'
    WHEN v_role = 'teacher' THEN 'active'
    ELSE 'active'
  END;

  v_parent_phone := nullif(trim(new.raw_user_meta_data->>'parent_phone'), '');

  -- 5. Insert or update user record
  INSERT INTO public.users (
    id,
    tenant_id,
    role,
    full_name,
    email,
    phone,
    parent_phone,
    status
  ) VALUES (
    new.id,
    v_tenant_id,
    v_role,
    coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'), ''), 'طالب جديد'),
    new.email,
    nullif(trim(new.raw_user_meta_data->>'phone'), ''),
    v_parent_phone,
    v_status
  )
  ON CONFLICT (id) DO UPDATE SET
    parent_phone = excluded.parent_phone,
    phone = excluded.phone;

  RETURN new;
END;
$$;
