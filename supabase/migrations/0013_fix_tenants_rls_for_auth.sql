-- Migration: 0013_fix_tenants_rls_for_auth.sql
-- Description: Allow authenticated users to read their own tenant metadata and status.
-- Rationale: Previously, tenants_teacher_read and tenants_student_parent_read required
-- tenant_is_active() AND has_role('student') (which required status = 'active').
-- This caused a circular lock:
-- 1. Pending or suspended students could not read their tenant, causing inner joins to fail and return null.
-- 2. If a tenant became suspended, tenant_is_active() returned false, preventing any user from reading
--    tenants.status to know that the tenant is suspended.
-- Replacing both with tenants_read_own scoped strictly to id = public.my_tenant_id().

DROP POLICY IF EXISTS tenants_teacher_read ON public.tenants;
DROP POLICY IF EXISTS tenants_student_parent_read ON public.tenants;
DROP POLICY IF EXISTS tenants_read_own ON public.tenants;

CREATE POLICY tenants_read_own ON public.tenants FOR SELECT TO authenticated
  USING (id = public.my_tenant_id());
