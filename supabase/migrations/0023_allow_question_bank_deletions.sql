-- Migration: Allow deleting question bank revisions
-- Description: 
-- 1. Changes the `trg_qb_revision_immutable` trigger to only fire on UPDATE, not DELETE.
-- 2. Adds a DELETE RLS policy for `qb_question_revisions` so teachers can delete questions (which cascades/deletes revisions).

-- 1. Modify the trigger to only prevent UPDATEs
drop trigger if exists trg_qb_revision_immutable on public.qb_question_revisions;
create trigger trg_qb_revision_immutable
  before update on public.qb_question_revisions
  for each row execute function public.qb_prevent_revision_mutation();

-- 2. Add DELETE policy for teachers
create policy "qb_revisions_teacher_delete" on public.qb_question_revisions
  for delete to authenticated
  using (public.qb_is_teacher(tenant_id));
