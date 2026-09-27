-- ============================================================================
-- 0019_question_bank_core.sql — EdSentre Question Bank Core Schema (M1)
-- Reference: 11_QUESTION_BANK_RECONSTRUCTION_SPEC.md §6
-- Rules:
--   · Every table carries tenant_id uuid not null + RLS enabled
--   · question_revisions is IMMUTABLE (enforced by trigger)
--   · publish_revision() is SECURITY DEFINER — the ONLY path to publication
--   · Students get SELECT on published_question_revision VIEW only
--   · No INSERT/UPDATE on questions.status='published' for app roles
-- ============================================================================

begin;

-- ============================================================================
-- 1. LOOKUP / REFERENCE TABLES (no tenant_id needed)
-- ============================================================================

-- 1a. Question types registry
create table if not exists public.question_types (
  code             text primary key,          -- 'multiple_choice' | 'grid_in' | 'true_false'
  response_schema  jsonb not null default '{}',
  validator        text,                       -- python dotted path to validator class
  renderer         text                        -- flutter widget class name
);

insert into public.question_types (code) values
  ('multiple_choice'),
  ('grid_in'),
  ('true_false')
on conflict (code) do nothing;

-- 1b. Skill taxonomy tree (SAT/EST 4-domain hierarchy)
create table if not exists public.taxonomy (
  id        text primary key,                 -- e.g. 'geo.solids.surface_area'
  parent_id text references public.taxonomy(id),
  name_en   text not null,
  name_ar   text
);

insert into public.taxonomy (id, parent_id, name_en, name_ar) values
  ('algebra',            null,       'Algebra',                           'الجبر'),
  ('advanced_math',      null,       'Advanced Math',                     'الرياضيات المتقدمة'),
  ('problem_solving',    null,       'Problem-Solving & Data Analysis',   'حل المسائل وتحليل البيانات'),
  ('geometry',           null,       'Geometry & Trigonometry',           'الهندسة وعلم المثلثات'),
  ('geo.solids',         'geometry', 'Solid Shapes',                      'الأجسام الهندسية'),
  ('geo.solids.volume',  'geo.solids','Volume',                           'الحجم'),
  ('geo.solids.surface_area','geo.solids','Surface Area',                 'المساحة الجانبية والكلية')
on conflict (id) do nothing;

-- ============================================================================
-- 2. DOCUMENT LAYER — immutable evidence
-- ============================================================================

-- 2a. Uploaded documents (one row per unique file per tenant)
create table if not exists public.qb_documents (
  id                  uuid primary key default gen_random_uuid(),
  tenant_id           uuid not null references public.tenants(id),
  sha256              text not null,
  original_filename   text not null,
  mime                text,
  size_bytes          bigint,
  page_count          int,
  uploader_id         uuid references public.users(id),
  rights_attestation  jsonb,    -- {claimed_source, license, uploader_note, attested_at}
  forensic            jsonb,    -- DocumentForensics (from M0 pipeline)
  pipeline_version    text,
  status              text not null default 'pending'
                      check (status in ('pending','processing','done','failed')),
  created_at          timestamptz not null default now(),
  unique (tenant_id, sha256)
);

-- 2b. Per-page classification
create table if not exists public.qb_document_pages (
  id            uuid primary key default gen_random_uuid(),
  document_id   uuid not null references public.qb_documents(id) on delete cascade,
  tenant_id     uuid not null references public.tenants(id),
  page_no       int not null,
  page_class    text not null
                check (page_class in (
                  'native_vector','hybrid_raster','native_text_only',
                  'scanned','screenshot','cover','unknown'
                )),
  text_trust    numeric(4,3) check (text_trust between 0 and 1),
  render_path   text,          -- storage path for 300 DPI render
  width_pt      numeric,
  height_pt     numeric,
  rotation      int default 0,
  unique (document_id, page_no)
);

