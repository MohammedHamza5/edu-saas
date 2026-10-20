-- ==============================================================================
-- Migration: 0098_drop_ambiguous_exam_rpc_overloads.sql
-- Description:
--   Drops legacy ambiguous function overloads for update_draft_exam_questions
--   and create_exam_with_questions that caused PostgreSQL error 42725:
--   "Could not choose the best candidate function between..."
-- ==============================================================================

-- 1. Drop old 10-parameter overload of update_draft_exam_questions
DROP FUNCTION IF EXISTS public.update_draft_exam_questions(
  uuid, text, integer, integer, integer, boolean, boolean, boolean, boolean, jsonb
);

-- 2. Drop old 12-parameter overload of create_exam_with_questions
DROP FUNCTION IF EXISTS public.create_exam_with_questions(
  text, uuid, integer, integer, integer, boolean, boolean, boolean, boolean, timestamp with time zone, timestamp with time zone, jsonb
);

-- 3. Notify PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';
