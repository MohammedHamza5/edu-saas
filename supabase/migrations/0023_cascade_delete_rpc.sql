-- ============================================================================
-- Migration 0023: Atomic Cascade Delete RPCs for Question Bank
-- Deletes documents and questions with complete atomicity and RLS tenant isolation.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.delete_qb_document(p_document_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tenant_id uuid;
  v_user_role text;
BEGIN
  -- 1. Security Check: verify teacher belongs to document's tenant
  SELECT tenant_id, role INTO v_tenant_id, v_user_role
  FROM public.users
  WHERE id = auth.uid() AND status = 'active';

  IF v_user_role != 'teacher' THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only teachers can delete documents';
  END IF;

  -- Verify document exists and belongs to the same tenant
  IF NOT EXISTS (
    SELECT 1 FROM public.qb_documents
    WHERE id = p_document_id AND tenant_id = v_tenant_id
  ) THEN
    RAISE EXCEPTION 'NOT_FOUND: Document not found or not in your tenant';
  END IF;

  -- 2. Delete all question-related records for questions belonging to this document
  -- a. Delete review actions
  DELETE FROM public.qb_review_actions
  WHERE task_id IN (
    SELECT t.id FROM public.qb_review_tasks t
    JOIN public.qb_question_revisions r ON r.id = t.revision_id
    JOIN public.qb_questions q ON q.id = r.question_id
    WHERE q.document_id = p_document_id
  );

  -- b. Delete review tasks
  DELETE FROM public.qb_review_tasks
  WHERE revision_id IN (
    SELECT r.id FROM public.qb_question_revisions r
    JOIN public.qb_questions q ON q.id = r.question_id
    WHERE q.document_id = p_document_id
  );

  -- c. Delete validation issues
  DELETE FROM public.qb_validation_issues
  WHERE run_id IN (
    SELECT v.id FROM public.qb_validation_runs v
    JOIN public.qb_question_revisions r ON r.id = v.revision_id
    JOIN public.qb_questions q ON q.id = r.question_id
    WHERE q.document_id = p_document_id
  );

  -- d. Delete validation runs
  DELETE FROM public.qb_validation_runs
  WHERE revision_id IN (
    SELECT r.id FROM public.qb_question_revisions r
    JOIN public.qb_questions q ON q.id = r.question_id
    WHERE q.document_id = p_document_id
  );

  -- e. Delete approvals
  DELETE FROM public.qb_approvals
  WHERE revision_id IN (
    SELECT r.id FROM public.qb_question_revisions r
    JOIN public.qb_questions q ON q.id = r.question_id
    WHERE q.document_id = p_document_id
  );

  -- f. Delete taxonomy assignments
  DELETE FROM public.qb_taxonomy_assignments
  WHERE revision_id IN (
    SELECT r.id FROM public.qb_question_revisions r
    JOIN public.qb_questions q ON q.id = r.question_id
    WHERE q.document_id = p_document_id
  );

  -- g. Delete question events
  DELETE FROM public.qb_question_events
  WHERE question_id IN (
    SELECT id FROM public.qb_questions WHERE document_id = p_document_id
  );

  -- h. Break circular dependency: nullify published revision FK on questions
  UPDATE public.qb_questions
  SET current_published_revision_id = NULL
  WHERE document_id = p_document_id;

  -- i. Delete revisions
  DELETE FROM public.qb_question_revisions
  WHERE question_id IN (
    SELECT id FROM public.qb_questions WHERE document_id = p_document_id
  );

  -- j. Delete questions
  DELETE FROM public.qb_questions
  WHERE document_id = p_document_id;

  -- 3. Delete document-level assets & sections
  DELETE FROM public.qb_exam_sections
  WHERE document_id = p_document_id;

  DELETE FROM public.qb_page_regions
  WHERE page_id IN (
    SELECT id FROM public.qb_document_pages WHERE document_id = p_document_id
  );

  DELETE FROM public.qb_evidence_assets
  WHERE document_id = p_document_id;

  DELETE FROM public.qb_document_pages
  WHERE document_id = p_document_id;

  -- 4. Delete jobs referencing this document
  DELETE FROM public.qb_jobs
  WHERE tenant_id = v_tenant_id
    AND payload->>'document_id' = p_document_id::text;

  -- 5. Delete the document itself
  DELETE FROM public.qb_documents
  WHERE id = p_document_id AND tenant_id = v_tenant_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_qb_question(p_question_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tenant_id uuid;
  v_user_role text;
BEGIN
  SELECT tenant_id, role INTO v_tenant_id, v_user_role
  FROM public.users
  WHERE id = auth.uid() AND status = 'active';

  IF v_user_role != 'teacher' THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only teachers can delete questions';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.qb_questions
    WHERE id = p_question_id AND tenant_id = v_tenant_id
  ) THEN
    RAISE EXCEPTION 'NOT_FOUND: Question not found';
  END IF;

  -- Delete review actions
  DELETE FROM public.qb_review_actions
  WHERE task_id IN (
    SELECT t.id FROM public.qb_review_tasks t
    JOIN public.qb_question_revisions r ON r.id = t.revision_id
    WHERE r.question_id = p_question_id
  );

  -- Delete review tasks
  DELETE FROM public.qb_review_tasks
  WHERE revision_id IN (
    SELECT id FROM public.qb_question_revisions WHERE question_id = p_question_id
  );

  -- Delete validation issues
  DELETE FROM public.qb_validation_issues
  WHERE run_id IN (
    SELECT v.id FROM public.qb_validation_runs v
    JOIN public.qb_question_revisions r ON r.id = v.revision_id
    WHERE r.question_id = p_question_id
  );

  -- Delete validation runs
  DELETE FROM public.qb_validation_runs
  WHERE revision_id IN (
    SELECT id FROM public.qb_question_revisions WHERE question_id = p_question_id
  );

  -- Delete approvals
  DELETE FROM public.qb_approvals
  WHERE revision_id IN (
    SELECT id FROM public.qb_question_revisions WHERE question_id = p_question_id
  );

  -- Delete taxonomy assignments
  DELETE FROM public.qb_taxonomy_assignments
  WHERE revision_id IN (
    SELECT id FROM public.qb_question_revisions WHERE question_id = p_question_id
  );

  -- Delete question events
  DELETE FROM public.qb_question_events
  WHERE question_id = p_question_id;

  -- Nullify published revision FK
  UPDATE public.qb_questions
  SET current_published_revision_id = NULL
  WHERE id = p_question_id;

  -- Delete revisions
  DELETE FROM public.qb_question_revisions
  WHERE question_id = p_question_id;

  -- Delete question
  DELETE FROM public.qb_questions
  WHERE id = p_question_id;
END;
$$;
