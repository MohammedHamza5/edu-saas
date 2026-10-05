-- Migration 0038: Video Bank CMS

-- 1. video_folders
create table public.video_folders (
  id uuid primary key default uuid_generate_v4(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  parent_id uuid references public.video_folders(id) on delete cascade,
  name text not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create index idx_video_folders_tenant on public.video_folders(tenant_id);
create index idx_video_folders_parent on public.video_folders(parent_id);

alter table public.video_folders enable row level security;

create policy folders_teacher_all on public.video_folders
  for all to authenticated
  using (
    tenant_id = public.my_tenant_id() 
    and (select role from public.users where id = auth.uid()) = 'teacher'
  )
  with check (
    tenant_id = public.my_tenant_id() 
    and (select role from public.users where id = auth.uid()) = 'teacher'
  );


-- 2. video_library
create table public.video_library (
  id uuid primary key default uuid_generate_v4(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  folder_id uuid references public.video_folders(id) on delete set null,
  title text not null,
  description text,
  provider text not null default 'bunny',
  provider_video_id text,
  thumbnail_url text,
  duration integer,
  status text not null default 'uploading' check (status in ('uploading', 'processing', 'ready', 'failed')),
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create index idx_video_library_tenant on public.video_library(tenant_id);
create index idx_video_library_folder on public.video_library(folder_id);

alter table public.video_library enable row level security;

create policy library_teacher_all on public.video_library
  for all to authenticated
  using (
    tenant_id = public.my_tenant_id() 
    and (select role from public.users where id = auth.uid()) = 'teacher'
  )
  with check (
    tenant_id = public.my_tenant_id() 
    and (select role from public.users where id = auth.uid()) = 'teacher'
  );


-- 3. Link library to videos (content instances)
alter table public.videos 
add column library_video_id uuid references public.video_library(id) on delete set null;

-- When linking to a library video, the 'provider_video_id' will typically mirror the library's 'provider_video_id',
-- but library_video_id allows us to trace it back to the CMS to sync name changes or status if needed.