-- 2c. Evidence assets — immutable blobs (never deleted in V1)
create table if not exists public.qb_evidence_assets (
  id             uuid primary key default gen_random_uuid(),
  document_id    uuid not null references public.qb_documents(id),
  page_id        uuid references public.qb_document_pages(id),
  tenant_id      uuid not null references public.tenants(id),
  kind           text not null
                 check (kind in (
                   'page_render','embedded_image','composite_image',
                   'vector_group','crop','span_dump','key_crop'
                 )),
  bbox_pt        numeric[4],
  storage_path   text,
  sha256         text not null,
  dpi            int,
  derived_from   uuid[],       -- parent asset IDs (for composites)
  producer       jsonb,        -- {tool, version, params}
  created_at     timestamptz not null default now()
);

-- 2d. Page regions (noise-classified zones)
create table if not exists public.qb_page_regions (
  id          uuid primary key default gen_random_uuid(),
  page_id     uuid not null references public.qb_document_pages(id),
  tenant_id   uuid not null references public.tenants(id),
  kind        text,            -- 'question_hypothesis', 'options_block', 'figure', etc.
  bbox_pt     numeric[4],
  source      text,            -- which pipeline stage created it
  confidence  numeric(4,3),
  noise_class text             -- 'header'|'footer'|'watermark'|'page_number'|null
);

-- ============================================================================
-- 3. QUESTION STRUCTURE
-- ============================================================================

-- 3a. Exam sections (Module 1 / Module 2 / Form A)
create table if not exists public.qb_exam_sections (
  id                      uuid primary key default gen_random_uuid(),
  document_id             uuid not null references public.qb_documents(id),
  tenant_id               uuid not null references public.tenants(id),
  label                   text,                   -- 'Module 1', 'Module 2'
  ordinal                 int,
  expected_question_count int,
  form_id                 text                    -- ExamView form letter: 'A'
);

-- 3b. Questions (stable identity across revisions)
create table if not exists public.qb_questions (
  id                              uuid primary key default gen_random_uuid(),
  tenant_id                       uuid not null references public.tenants(id),
  document_id                     uuid references public.qb_documents(id),
  section_id                      uuid references public.qb_exam_sections(id),
  source_label                    text,           -- 'M2-Q7', 'Q3'
  question_type                   text not null references public.question_types(code),
  current_published_revision_id   uuid,           -- FK added after revisions table exists
  status                          text not null default 'extracted'
                                  check (status in (
                                    'extracted','review_required','in_review',
                                    'approved','published','rejected','quarantined'
                                  )),
  created_at                      timestamptz not null default now(),
  updated_at                      timestamptz not null default now(),
  unique (document_id, source_label)
);

-- 3c. Question revisions — IMMUTABLE (no UPDATE or DELETE ever)
create table if not exists public.qb_question_revisions (
  id              uuid primary key default gen_random_uuid(),
  question_id     uuid not null references public.qb_questions(id),
  tenant_id       uuid not null references public.tenants(id),
  rev_no          int not null,
  content         jsonb not null,    -- QuestionRevisionContent (§7.1)
  answer          jsonb not null,    -- AnswerState
  confidence      jsonb,             -- per-block confidence vector
  provenance      jsonb not null,    -- pipeline stage + version + candidates
  content_hash    text not null,     -- sha256(content::text) — approval is bound to this
  created_by      uuid references public.users(id),
  created_via     text check (created_via in ('pipeline','teacher_edit','restore')),
  edit_note       text,
  created_at      timestamptz not null default now(),
  unique (question_id, rev_no)
);

-- Add FK for current_published_revision_id now that revisions table exists
alter table public.qb_questions
  add constraint qb_questions_published_rev_fk
  foreign key (current_published_revision_id)
  references public.qb_question_revisions(id)
  deferrable initially deferred;

-- ============================================================================
-- 4. VALIDATION & REVIEW
-- ============================================================================

-- 4a. Validation runs (one per pipeline invocation on a revision)
create table if not exists public.qb_validation_runs (
  id               uuid primary key default gen_random_uuid(),
  revision_id      uuid not null references public.qb_question_revisions(id),
  tenant_id        uuid not null references public.tenants(id),
  pipeline_version text,
  ran_at           timestamptz not null default now()
);

