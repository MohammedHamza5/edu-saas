-- ============================================================================
-- 0003_approve_student_rpc.sql — Atomic Server-side Student Approval & Lifecycle
-- المصدر: الوثيقة المرجعية الموحدة (الأقسام 3.3، 5.2، 11.3)
-- ============================================================================

create or replace function public.approve_student(
  p_student_id uuid,
  p_action text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller_id uuid;
  v_caller_role text;
  v_caller_status text;
  v_caller_tenant uuid;
  v_student_tenant uuid;
  v_student_status text;
  v_student_name text;
  v_new_status text;
  v_notif_id uuid;
begin
  -- 1. Identify caller
  v_caller_id := auth.uid();
  if v_caller_id is null then
    raise exception 'AUTH_REQUIRED: Caller is not authenticated';
  end if;

  -- 2. Validate caller is an active teacher
  select role, status, tenant_id
  into v_caller_role, v_caller_status, v_caller_tenant
  from public.users
  where id = v_caller_id;

  if v_caller_role is null or v_caller_role != 'teacher' or v_caller_status != 'active' then
    raise exception 'NOT_AUTHORIZED: Only active teachers can perform this action';
  end if;

  -- 3. Validate tenant is active
  if not exists (select 1 from public.tenants where id = v_caller_tenant and status = 'active') then
    raise exception 'TENANT_SUSPENDED: Tenant is not active';
  end if;

  -- 4. Map action to status
  if p_action = 'approve' then
    v_new_status := 'active';
  elsif p_action = 'reject' then
    v_new_status := 'rejected';
  elsif p_action = 'suspend' then
    v_new_status := 'suspended';
  elsif p_action = 'activate' then
    v_new_status := 'active';
  else
    raise exception 'VALIDATION_ERROR: Invalid action %', p_action;
  end if;

  -- 5. Validate target student exists in same tenant
  select tenant_id, status, full_name
  into v_student_tenant, v_student_status, v_student_name
  from public.users
  where id = p_student_id;

  if v_student_tenant is null then
    raise exception 'STUDENT_NOT_FOUND: Student record not found';
  end if;

  if v_student_tenant != v_caller_tenant then
    raise exception 'NOT_AUTHORIZED: Student belongs to another tenant';
  end if;

  -- 6. Update student status
  update public.users
  set status = v_new_status, updated_at = now()
  where id = p_student_id;

  -- 6b. Auto-confirm email in auth.users so student can immediately log in
  if p_action in ('approve', 'activate') then
    update auth.users
    set email_confirmed_at = coalesce(email_confirmed_at, now())
    where id = p_student_id;
  end if;

  -- 7. Audit log
  insert into public.audit_logs (tenant_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    v_caller_tenant,
    v_caller_id,
    'student_' || p_action,
    'users',
    p_student_id,
    jsonb_build_object('previous_status', v_student_status, 'new_status', v_new_status)
  );

  -- 8. Create notification
  if p_action in ('approve', 'reject') then
    insert into public.notifications (tenant_id, title, body, type, data)
    values (
      v_caller_tenant,
      case when p_action = 'approve' then 'تم اعتماد حسابك بنجاح' else 'حالة طلب التسجيل' end,
      case when p_action = 'approve'
        then 'مرحباً بك في المنصة التعليمية! تم قبول طلبك بنجاح ويمكنك الآن تصفح المواد والمجموعات.'
        else 'نأسف لإبلاغك بأنه لم يتم قبول طلب التسجيل في الوقت الحالي.'
      end,
      'important_announcement',
      jsonb_build_object('student_id', p_student_id, 'action', p_action)
    )
    returning id into v_notif_id;

    if v_notif_id is not null then
      insert into public.notification_recipients (notification_id, user_id)
      values (v_notif_id, p_student_id);
    end if;
  end if;

  return jsonb_build_object('ok', true, 'status', v_new_status);
end;
$$;
