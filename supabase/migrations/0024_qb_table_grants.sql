-- ============================================================================
-- Migration 0024: Table-Level Grants for Question Bank Tables
-- In Supabase architecture, PostgREST requires table-level grants for anon/authenticated
-- so queries can be passed to PostgreSQL RLS policies without 'insufficient_privilege (42501)' errors.
-- ============================================================================

GRANT ALL ON TABLE public.qb_question_revisions TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.qb_validation_runs TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.qb_validation_issues TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.qb_review_tasks TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.qb_review_actions TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.qb_approvals TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.qb_taxonomy_assignments TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.qb_question_events TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.qb_jobs TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.qb_documents TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.qb_document_pages TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.qb_evidence_assets TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.qb_questions TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.qb_page_regions TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.qb_exam_sections TO anon, authenticated, service_role;

GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;
