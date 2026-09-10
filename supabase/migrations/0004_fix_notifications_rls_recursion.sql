-- ============================================================================
-- 0004_fix_notifications_rls_recursion.sql — Fix Mutual RLS Recursion
-- الحل: استخدام دوال SECURITY DEFINER لمنع الاستدعاء التكراري اللانهائي بين
-- public.notifications و public.notification_recipients
-- ============================================================================

-- 1. Helper functions with security definer to eliminate RLS recursion
create or replace function public.user_has_notification(p_notif_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.notification_recipients
    where notification_id = p_notif_id and user_id = p_user_id
  );
$$;

create or replace function public.notification_belongs_to_tenant(p_notif_id uuid, p_tenant_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.notifications
    where id = p_notif_id and tenant_id = p_tenant_id
  );
$$;

-- 2. Drop old recursive policies
drop policy if exists notif_recipient_related on public.notifications;
drop policy if exists nr_teacher_read on public.notification_recipients;
drop policy if exists nr_teacher_insert on public.notification_recipients;

-- 3. Recreate clean non-recursive policies
create policy notif_recipient_related on public.notifications for select to authenticated
  using (public.tenant_is_active() and public.user_has_notification(notifications.id, auth.uid()));

create policy nr_teacher_read on public.notification_recipients for select to authenticated
  using (
    public.has_role('teacher')
    and public.tenant_is_active()
    and public.notification_belongs_to_tenant(notification_recipients.notification_id, public.my_tenant_id())
  );

create policy nr_teacher_insert on public.notification_recipients for insert to authenticated
  with check (
    public.has_role('teacher')
    and public.tenant_is_active()
    and public.notification_belongs_to_tenant(notification_recipients.notification_id, public.my_tenant_id())
    and public.user_belongs_to_my_tenant(notification_recipients.user_id)
  );
