-- ============================================================================
-- Migration 0006: Add parent_phone column to public.users & update trigger
-- ============================================================================

-- 1. Add parent_phone column to public.users if not exists
alter table public.users add column if not exists parent_phone text;

-- 2. Update trigger function to copy parent_phone from auth metadata
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
  v_role text;
  v_status text;
  v_parent_phone text;
begin
  -- استخراج tenant_id: إما من metadata أو أول tenant متاح (في V1)
  begin
    v_tenant_id := (new.raw_user_meta_data->>'tenant_id')::uuid;
  exception when others then
    select id into v_tenant_id from public.tenants where status = 'active' order by created_at asc limit 1;
  end;

  if v_tenant_id is null then
    select id into v_tenant_id from public.tenants where status = 'active' order by created_at asc limit 1;
  end if;

  -- تحديد الدور
  v_role := coalesce(new.raw_user_meta_data->>'role', 'student');
  if v_role not in ('teacher', 'student', 'parent') then
    v_role := 'student';
  end if;

  -- الطالب يبدأ دائمًا pending؛ المدرس لا يسجل ذاتيًا؛ ولي الأمر active
  v_status := case
    when v_role = 'student' then 'pending'
    when v_role = 'teacher' then 'active'
    else 'active'
  end;

  v_parent_phone := nullif(trim(new.raw_user_meta_data->>'parent_phone'), '');

  insert into public.users (
    id,
    tenant_id,
    role,
    full_name,
    email,
    phone,
    parent_phone,
    status
  ) values (
    new.id,
    v_tenant_id,
    v_role,
    coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'), ''), 'طالب جديد'),
    new.email,
    nullif(trim(new.raw_user_meta_data->>'phone'), ''),
    v_parent_phone,
    v_status
  )
  on conflict (id) do update set
    parent_phone = excluded.parent_phone,
    phone = excluded.phone;

  return new;
end;
$$;
