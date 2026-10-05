-- Migration 0043: Optimize Video Bank CMS Performance
-- Adds index on videos(library_video_id)
-- Creates video_folders_with_counts view for single-query counts (eliminates N+1 queries)
-- Creates get_video_bank_contents RPC for instant single-roundtrip folder contents

create index if not exists idx_videos_library_video_id on public.videos(library_video_id);

create or replace view public.video_folders_with_counts
with (security_invoker = true)
as
select 
  f.*,
  coalesce(v.video_count, 0)::integer as video_count,
  coalesce(s.subfolder_count, 0)::integer as subfolder_count
from public.video_folders f
left join (
  select folder_id, count(*)::integer as video_count 
  from public.video_library 
  group by folder_id
) v on v.folder_id = f.id
left join (
  select parent_id, count(*)::integer as subfolder_count 
  from public.video_folders 
  where parent_id is not null
  group by parent_id
) s on s.parent_id = f.id;

grant select on public.video_folders_with_counts to authenticated, anon;

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

  -- Folders with counts
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