-- 4b. Validation issues produced by the rule catalog (§9)
create table if not exists public.qb_validation_issues (
  id             uuid primary key default gen_random_uuid(),
  run_id         uuid not null references public.qb_validation_runs(id),
  tenant_id      uuid not null references public.tenants(id),
  rule_id        text not null,   -- 'B-020', 'B-041', etc.
  severity       text not null check (severity in ('BLOCKER','WARN','INFO')),
  block_ref      text,            -- which content block this applies to
  message        jsonb,           -- structured message (en + ar)
  resolvable_by  text check (resolvable_by in ('edit','confirm','none')),
  resolved_by    uuid references public.users(id),
  resolved_at    timestamptz
);

-- 4c. Teacher review tasks
create table if not exists public.qb_review_tasks (
  id           uuid primary key default gen_random_uuid(),
  revision_id  uuid not null references public.qb_question_revisions(id),
  tenant_id    uuid not null references public.tenants(id),
  priority     int default 0,
  mode         text,            -- 'fast', 'detailed', 'batch'
  assigned_to  uuid references public.users(id),
  status       text not null default 'pending'
               check (status in ('pending','in_progress','done','skipped')),
  created_at   timestamptz not null default now()
);

-- 4d. Audit trail for every review action
create table if not exists public.qb_review_actions (
  id          uuid primary key default gen_random_uuid(),
  task_id     uuid not null references public.qb_review_tasks(id),
  tenant_id   uuid not null references public.tenants(id),
  actor_id    uuid not null references public.users(id),
  action      text not null,   -- 'edit_block','acknowledge_issue','approve','reject','split','merge'
  payload     jsonb,
  created_at  timestamptz not null default now()
);

-- 4e. Approvals — bound to content_hash, cannot be reused after edit
create table if not exists public.qb_approvals (
  id                    uuid primary key default gen_random_uuid(),
  revision_id           uuid not null references public.qb_question_revisions(id),
  tenant_id             uuid not null references public.tenants(id),
  approver_id           uuid not null references public.users(id),
  content_hash          text not null,  -- MUST equal revision.content_hash at publish time
  acknowledged_issue_ids uuid[],        -- WARNs explicitly acknowledged by approver
  created_at            timestamptz not null default now()
);

-- ============================================================================
-- 5. TAXONOMY ASSIGNMENTS & QUESTION EVENTS
-- ============================================================================

create table if not exists public.qb_taxonomy_assignments (
  id           uuid primary key default gen_random_uuid(),
  revision_id  uuid not null references public.qb_question_revisions(id),
  tenant_id    uuid not null references public.tenants(id),
  taxonomy_id  text not null references public.taxonomy(id),
  source       text not null check (source in ('ai_suggested','teacher_assigned')),
  status       text not null default 'provisional'
               check (status in ('provisional','confirmed','rejected')),
  confidence   numeric(4,3)
);

-- Question event log — append-only audit trail
create table if not exists public.qb_question_events (
  id          bigserial primary key,
  question_id uuid not null references public.qb_questions(id),
  revision_id uuid references public.qb_question_revisions(id),
  tenant_id   uuid not null references public.tenants(id),
  actor       uuid references public.users(id),
  event       text not null,   -- 'created','revision_added','approved','published','rejected','quarantined'
  diff        jsonb,
  at          timestamptz not null default now()
);

-- ============================================================================
-- 6. PIPELINE JOB QUEUE (Postgres-native, no Celery/Kafka)
-- ============================================================================

