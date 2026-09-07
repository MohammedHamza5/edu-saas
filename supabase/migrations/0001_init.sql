-- ============================================================================
-- 0001_init.sql — Education SaaS V1 · Full Schema + RLS
-- المصدر: الوثيقة المرجعية الموحدة (الأقسام 4 و5) + rules/02-data-model.md
-- مبادئ: uuid PK · timestamptz UTC · statuses من نوع text (بلا ENUM صارم)
--        · لا Hard Delete للبيانات الأكاديمية · RLS مفعّل على كل جدول
-- ملاحظة: يُطبَّق على بيئة Development أولًا ثم Production عبر نفس الملف.
-- ============================================================================

-- ---------- 1) الجداول ----------

create table public.tenants (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  logo_url   text,
  email      text,
  phone      text,
  status     text not null default 'active' check (status in ('active','suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.users (
  id              uuid primary key references auth.users(id) on delete cascade,
  tenant_id       uuid not null references public.tenants(id),
  role            text not null check (role in ('teacher','student','parent')),
  full_name       text not null,
  email           text,
  phone           text,
  avatar_url      text,
  status          text not null default 'pending' check (status in ('pending','active','rejected','suspended')),
  last_activity_at timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create table public.groups (
  id                      uuid primary key default gen_random_uuid(),
  tenant_id               uuid not null references public.tenants(id),
  name                    text not null,
  level                   text,
  description             text,
  previous_content_access text not null default 'deny' check (previous_content_access in ('allow','deny')),
  status                  text not null default 'active' check (status in ('active','archived')),
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

create table public.group_members (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid not null references public.groups(id),
  student_id uuid not null references public.users(id),
  joined_at  timestamptz not null default now(),
  status     text not null default 'active' check (status in ('active','removed')),
  constraint group_members_unique unique (group_id, student_id)
);

create table public.parent_students (
  id           uuid primary key default gen_random_uuid(),
  parent_id    uuid not null references public.users(id),
  student_id   uuid not null references public.users(id),
  relationship text,
  created_at   timestamptz not null default now(),
  constraint parent_students_unique unique (parent_id, student_id)
);

create table public.content (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references public.tenants(id),
  group_id     uuid not null references public.groups(id),
  title        text not null,
  description  text,
  type         text not null check (type in ('video','pdf','image','assignment','exam')),
  status       text not null default 'draft' check (status in ('draft','published','archived')),
  sort_order   integer not null default 0,
  published_at timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table public.files (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references public.tenants(id),
  content_id   uuid references public.content(id),
  storage_path text not null,
  file_name    text not null,
  mime_type    text not null,
  file_size    integer not null default 0,
  created_at   timestamptz not null default now()
);

create table public.videos (
  id                uuid primary key default gen_random_uuid(),
  content_id        uuid not null references public.content(id),
  provider          text not null default 'bunny',
  provider_video_id text,
  thumbnail_url     text,
  duration          integer,
  status            text not null default 'uploading' check (status in ('uploading','processing','ready','failed','deleted')),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create table public.assignments (
  id                    uuid primary key default gen_random_uuid(),
  content_id            uuid not null references public.content(id),
  tenant_id             uuid not null references public.tenants(id),
  instructions          text,
  due_at                timestamptz,
  allow_late_submission boolean not null default false,
  max_score             integer not null default 100,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create table public.assignment_submissions (
  id               uuid primary key default gen_random_uuid(),
  assignment_id    uuid not null references public.assignments(id),
  student_id       uuid not null references public.users(id),
  attempt_number   integer not null default 1,
  submitted_at     timestamptz not null default now(),
  status           text not null default 'submitted' check (status in ('submitted','reviewed','late')),
  score            integer,
  teacher_feedback text,
  reviewed_at      timestamptz,
  reviewed_by      uuid references public.users(id),
  constraint assignment_submissions_unique unique (assignment_id, student_id, attempt_number)
);

create table public.submission_files (
  id           uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.assignment_submissions(id),
  storage_path text not null,
  file_name    text not null,
  mime_type    text not null,
  file_size    integer not null default 0,
  created_at   timestamptz not null default now()
);

create table public.exams (
  id                uuid primary key default gen_random_uuid(),
  content_id        uuid not null references public.content(id),
  tenant_id         uuid not null references public.tenants(id),
  duration_minutes  integer not null default 60,
  max_score         integer not null default 100,
  passing_score     integer,
  shuffle_questions boolean not null default false,
  show_result       boolean not null default true,
  allow_retake      boolean not null default false,
  start_at          timestamptz,
  end_at            timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create table public.exam_versions (
  id             uuid primary key default gen_random_uuid(),
  exam_id        uuid not null references public.exams(id),
  version_number integer not null default 1,
  status         text not null default 'draft' check (status in ('draft','published','archived')),
  created_at     timestamptz not null default now(),
  published_at   timestamptz
);

create table public.exam_questions (
  id              uuid primary key default gen_random_uuid(),
  exam_version_id uuid not null references public.exam_versions(id),
  question_text   text not null,
  question_type   text not null check (question_type in ('multiple_choice','true_false')),
  points          integer not null default 1,
  sort_order      integer not null default 0
);

create table public.question_options (
  id          uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.exam_questions(id),
  option_text text not null,
  sort_order  integer not null default 0,
  is_correct  boolean not null default false
);

create table public.exam_attempts (
  id              uuid primary key default gen_random_uuid(),
  exam_id         uuid not null references public.exams(id),
  exam_version_id uuid not null references public.exam_versions(id),
  student_id      uuid not null references public.users(id),
  started_at      timestamptz not null default now(),
  submitted_at    timestamptz,
  status          text not null default 'in_progress' check (status in ('in_progress','submitted','expired')),
  score           integer,
  percentage      numeric(5,2)
);

create table public.exam_answers (
  id                uuid primary key default gen_random_uuid(),
  attempt_id        uuid not null references public.exam_attempts(id),
  question_id       uuid not null references public.exam_questions(id),
  selected_option_id uuid references public.question_options(id),
  is_correct        boolean,
  points_earned     numeric(8,2),
  answered_at       timestamptz not null default now()
);

create table public.attendance (
  id         uuid primary key default gen_random_uuid(),
  tenant_id  uuid not null references public.tenants(id),
  group_id   uuid not null references public.groups(id),
  student_id uuid not null references public.users(id),
  date       date not null,
  status     text not null check (status in ('present','absent','late','excused')),
  marked_at  timestamptz not null default now(),
  marked_by  uuid references public.users(id),
  note       text,
  constraint attendance_unique unique (group_id, student_id, date)
);

create table public.activity_events (
  id         uuid primary key default gen_random_uuid(),
  tenant_id  uuid not null references public.tenants(id),
  user_id    uuid not null references public.users(id),
  group_id   uuid references public.groups(id),
  content_id uuid references public.content(id),
  event_type text not null check (event_type in
    ('login','content_opened','video_started','video_completed','assignment_submitted','exam_started','exam_submitted')),
  metadata   jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.video_progress (
  id               uuid primary key default gen_random_uuid(),
  tenant_id        uuid not null references public.tenants(id),
  video_id         uuid not null references public.videos(id),
  student_id       uuid not null references public.users(id),
  progress_seconds integer not null default 0,
  duration_seconds integer not null default 0,
  percentage       numeric(5,2) not null default 0,
  completed        boolean not null default false,
  last_watched_at  timestamptz not null default now(),
  constraint video_progress_unique unique (video_id, student_id)
);

create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  tenant_id  uuid not null references public.tenants(id),
  title      text not null,
  body       text not null,
  type       text not null check (type in
    ('new_content','assignment_created','assignment_due','assignment_reviewed','exam_published','exam_result','attendance_marked','important_announcement')),
  data       jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.notification_recipients (
  id              uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications(id),
  user_id         uuid not null references public.users(id),
  read_at         timestamptz, -- NULL = غير مقروء
  created_at      timestamptz not null default now()
);

create table public.user_devices (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.users(id),
  platform     text not null check (platform in ('android','ios','web')),
  push_token   text not null,
  is_active    boolean not null default true,
  last_seen_at timestamptz,
  created_at   timestamptz not null default now()
);

create table public.audit_logs (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null references public.tenants(id),
  actor_user_id uuid references public.users(id),
  action        text not null,
  entity_type   text not null,
  entity_id     uuid,
  metadata      jsonb not null default '{}'::jsonb,
  created_at    timestamptz not null default now()
);

-- ---------- 2) دوال مساعدة (Security Definer + search_path مقفل) ----------
create or replace function public.my_tenant_id()
returns uuid language plpgsql stable security definer set search_path = public as $$
declare
  v_tenant_id uuid;
begin
  select tenant_id into v_tenant_id from public.users where id = auth.uid();
  return v_tenant_id;
end;
$$;

create or replace function public.has_role(r text)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare
  v_exists boolean;
begin
  select exists (
    select 1 from public.users u
    where u.id = auth.uid() and u.role = r and u.status = 'active'
  ) into v_exists;
  return v_exists;
end;
$$;

create or replace function public.tenant_is_active()
returns boolean language plpgsql stable security definer set search_path = public as $$
declare
  v_active boolean;
begin
  select exists (
    select 1 from public.users u
    join public.tenants t on t.id = u.tenant_id
    where u.id = auth.uid() and t.status = 'active'
  ) into v_active;
  return v_active;
end;
$$;

-- منع تعديل الحقول المحمية يدويًا (role / tenant_id / id) عبر Update مباشر
create or replace function public.prevent_identity_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.id      is distinct from old.id or
     new.role    is distinct from old.role or
     new.tenant_id is distinct from old.tenant_id then
    raise exception 'identity fields (id, role, tenant_id) cannot be changed directly';
  end if;
  return new;
end $$;

-- فحص العلاقة بين ولي الأمر والطالب بدون استدعاء RLS متكرر
create or replace function public.is_parent_of_student(p_parent_id uuid, p_student_id uuid)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare
  v_exists boolean;
begin
  select exists (
    select 1 from public.parent_students ps 
    where ps.parent_id = p_parent_id and ps.student_id = p_student_id
  ) into v_exists;
  return v_exists;
end;
$$;

-- فحص انتماء المستخدم لنفس الـ Tenant للمدرس الحالي
create or replace function public.user_belongs_to_my_tenant(p_user_id uuid)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare
  v_exists boolean;
begin
  select exists (
    select 1 from public.users u 
    where u.id = p_user_id and u.tenant_id = public.my_tenant_id()
  ) into v_exists;
  return v_exists;
end;
$$;

-- فحص عضوية الطالب النشطة في المجموعة
create or replace function public.is_member_of_group(p_group_id uuid, p_student_id uuid)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare
  v_exists boolean;
begin
  select exists (
    select 1 from public.group_members gm 
    where gm.group_id = p_group_id and gm.student_id = p_student_id and gm.status = 'active'
  ) into v_exists;
  return v_exists;
end;
$$;

-- فحص انتماء المجموعة لنفس الـ Tenant للمدرس الحالي
create or replace function public.group_belongs_to_my_tenant(p_group_id uuid)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare
  v_exists boolean;
begin
  select exists (
    select 1 from public.groups g 
    where g.id = p_group_id and g.tenant_id = public.my_tenant_id()
  ) into v_exists;
  return v_exists;
end;
$$;

-- فحص امتلاك ولي الأمر لطالب داخل المجموعة
create or replace function public.parent_has_child_in_group(p_parent_id uuid, p_group_id uuid)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare
  v_exists boolean;
begin
  select exists (
    select 1 from public.group_members gm
    join public.parent_students ps on ps.student_id = gm.student_id and ps.parent_id = p_parent_id
    where gm.group_id = p_group_id and gm.status = 'active'
  ) into v_exists;
  return v_exists;
end;
$$;

-- ---------- 3) الفهارس (القسم 4.4 — Index حسب الـQueries الفعلية) ----------
create index idx_users_tenant on public.users(tenant_id);
create index idx_users_tenant_role on public.users(tenant_id, role);
create index idx_users_tenant_status on public.users(tenant_id, status);
create index idx_groups_tenant on public.groups(tenant_id);
create index idx_group_members_student on public.group_members(student_id);
create index idx_parent_students_parent on public.parent_students(parent_id);
create index idx_parent_students_student on public.parent_students(student_id);
create index idx_content_tenant_group on public.content(tenant_id, group_id);
create index idx_content_group_status on public.content(group_id, status);
create index idx_content_group_published on public.content(group_id, published_at);
create index idx_assignments_content on public.assignments(content_id);
create index idx_submissions_assignment_student on public.assignment_submissions(assignment_id, student_id);
create index idx_exams_content on public.exams(content_id);
create index idx_exam_versions_exam on public.exam_versions(exam_id);
create index idx_exam_questions_version on public.exam_questions(exam_version_id);
create index idx_exam_attempts_exam_student on public.exam_attempts(exam_id, student_id);
create index idx_attendance_group_date on public.attendance(group_id, date);
create index idx_attendance_student_date on public.attendance(student_id, date);
create index idx_activity_user_created on public.activity_events(user_id, created_at);
create index idx_activity_tenant_created on public.activity_events(tenant_id, created_at);
create index idx_notifications_tenant_created on public.notifications(tenant_id, created_at);
create index idx_notif_recipients_user_read on public.notification_recipients(user_id, read_at);

-- 🔧 [إصلاح تجميع — القسم 4.3] منع Race Condition: Attempt واحدة نشطة لكل (طالب، امتحان)
create unique index one_active_attempt_per_student
  on public.exam_attempts (exam_id, student_id)
  where status = 'in_progress';

-- ---------- 4) محفزات الحماية ----------
create trigger trg_users_prevent_identity_change
  before update on public.users
  for each row execute function public.prevent_identity_change();

-- تحديث updated_at تلقائيًا
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

create trigger trg_tenants_touch before update on public.tenants
  for each row execute function public.touch_updated_at();
create trigger trg_users_touch before update on public.users
  for each row execute function public.touch_updated_at();
create trigger trg_groups_touch before update on public.groups
  for each row execute function public.touch_updated_at();
create trigger trg_content_touch before update on public.content
  for each row execute function public.touch_updated_at();
create trigger trg_videos_touch before update on public.videos
  for each row execute function public.touch_updated_at();
create trigger trg_assignments_touch before update on public.assignments
  for each row execute function public.touch_updated_at();
create trigger trg_exams_touch before update on public.exams
  for each row execute function public.touch_updated_at();

-- حماية question_options.is_correct من القراءة عبر أي Select مباشر مسموح
-- (التعرض الحقيقي يُمنع في طبقة الـRepository/DTO — الوثيقة القسم 4.2)

-- ---------- 5) RLS — تفعيل على كل جدول ----------
alter table public.tenants              enable row level security;
alter table public.users                enable row level security;
alter table public.groups               enable row level security;
alter table public.group_members        enable row level security;
alter table public.parent_students      enable row level security;
alter table public.content              enable row level security;
alter table public.files                enable row level security;
alter table public.videos               enable row level security;
alter table public.assignments          enable row level security;
alter table public.assignment_submissions enable row level security;
alter table public.submission_files     enable row level security;
alter table public.exams                enable row level security;
alter table public.exam_versions        enable row level security;
alter table public.exam_questions       enable row level security;
alter table public.question_options     enable row level security;
alter table public.exam_attempts        enable row level security;
alter table public.exam_answers         enable row level security;
alter table public.attendance           enable row level security;
alter table public.activity_events      enable row level security;
alter table public.video_progress       enable row level security;
alter table public.notifications        enable row level security;
alter table public.notification_recipients enable row level security;
alter table public.user_devices         enable row level security;
alter table public.audit_logs           enable row level security;

-- ---------- 6) السياسات (المبدأ: auth.uid() → users → tenant/role) ----------
-- ملاحظة: كتابة العمليات الحساسة (اعتماد، درجات، حضور...) تمر عبر Edge Functions
-- Service Role التي تتجاوز RLS بإذن صريح — RLS هنا تحكم الوصول المباشر من العميل.

-- tenants
create policy tenants_teacher_read on public.tenants for select to authenticated
  using (public.has_role('teacher') and public.tenant_is_active() and id = public.my_tenant_id());
create policy tenants_student_parent_read on public.tenants for select to authenticated
  using ((public.has_role('student') or public.has_role('parent')) and public.tenant_is_active() and id = public.my_tenant_id());

-- users
create policy users_own_read on public.users for select to authenticated
  using (id = auth.uid());
create policy users_teacher_read_tenant on public.users for select to authenticated
  using (public.has_role('teacher') and public.tenant_is_active() and tenant_id = public.my_tenant_id());
create policy users_parent_read_children on public.users for select to authenticated
  using (public.has_role('parent') and public.tenant_is_active() and public.is_parent_of_student(auth.uid(), users.id));
create policy users_own_update on public.users for update to authenticated
  using (id = auth.uid());

-- groups
create policy groups_teacher_all on public.groups for all to authenticated
  using (public.has_role('teacher') and public.tenant_is_active() and tenant_id = public.my_tenant_id());
create policy groups_student_read_member on public.groups for select to authenticated
  using (public.has_role('student') and public.tenant_is_active() and public.is_member_of_group(groups.id, auth.uid()));
create policy groups_parent_read_children on public.groups for select to authenticated
  using (public.has_role('parent') and public.tenant_is_active() and public.parent_has_child_in_group(auth.uid(), groups.id));

-- group_members
create policy gm_teacher_all on public.group_members for all to authenticated
  using (public.has_role('teacher') and public.tenant_is_active() and public.group_belongs_to_my_tenant(group_members.group_id));
create policy gm_student_read_own on public.group_members for select to authenticated
  using (student_id = auth.uid() and public.tenant_is_active());
create policy gm_parent_read_children on public.group_members for select to authenticated
  using (public.has_role('parent') and public.tenant_is_active() and public.is_parent_of_student(auth.uid(), group_members.student_id));

-- parent_students
create policy ps_teacher_all on public.parent_students for all to authenticated
  using (public.has_role('teacher') and public.tenant_is_active() and public.user_belongs_to_my_tenant(parent_students.parent_id));
create policy ps_parent_read_own on public.parent_students for select to authenticated
  using (parent_id = auth.uid() and public.tenant_is_active());
create policy ps_student_read_own on public.parent_students for select to authenticated
  using (student_id = auth.uid() and public.tenant_is_active());

-- content
create policy content_teacher_all on public.content for all to authenticated
  using (public.has_role('teacher') and public.tenant_is_active() and tenant_id = public.my_tenant_id());
create policy content_student_read_published on public.content for select to authenticated
  using (public.has_role('student') and public.tenant_is_active() and status = 'published' and exists (
    select 1 from public.group_members gm
    where gm.student_id = auth.uid() and gm.group_id = content.group_id
      and (gm.joined_at <= content.published_at or (
        select g.previous_content_access from public.groups g where g.id = content.group_id) = 'allow')));
create policy content_parent_read_children on public.content for select to authenticated
  using (public.has_role('parent') and public.tenant_is_active() and status = 'published' and exists (
    select 1 from public.group_members gm
    join public.parent_students ps on ps.student_id = gm.student_id and ps.parent_id = auth.uid()
    where gm.group_id = content.group_id));

-- files
create policy files_teacher_all on public.files for all to authenticated
  using (public.has_role('teacher') and public.tenant_is_active() and tenant_id = public.my_tenant_id());
create policy files_student_read_authorized on public.files for select to authenticated
  using (public.has_role('student') and public.tenant_is_active() and exists (
    select 1 from public.content c where c.id = files.content_id and c.status = 'published' and exists (
      select 1 from public.group_members gm where gm.student_id = auth.uid() and gm.group_id = c.group_id)));

-- videos
create policy videos_teacher_all on public.videos for all to authenticated
  using (public.has_role('teacher') and public.tenant_is_active() and exists (
    select 1 from public.content c where c.id = videos.content_id and c.tenant_id = public.my_tenant_id()));
create policy videos_student_read_ready on public.videos for select to authenticated
  using (public.has_role('student') and public.tenant_is_active() and status = 'ready' and exists (
    select 1 from public.content c where c.id = videos.content_id and c.status = 'published' and exists (
      select 1 from public.group_members gm where gm.student_id = auth.uid() and gm.group_id = c.group_id)));

-- assignments
create policy assignments_teacher_all on public.assignments for all to authenticated
  using (public.has_role('teacher') and public.tenant_is_active() and tenant_id = public.my_tenant_id());
create policy assignments_student_read_group on public.assignments for select to authenticated
  using (public.has_role('student') and public.tenant_is_active() and exists (
    select 1 from public.content c where c.id = assignments.content_id and c.status = 'published' and exists (
      select 1 from public.group_members gm where gm.student_id = auth.uid() and gm.group_id = c.group_id)));
create policy assignments_parent_read_children on public.assignments for select to authenticated
  using (public.has_role('parent') and public.tenant_is_active() and exists (
    select 1 from public.content c join public.group_members gm on gm.group_id = c.group_id
    join public.parent_students ps on ps.student_id = gm.student_id and ps.parent_id = auth.uid()
    where c.id = assignments.content_id));

-- assignment_submissions
create policy subs_student_own_all on public.assignment_submissions for select to authenticated
  using (student_id = auth.uid() and public.tenant_is_active());
create policy subs_teacher_read_grade on public.assignment_submissions for select to authenticated
  using (public.has_role('teacher') and public.tenant_is_active() and exists (
    select 1 from public.assignments a where a.id = assignment_submissions.assignment_id and a.tenant_id = public.my_tenant_id()));
create policy subs_parent_read_children on public.assignment_submissions for select to authenticated
  using (public.has_role('parent') and public.tenant_is_active() and exists (
    select 1 from public.parent_students ps where ps.parent_id = auth.uid() and ps.student_id = assignment_submissions.student_id));

-- submission_files
create policy subfiles_teacher_all on public.submission_files for all to authenticated
  using (public.has_role('teacher') and public.tenant_is_active() and exists (
    select 1 from public.assignment_submissions s
    join public.assignments a on a.id = s.assignment_id
    where s.id = submission_files.submission_id and a.tenant_id = public.my_tenant_id()));
create policy subfiles_student_own on public.submission_files for select to authenticated
  using (exists (select 1 from public.assignment_submissions s where s.id = submission_files.submission_id and s.student_id = auth.uid()));

-- exams
create policy exams_teacher_all on public.exams for all to authenticated
  using (public.has_role('teacher') and public.tenant_is_active() and tenant_id = public.my_tenant_id());
create policy exams_student_read_published on public.exams for select to authenticated
  using (public.has_role('student') and public.tenant_is_active() and exists (
    select 1 from public.content c where c.id = exams.content_id and c.status = 'published' and exists (
      select 1 from public.group_members gm where gm.student_id = auth.uid() and gm.group_id = c.group_id)));
create policy exams_parent_read_children on public.exams for select to authenticated
  using (public.has_role('parent') and public.tenant_is_active() and exists (
    select 1 from public.content c join public.group_members gm on gm.group_id = c.group_id
    join public.parent_students ps on ps.student_id = gm.student_id and ps.parent_id = auth.uid()
    where c.id = exams.content_id));

-- exam_versions
create policy ev_teacher_all on public.exam_versions for all to authenticated
  using (public.has_role('teacher') and public.tenant_is_active() and exists (
    select 1 from public.exams e where e.id = exam_versions.exam_id and e.tenant_id = public.my_tenant_id()));
create policy ev_student_read_published on public.exam_versions for select to authenticated
  using (status = 'published' and exists (
    select 1 from public.exams e where e.id = exam_versions.exam_id and exists (
      select 1 from public.content c where c.id = e.content_id and c.status = 'published' and exists (
        select 1 from public.group_members gm where gm.student_id = auth.uid() and gm.group_id = c.group_id))));

-- exam_questions
create policy eq_teacher_all on public.exam_questions for all to authenticated
  using (public.has_role('teacher') and public.tenant_is_active() and exists (
    select 1 from public.exam_versions v join public.exams e on e.id = v.exam_id
    where v.id = exam_questions.exam_version_id and e.tenant_id = public.my_tenant_id()));
create policy eq_student_read_published on public.exam_questions for select to authenticated
  using (exists (select 1 from public.exam_versions v where v.id = exam_questions.exam_version_id and v.status = 'published'));

-- question_options
create policy qo_teacher_all on public.question_options for all to authenticated
  using (public.has_role('teacher') and public.tenant_is_active() and exists (
    select 1 from public.exam_questions q join public.exam_versions v on v.id = q.exam_version_id
    join public.exams e on e.id = v.exam_id where q.id = question_options.question_id and e.tenant_id = public.my_tenant_id()));
-- مهم: الطالب لا يقرأ question_options مباشرة إطلاقًا — المتاح له يأتي من Edge Function
-- (start-exam) بحقول آمنة فقط (بدون is_correct)

-- exam_attempts
create policy attempts_student_own on public.exam_attempts for select to authenticated
  using (student_id = auth.uid() and public.tenant_is_active());
create policy attempts_teacher_read on public.exam_attempts for select to authenticated
  using (public.has_role('teacher') and public.tenant_is_active() and exists (
    select 1 from public.exams e where e.id = exam_attempts.exam_id and e.tenant_id = public.my_tenant_id()));
create policy attempts_parent_read_children on public.exam_attempts for select to authenticated
  using (public.has_role('parent') and public.tenant_is_active() and exists (
    select 1 from public.parent_students ps where ps.parent_id = auth.uid() and ps.student_id = exam_attempts.student_id));

-- exam_answers
create policy answers_student_own on public.exam_answers for select to authenticated
  using (exists (select 1 from public.exam_attempts a where a.id = exam_answers.attempt_id and a.student_id = auth.uid()));
create policy answers_teacher_read on public.exam_answers for select to authenticated
  using (public.has_role('teacher') and public.tenant_is_active() and exists (
    select 1 from public.exam_attempts a join public.exams e on e.id = a.exam_id
    where a.id = exam_answers.attempt_id and e.tenant_id = public.my_tenant_id()));

-- attendance
create policy attendance_teacher_all on public.attendance for all to authenticated
  using (public.has_role('teacher') and public.tenant_is_active() and tenant_id = public.my_tenant_id());
create policy attendance_student_read_own on public.attendance for select to authenticated
  using (student_id = auth.uid() and public.tenant_is_active());
create policy attendance_parent_read_children on public.attendance for select to authenticated
  using (public.has_role('parent') and public.tenant_is_active() and exists (
    select 1 from public.parent_students ps where ps.parent_id = auth.uid() and ps.student_id = attendance.student_id));

-- activity_events
create policy activity_teacher_read_tenant on public.activity_events for select to authenticated
  using (public.has_role('teacher') and public.tenant_is_active() and tenant_id = public.my_tenant_id());
create policy activity_user_own on public.activity_events for select to authenticated
  using (user_id = auth.uid() and public.tenant_is_active());
create policy activity_parent_read_children on public.activity_events for select to authenticated
  using (public.has_role('parent') and public.tenant_is_active() and exists (
    select 1 from public.parent_students ps where ps.parent_id = auth.uid() and ps.student_id = activity_events.user_id));

-- video_progress
create policy vp_student_own_all on public.video_progress for all to authenticated
  using (student_id = auth.uid() and public.tenant_is_active());
create policy vp_teacher_read_tenant on public.video_progress for select to authenticated
  using (public.has_role('teacher') and public.tenant_is_active() and tenant_id = public.my_tenant_id());
create policy vp_parent_read_children on public.video_progress for select to authenticated
  using (public.has_role('parent') and public.tenant_is_active() and exists (
    select 1 from public.parent_students ps where ps.parent_id = auth.uid() and ps.student_id = video_progress.student_id));

-- notifications
create policy notif_teacher_all on public.notifications for all to authenticated
  using (public.has_role('teacher') and public.tenant_is_active() and tenant_id = public.my_tenant_id());
create policy notif_recipient_related on public.notifications for select to authenticated
  using (public.tenant_is_active() and exists (
    select 1 from public.notification_recipients nr where nr.notification_id = notifications.id and nr.user_id = auth.uid()));

-- notification_recipients
create policy nr_own on public.notification_recipients for select to authenticated
  using (user_id = auth.uid() and public.tenant_is_active());
create policy nr_teacher_read on public.notification_recipients for select to authenticated
  using (public.has_role('teacher') and public.tenant_is_active() and exists (
    select 1 from public.notifications n where n.id = notification_recipients.notification_id and n.tenant_id = public.my_tenant_id()));
create policy nr_own_update_read on public.notification_recipients for update to authenticated
  using (user_id = auth.uid() and public.tenant_is_active());

-- user_devices
create policy devices_own_all on public.user_devices for all to authenticated
  using (user_id = auth.uid() and public.tenant_is_active());

-- audit_logs: قراءة المدرس لـTenant فقط، الكتابة عبر Backend (Service Role)
create policy audit_teacher_read_tenant on public.audit_logs for select to authenticated
  using (public.has_role('teacher') and public.tenant_is_active() and tenant_id = public.my_tenant_id());

-- ============================================================================
-- نهاية 0001_init.sql
-- ملاحظة التنفيذ: قبل الإطلاق يجب تشغيل EXPLAIN ANALYZE على أهم الاستعلامات
-- المحمية بـRLS (القسم 5.5) واختبار سيناريوهات الهجوم (القسم 12.5) كاختبارات فعلية.
-- ============================================================================
