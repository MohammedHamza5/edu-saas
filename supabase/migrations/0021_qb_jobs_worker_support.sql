-- ============================================================================
-- 0021_qb_jobs_worker_support.sql
-- يضيف:
--   1. storage_path على qb_documents
--   2. دالة claim_next_job (SELECT…FOR UPDATE SKIP LOCKED)
--   3. دالة complete_job / fail_job
-- ============================================================================

begin;

-- 1. storage_path على qb_documents
alter table public.qb_documents
  add column if not exists storage_path text;

-- 2. أعمدة إضافية على qb_questions
alter table public.qb_questions
  add column if not exists priority_score         numeric(6,3) not null default 0,
  add column if not exists policy_state           text         not null default 'REVIEW_FAST',
  add column if not exists duplicate_cluster_id   uuid,
  add column if not exists requires_second_review boolean      not null default false;

-- 3. claim_next_job
create or replace function public.claim_next_job(p_worker_id text)
returns setof public.qb_jobs
language plpgsql
security definer
set search_path = public
as $$
declare v_job public.qb_jobs;
begin
  select * into v_job
  from public.qb_jobs
  where status = 'pending'
    and run_after <= now()
    and attempts < max_attempts
  order by created_at asc
  limit 1
  for update skip locked;

  if v_job.id is null then return; end if;

  update public.qb_jobs set
    status    = 'running',
    locked_by = p_worker_id,
    locked_at = now(),
    attempts  = attempts + 1,
    updated_at = now()
  where id = v_job.id;

  return query select * from public.qb_jobs where id = v_job.id;
end;
$$;

-- 4. complete_job
create or replace function public.complete_job(p_job_id uuid, p_result jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.qb_jobs set
    status = 'done', result = p_result, error = null, updated_at = now()
  where id = p_job_id;
end;
$$;

-- 5. fail_job
create or replace function public.fail_job(p_job_id uuid, p_error text, p_retry boolean default true)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.qb_jobs set
    status    = case when p_retry and attempts < max_attempts then 'pending' else 'failed' end,
    error     = p_error,
    locked_by = null,
    locked_at = null,
    run_after = case when p_retry and attempts < max_attempts
                     then now() + (attempts * interval '30 seconds')
                     else run_after end,
    updated_at = now()
  where id = p_job_id;
end;
$$;

grant execute on function public.claim_next_job(text) to service_role;
grant execute on function public.complete_job(uuid, jsonb) to service_role;
grant execute on function public.fail_job(uuid, text, boolean) to service_role;

commit;