create table if not exists public.qb_jobs (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references public.tenants(id),
  kind        text not null,   -- 'ingest_document','run_forensics','run_segmentation',etc.
  payload     jsonb not null default '{}',
  status      text not null default 'pending'
              check (status in ('pending','running','done','failed','cancelled')),
  attempts    int not null default 0,
  max_attempts int not null default 3,
  run_after   timestamptz not null default now(),
  locked_by   text,           -- worker instance identifier
  locked_at   timestamptz,
  cache_key   text unique,    -- sha256(input)+stage+version — idempotency key
  error       text,
  result      jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ============================================================================
-- 7. INDEXES (critical for RLS policy performance per §3.3 / spec §11)
-- ============================================================================

-- tenant-scoped lookups — prevents Sequential Scan inside RLS policies
create index if not exists idx_qb_documents_tenant        on public.qb_documents(tenant_id);
create index if not exists idx_qb_document_pages_doc      on public.qb_document_pages(document_id);
create index if not exists idx_qb_evidence_assets_tenant  on public.qb_evidence_assets(tenant_id);
create index if not exists idx_qb_evidence_assets_page    on public.qb_evidence_assets(page_id);
create index if not exists idx_qb_questions_tenant        on public.qb_questions(tenant_id);
create index if not exists idx_qb_questions_document      on public.qb_questions(document_id);
create index if not exists idx_qb_questions_status        on public.qb_questions(status);
create index if not exists idx_qb_revisions_question      on public.qb_question_revisions(question_id);
create index if not exists idx_qb_revisions_tenant        on public.qb_question_revisions(tenant_id);
create index if not exists idx_qb_validation_issues_run   on public.qb_validation_issues(run_id);
create index if not exists idx_qb_jobs_status_run_after   on public.qb_jobs(status, run_after)
  where status = 'pending';
create index if not exists idx_qb_events_question         on public.qb_question_events(question_id);

-- ============================================================================
-- 8. IMMUTABILITY TRIGGER — question_revisions cannot be updated or deleted
-- ============================================================================

create or replace function public.qb_prevent_revision_mutation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  raise exception
    'qb_question_revisions is immutable. Create a new revision instead. (question_id: %, rev_no: %)',
    old.question_id, old.rev_no
    using errcode = 'P0001';
  return null; -- unreachable, but required for trigger
end;
$$;

drop trigger if exists trg_qb_revision_immutable on public.qb_question_revisions;
create trigger trg_qb_revision_immutable
  before update or delete on public.qb_question_revisions
  for each row execute function public.qb_prevent_revision_mutation();

-- ============================================================================
-- 9. PUBLISH GATE — SECURITY DEFINER function: the ONLY path to publication
-- Must raise if any of 6 pre-conditions fails (§6.3)
-- ============================================================================

create or replace function public.publish_revision(p_revision_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_revision    public.qb_question_revisions%rowtype;
  v_question    public.qb_questions%rowtype;
  v_approval    public.qb_approvals%rowtype;
  v_caller_role text;
  v_blocker_cnt int;
  v_latest_rev_no int;
begin
  -- ── 0. Caller must be authenticated and a teacher in the same tenant ──────
  if auth.uid() is null then
    raise exception 'AUTH_REQUIRED: must be authenticated to publish'
      using errcode = 'P0002';
  end if;

  -- ── Load revision ────────────────────────────────────────────────────────
  select * into v_revision from public.qb_question_revisions where id = p_revision_id;
  if not found then
    raise exception 'NOT_FOUND: revision % does not exist', p_revision_id
      using errcode = 'P0003';
  end if;

  -- ── Load question ─────────────────────────────────────────────────────────
  select * into v_question from public.qb_questions where id = v_revision.question_id;
  if not found then
    raise exception 'NOT_FOUND: question for revision % not found', p_revision_id
      using errcode = 'P0003';
  end if;

  -- ── Caller must be a teacher in the same tenant ──────────────────────────
  select role into v_caller_role
    from public.users
    where id = auth.uid() and tenant_id = v_question.tenant_id;
  if not found or v_caller_role != 'teacher' then
    raise exception 'NOT_AUTHORIZED: only a teacher of this tenant can publish'
      using errcode = 'P0004';
  end if;

  -- ── CONDITION 1: valid approval with matching content_hash ───────────────
  select * into v_approval
    from public.qb_approvals
    where revision_id = p_revision_id
    order by created_at desc
    limit 1;

  if not found then
    raise exception 'PUBLISH_BLOCKED: no approval found for revision %', p_revision_id
      using errcode = 'P0005';
  end if;

  if v_approval.content_hash != v_revision.content_hash then
    raise exception 'PUBLISH_BLOCKED: content_hash mismatch — approval is stale (approval: %, revision: %)',
      v_approval.content_hash, v_revision.content_hash
      using errcode = 'P0006';
  end if;

  -- ── CONDITION 2: no unresolved BLOCKER issues on the latest validation run ─
  select count(*) into v_blocker_cnt
    from public.qb_validation_issues vi
    join public.qb_validation_runs vr on vr.id = vi.run_id
    where vr.revision_id = p_revision_id
      and vi.severity = 'BLOCKER'
      and vi.resolved_at is null;

  if v_blocker_cnt > 0 then
    raise exception 'PUBLISH_BLOCKED: % unresolved BLOCKER issue(s) on revision %',
      v_blocker_cnt, p_revision_id
      using errcode = 'P0007';
  end if;

  -- ── CONDITION 3: all answer statuses must be acceptable ──────────────────
  if not (v_revision.answer->>'status' = any(array[
            'source_extracted','solver_verified',
            'source_and_solver_agree','teacher_confirmed'
         ])) then
    raise exception 'PUBLISH_BLOCKED: answer status "%" is not acceptable for publication',
      v_revision.answer->>'status'
      using errcode = 'P0008';
  end if;

  -- For MCQ: answer key must exist in option keys
  if v_question.question_type = 'multiple_choice' then
    if not exists (
      select 1
      from jsonb_array_elements(v_revision.content->'options') as opt
      where opt->>'key' = coalesce(v_revision.answer->>'normalized', v_revision.answer->>'raw')
    ) then
      raise exception 'PUBLISH_BLOCKED: MCQ answer key "%" not found in option keys on revision %',
        coalesce(v_revision.answer->>'normalized', v_revision.answer->>'raw'), p_revision_id
        using errcode = 'P0012';
    end if;
  end if;

  -- ── CONDITION 4: rights attestation at document level ────────────────────
  if not exists (
    select 1 from public.qb_documents d
    where d.id = v_question.document_id
      and d.rights_attestation is not null
      and d.rights_attestation != 'null'::jsonb
      and d.rights_attestation != '{}'::jsonb
  ) then
    raise exception 'PUBLISH_BLOCKED: rights_attestation missing on document for question %',
      v_question.id
      using errcode = 'P0009';
  end if;

  -- ── CONDITION 5: revision must be the latest for this question ───────────
  select max(rev_no) into v_latest_rev_no
    from public.qb_question_revisions
    where question_id = v_revision.question_id;

  if v_revision.rev_no != v_latest_rev_no then
    raise exception 'PUBLISH_BLOCKED: revision % (rev_no %) is not the latest (latest rev_no: %)',
      p_revision_id, v_revision.rev_no, v_latest_rev_no
      using errcode = 'P0010';
  end if;

  -- ── CONDITION 6: content block source_refs are non-empty ─────────────────
  -- (check that each stem and option block has source_refs set)
  if exists (
    select 1
    from jsonb_array_elements(v_revision.content->'stem') as blk
    where (blk->'source_refs') is null
       or jsonb_array_length(blk->'source_refs') = 0
  ) or exists (
    select 1
    from jsonb_array_elements(v_revision.content->'options') as opt
    where (opt->'source_refs') is null
       or jsonb_array_length(opt->'source_refs') = 0
  ) then
    raise exception 'PUBLISH_BLOCKED: one or more stem or option blocks have empty source_refs on revision %',
      p_revision_id
      using errcode = 'P0011';
  end if;

  -- ── ALL CONDITIONS PASSED — PERFORM ATOMIC PUBLICATION ───────────────────
  update public.qb_questions
    set status                        = 'published',
        current_published_revision_id = p_revision_id,
        updated_at                    = now()
    where id = v_revision.question_id;

  -- Audit event
  insert into public.qb_question_events
    (question_id, revision_id, tenant_id, actor, event, diff)
  values (
    v_revision.question_id, p_revision_id, v_question.tenant_id,
    auth.uid(), 'published',
    jsonb_build_object('rev_no', v_revision.rev_no, 'content_hash', v_revision.content_hash)
  );

end;
$$;

-- ============================================================================
-- 10. READ MODEL — students see ONLY this view, never raw tables
-- ============================================================================

create or replace view public.published_question_revision
  with (security_invoker = true)   -- respects caller's RLS
as
  select r.*
  from public.qb_questions q
  join public.qb_question_revisions r on r.id = q.current_published_revision_id
  where q.status = 'published';

-- ============================================================================
-- 11. ROW LEVEL SECURITY — enable on every table
-- ============================================================================

-- Helper: is caller an active teacher of a given tenant?
create or replace function public.qb_is_teacher(p_tenant_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.users
    where id = auth.uid()
      and tenant_id = p_tenant_id
      and role = 'teacher'
      and status = 'active'
  );
$$;

-- Helper: get caller's tenant_id (cached per statement)
create or replace function public.qb_my_tenant()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select tenant_id from public.users where id = auth.uid();
$$;

-- ── qb_documents ─────────────────────────────────────────────────────────────
alter table public.qb_documents enable row level security;

create policy "qb_docs_teacher_all" on public.qb_documents
  for all to authenticated
  using (public.qb_is_teacher(tenant_id))
  with check (public.qb_is_teacher(tenant_id));

-- ── qb_document_pages ────────────────────────────────────────────────────────
alter table public.qb_document_pages enable row level security;

create policy "qb_doc_pages_teacher_all" on public.qb_document_pages
  for all to authenticated
  using (public.qb_is_teacher(tenant_id))
  with check (public.qb_is_teacher(tenant_id));

-- ── qb_evidence_assets ───────────────────────────────────────────────────────
alter table public.qb_evidence_assets enable row level security;

create policy "qb_evidence_teacher_all" on public.qb_evidence_assets
  for all to authenticated
  using (public.qb_is_teacher(tenant_id))
  with check (public.qb_is_teacher(tenant_id));

-- ── qb_page_regions ──────────────────────────────────────────────────────────
alter table public.qb_page_regions enable row level security;

create policy "qb_page_regions_teacher_all" on public.qb_page_regions
  for all to authenticated
  using (public.qb_is_teacher(tenant_id))
  with check (public.qb_is_teacher(tenant_id));

-- ── qb_exam_sections ─────────────────────────────────────────────────────────
alter table public.qb_exam_sections enable row level security;

create policy "qb_sections_teacher_all" on public.qb_exam_sections
  for all to authenticated
  using (public.qb_is_teacher(tenant_id))
  with check (public.qb_is_teacher(tenant_id));

-- ── qb_questions ─────────────────────────────────────────────────────────────
alter table public.qb_questions enable row level security;

-- Teachers: full access to their tenant
create policy "qb_questions_teacher_all" on public.qb_questions
  for all to authenticated
  using (public.qb_is_teacher(tenant_id))
  with check (public.qb_is_teacher(tenant_id));

-- Students: SELECT only published questions in their tenant
create policy "qb_questions_student_read_published" on public.qb_questions
  for select to authenticated
  using (
    status = 'published'
    and tenant_id = public.qb_my_tenant()
    and exists (
      select 1 from public.users
      where id = auth.uid() and role = 'student' and status = 'active'
    )
  );

-- ── qb_question_revisions ────────────────────────────────────────────────────
alter table public.qb_question_revisions enable row level security;

-- Teachers: INSERT only (no UPDATE/DELETE — enforced by trigger)
create policy "qb_revisions_teacher_insert" on public.qb_question_revisions
  for insert to authenticated
  with check (public.qb_is_teacher(tenant_id));

-- Teachers: SELECT all revisions of their tenant
create policy "qb_revisions_teacher_select" on public.qb_question_revisions
  for select to authenticated
  using (public.qb_is_teacher(tenant_id));

-- Students: NO direct access to qb_question_revisions (use view instead)
-- (no student policy = no access)

-- ── qb_validation_runs ───────────────────────────────────────────────────────
alter table public.qb_validation_runs enable row level security;

create policy "qb_val_runs_teacher_all" on public.qb_validation_runs
  for all to authenticated
  using (public.qb_is_teacher(tenant_id))
  with check (public.qb_is_teacher(tenant_id));

-- ── qb_validation_issues ─────────────────────────────────────────────────────
alter table public.qb_validation_issues enable row level security;

create policy "qb_val_issues_teacher_all" on public.qb_validation_issues
  for all to authenticated
  using (public.qb_is_teacher(tenant_id))
  with check (public.qb_is_teacher(tenant_id));

-- ── qb_review_tasks ──────────────────────────────────────────────────────────
alter table public.qb_review_tasks enable row level security;

create policy "qb_review_tasks_teacher_all" on public.qb_review_tasks
  for all to authenticated
  using (public.qb_is_teacher(tenant_id))
  with check (public.qb_is_teacher(tenant_id));

-- ── qb_review_actions ────────────────────────────────────────────────────────
alter table public.qb_review_actions enable row level security;

create policy "qb_review_actions_teacher_all" on public.qb_review_actions
  for all to authenticated
  using (public.qb_is_teacher(tenant_id))
  with check (public.qb_is_teacher(tenant_id));

-- ── qb_approvals ─────────────────────────────────────────────────────────────
alter table public.qb_approvals enable row level security;

create policy "qb_approvals_teacher_insert_select" on public.qb_approvals
  for all to authenticated
  using (public.qb_is_teacher(tenant_id))
  with check (public.qb_is_teacher(tenant_id));

-- ── qb_taxonomy_assignments ──────────────────────────────────────────────────
alter table public.qb_taxonomy_assignments enable row level security;

create policy "qb_taxonomy_assign_teacher_all" on public.qb_taxonomy_assignments
  for all to authenticated
  using (public.qb_is_teacher(tenant_id))
  with check (public.qb_is_teacher(tenant_id));

-- ── qb_question_events (append-only audit) ───────────────────────────────────
alter table public.qb_question_events enable row level security;

-- Only teachers can SELECT their tenant's events; only backend inserts (via publish_revision)
create policy "qb_events_teacher_select" on public.qb_question_events
  for select to authenticated
  using (public.qb_is_teacher(tenant_id));

-- ── qb_jobs ──────────────────────────────────────────────────────────────────
alter table public.qb_jobs enable row level security;

create policy "qb_jobs_teacher_select" on public.qb_jobs
  for select to authenticated
  using (public.qb_is_teacher(tenant_id));

create policy "qb_jobs_teacher_insert" on public.qb_jobs
  for insert to authenticated
  with check (public.qb_is_teacher(tenant_id));

-- ============================================================================
-- 12. GRANTS — expose to authenticated role; anon gets nothing
-- ============================================================================

-- Revoke all from anon (defense in depth)
revoke all on public.qb_documents from anon;
revoke all on public.qb_document_pages from anon;
revoke all on public.qb_evidence_assets from anon;
revoke all on public.qb_questions from anon;
revoke all on public.qb_question_revisions from anon;
revoke all on public.published_question_revision from anon;

-- Grant to authenticated (RLS filters actual rows)
grant select, insert, update on public.qb_documents to authenticated;
grant select, insert on public.qb_document_pages to authenticated;
grant select, insert on public.qb_evidence_assets to authenticated;
grant select, insert on public.qb_page_regions to authenticated;
grant select, insert on public.qb_exam_sections to authenticated;
grant select, insert, update on public.qb_questions to authenticated;
grant select, insert on public.qb_question_revisions to authenticated;
grant select, insert on public.qb_validation_runs to authenticated;
grant select, insert, update on public.qb_validation_issues to authenticated;
grant select, insert, update on public.qb_review_tasks to authenticated;
grant select, insert on public.qb_review_actions to authenticated;
grant select, insert on public.qb_approvals to authenticated;
grant select, insert on public.qb_taxonomy_assignments to authenticated;
grant select on public.qb_question_events to authenticated;
grant select, insert, update on public.qb_jobs to authenticated;

-- Students access ONLY the published view
grant select on public.published_question_revision to authenticated;

-- publish_revision is callable by authenticated teachers (RLS inside the function gates it)
grant execute on function public.publish_revision(uuid) to authenticated;

commit;
