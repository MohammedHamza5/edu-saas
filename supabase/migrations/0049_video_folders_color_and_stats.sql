-- Migration 0049: Video Folders Color and Content Stats
-- 1. Adds color column to video_folders table
-- 2. Updates video_folders_with_counts view to include:
--    - color
--    - total_duration_seconds
--    - ready_video_count
--    - assigned_chapters_count
--    - assigned_groups (JSON list of courses/chapters where folder is used)

-- Step 1: Add color column
alter table public.video_folders 
  add column if not exists color text default null;

-- Step 2: Drop and recreate video_folders_with_counts view with extended metadata
drop view if exists public.video_folders_with_counts cascade;

create view public.video_folders_with_counts
with (security_invoker = true)
as
select 
  f.id,
  f.tenant_id,
  f.parent_id,
  f.name,
  f.color,
  f.created_at,
  f.updated_at,
  coalesce(v.video_count, 0)::integer as video_count,
  coalesce(v.total_duration_seconds, 0)::integer as total_duration_seconds,
  coalesce(v.ready_video_count, 0)::integer as ready_video_count,
  coalesce(s.subfolder_count, 0)::integer as subfolder_count,
  coalesce(ch_info.assigned_chapters_count, 0)::integer as assigned_chapters_count,
  coalesce(ch_info.assigned_groups, '[]'::jsonb) as assigned_groups
from public.video_folders f
left join (
  select 
    folder_id, 
    count(*)::integer as video_count,
    coalesce(sum(duration), 0)::integer as total_duration_seconds,
    count(*) filter (where status = 'ready')::integer as ready_video_count
  from public.video_library 
  group by folder_id
) v on v.folder_id = f.id
left join (
  select 
    parent_id, 
    count(*)::integer as subfolder_count 
  from public.video_folders 
  where parent_id is not null
  group by parent_id
) s on s.parent_id = f.id
left join (
  select 
    ch.source_folder_id,
    count(distinct ch.id)::integer as assigned_chapters_count,
    coalesce(
      jsonb_agg(
        distinct jsonb_build_object(
          'chapter_id', ch.id,
          'chapter_title', ch.title,
          'group_id', g.id,
          'group_name', g.name
        )
      ) filter (where ch.id is not null),
      '[]'::jsonb
    ) as assigned_groups
  from public.chapters ch
  join public.groups g on g.id = ch.group_id
  where ch.source_folder_id is not null
  group by ch.source_folder_id
) ch_info on ch_info.source_folder_id = f.id;

grant select on public.video_folders_with_counts to authenticated, anon;

-- Recreate get_video_bank_contents since cascade drop may have removed it
create or replace function public.get_video_bank_contents(
  p_folder_id uuid default null,
  p_search text default null
)
returns jsonb
language plpgsql
security invoker
as $$
declare
  v_folders jsonb;
  v_videos jsonb;
  v_trimmed_search text;
begin
  v_trimmed_search := nullif(trim(p_search), '');

  -- Folders with counts & metadata
  if v_trimmed_search is not null then
    v_folders := '[]'::jsonb;
  else
    select coalesce(jsonb_agg(to_jsonb(f)), '[]'::jsonb)
    into v_folders
    from (
      select * from public.video_folders_with_counts
      where (p_folder_id is null and parent_id is null)
         or (p_folder_id is not null and parent_id = p_folder_id)
      order by name asc
    ) f;
  end if;

  -- Videos
  select coalesce(jsonb_agg(to_jsonb(v)), '[]'::jsonb)
  into v_videos
  from (
    select vl.*,
      coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', vd.id,
          'content', jsonb_build_object(
            'group', jsonb_build_object('name', g.name)
          )
        ))
        from public.videos vd
        left join public.content c on c.id = vd.content_id
        left join public.groups g on g.id = c.group_id
        where vd.library_video_id = vl.id
      ), '[]'::jsonb) as videos
    from public.video_library vl
    where (
      case 
        when v_trimmed_search is not null then
          vl.title ilike '%' || v_trimmed_search || '%'
        when p_folder_id is not null then
          vl.folder_id = p_folder_id
        else
          vl.folder_id is null
      end
    )
    order by vl.created_at desc
  ) v;

  return jsonb_build_object(
    'folders', v_folders,
    'videos', v_videos
  );
end;
$$;

grant execute on function public.get_video_bank_contents(uuid, text) to authenticated, anon;

-- Step 3: RPC to update folder color directly
create or replace function public.update_video_folder_color(
  p_folder_id uuid,
  p_color text
)
returns jsonb
language plpgsql
security invoker
as $$
declare
  v_updated jsonb;
begin
  update public.video_folders
  set 
    color = nullif(trim(p_color), ''),
    updated_at = now()
  where id = p_folder_id;

  select to_jsonb(f) into v_updated
  from public.video_folders_with_counts f
  where f.id = p_folder_id;

  return v_updated;
end;
$$;

grant execute on function public.update_video_folder_color(uuid, text) to authenticated, anon;
