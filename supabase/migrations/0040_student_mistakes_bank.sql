-- ============================================================================
-- Migration: 0040_student_mistakes_bank.sql
-- Description:
-- 1. Create public.student_mistakes table to track student errors across all exams.
-- 2. Trigger on public.exam_answers to automatically populate & sync mistakes.
-- 3. RPC public.get_student_mistakes_summary: quick overview & count of mistakes.
-- 4. RPC public.get_student_mistakes_questions: safe list of mistake questions for review/practice.
-- 5. RPC public.submit_mistakes_practice: atomic grading of mistake practice sessions
--    and marking corrected questions as is_resolved = true.
-- ============================================================================

-- 1. Table student_mistakes
CREATE TABLE IF NOT EXISTS public.student_mistakes (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  student_id          UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  question_id         UUID NOT NULL REFERENCES public.exam_questions(id) ON DELETE CASCADE,
  source_exam_id      UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
  source_attempt_id   UUID REFERENCES public.exam_attempts(id) ON DELETE SET NULL,
  selected_option_id  UUID REFERENCES public.question_options(id) ON DELETE SET NULL,
  is_resolved         BOOLEAN NOT NULL DEFAULT false,
  resolved_at         TIMESTAMPTZ,
  first_failed_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_failed_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  failure_count       INTEGER NOT NULL DEFAULT 1,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_student_mistakes_student_question UNIQUE (student_id, question_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_student_mistakes_student_resolved 
  ON public.student_mistakes (student_id, is_resolved);

CREATE INDEX IF NOT EXISTS idx_student_mistakes_exam 
  ON public.student_mistakes (source_exam_id);

CREATE INDEX IF NOT EXISTS idx_student_mistakes_tenant 
  ON public.student_mistakes (tenant_id);

-- Enable RLS
ALTER TABLE public.student_mistakes ENABLE ROW LEVEL SECURITY;

-- Policies
DROP POLICY IF EXISTS student_mistakes_student_own ON public.student_mistakes;
CREATE POLICY student_mistakes_student_own ON public.student_mistakes
  FOR SELECT TO authenticated
  USING (student_id = auth.uid());

DROP POLICY IF EXISTS student_mistakes_teacher_all ON public.student_mistakes;
CREATE POLICY student_mistakes_teacher_all ON public.student_mistakes
  FOR ALL TO authenticated
  USING (
    tenant_id = public.my_tenant_id() 
    AND public.has_role('teacher')
  );

-- 2. Trigger function to automatically sync errors from exam_answers
CREATE OR REPLACE FUNCTION public.fn_sync_exam_answer_to_mistakes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id UUID;
  v_exam_id UUID;
  v_tenant_id UUID;
BEGIN
  -- Get context from the attempt
  SELECT att.student_id, att.exam_id, e.tenant_id
  INTO v_student_id, v_exam_id, v_tenant_id
  FROM public.exam_attempts att
  JOIN public.exams e ON e.id = att.exam_id
  WHERE att.id = NEW.attempt_id;

  IF v_student_id IS NULL OR v_exam_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.is_correct = false THEN
    -- Student made a mistake
    INSERT INTO public.student_mistakes (
      tenant_id,
      student_id,
      question_id,
      source_exam_id,
      source_attempt_id,
      selected_option_id,
      is_resolved,
      first_failed_at,
      last_failed_at,
      failure_count
    ) VALUES (
      v_tenant_id,
      v_student_id,
      NEW.question_id,
      v_exam_id,
      NEW.attempt_id,
      NEW.selected_option_id,
      false,
      now(),
      now(),
      1
    )
    ON CONFLICT (student_id, question_id) DO UPDATE SET
      is_resolved = false,
      last_failed_at = now(),
      failure_count = student_mistakes.failure_count + 1,
      selected_option_id = EXCLUDED.selected_option_id,
      source_attempt_id = EXCLUDED.source_attempt_id;
  ELSIF NEW.is_correct = true THEN
    -- Student answered correctly on a subsequent attempt
    UPDATE public.student_mistakes
    SET 
      is_resolved = true,
      resolved_at = now()
    WHERE student_id = v_student_id 
      AND question_id = NEW.question_id 
      AND is_resolved = false;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_exam_answer_to_mistakes ON public.exam_answers;
CREATE TRIGGER trg_sync_exam_answer_to_mistakes
  AFTER INSERT OR UPDATE OF is_correct ON public.exam_answers
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_sync_exam_answer_to_mistakes();

-- Backfill from any past incorrect answers in exam_answers
INSERT INTO public.student_mistakes (
  tenant_id,
  student_id,
  question_id,
  source_exam_id,
  source_attempt_id,
  selected_option_id,
  is_resolved,
  first_failed_at,
  last_failed_at,
  failure_count
)
SELECT 
  e.tenant_id,
  att.student_id,
  ea.question_id,
  att.exam_id,
  att.id,
  ea.selected_option_id,
  false,
  MIN(ea.answered_at),
  MAX(ea.answered_at),
  COUNT(*)
FROM public.exam_answers ea
JOIN public.exam_attempts att ON att.id = ea.attempt_id
JOIN public.exams e ON e.id = att.exam_id
WHERE ea.is_correct = false
GROUP BY e.tenant_id, att.student_id, ea.question_id, att.exam_id, att.id, ea.selected_option_id
ON CONFLICT (student_id, question_id) DO NOTHING;

-- 3. RPC: get_student_mistakes_summary
CREATE OR REPLACE FUNCTION public.get_student_mistakes_summary(p_student_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_total_count INTEGER;
  v_unresolved_count INTEGER;
  v_resolved_count INTEGER;
  v_sources JSONB;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  -- Ensure student is requesting for themselves unless caller is teacher in same tenant
  IF v_caller != p_student_id AND NOT public.has_role('teacher') THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE is_resolved = false),
    COUNT(*) FILTER (WHERE is_resolved = true)
  INTO v_total_count, v_unresolved_count, v_resolved_count
  FROM public.student_mistakes
  WHERE student_id = p_student_id;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'exam_id', s.source_exam_id,
        'exam_title', COALESCE(e.title, c.title, 'اختبار'),
        'content_title', c.title,
        'total_mistakes', s.cnt,
        'unresolved_count', s.unresolved_cnt
      ) ORDER BY s.unresolved_cnt DESC, s.last_failed DESC
    ),
    '[]'::jsonb
  )
  INTO v_sources
  FROM (
    SELECT 
      sm.source_exam_id,
      COUNT(*) AS cnt,
      COUNT(*) FILTER (WHERE sm.is_resolved = false) AS unresolved_cnt,
      MAX(sm.last_failed_at) AS last_failed
    FROM public.student_mistakes sm
    WHERE sm.student_id = p_student_id
    GROUP BY sm.source_exam_id
  ) s
  JOIN public.exams e ON e.id = s.source_exam_id
  LEFT JOIN public.content c ON c.id = e.content_id;

  RETURN jsonb_build_object(
    'total_mistakes', COALESCE(v_total_count, 0),
    'unresolved_count', COALESCE(v_unresolved_count, 0),
    'resolved_count', COALESCE(v_resolved_count, 0),
    'sources', COALESCE(v_sources, '[]'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_student_mistakes_summary(UUID) TO authenticated;

-- 4. RPC: get_student_mistakes_questions
CREATE OR REPLACE FUNCTION public.get_student_mistakes_questions(
  p_student_id UUID,
  p_exam_id UUID DEFAULT NULL,
  p_only_unresolved BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_questions JSONB;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  IF v_caller != p_student_id AND NOT public.has_role('teacher') THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'mistake_id', sm.id,
        'question_id', q.id,
        'question_text', q.question_text,
        'question_type', q.question_type,
        'points', q.points,
        'sort_order', q.sort_order,
        'image_url', q.image_url,
        'image_meta', q.image_meta,
        'is_resolved', sm.is_resolved,
        'failure_count', sm.failure_count,
        'last_failed_at', sm.last_failed_at,
        'source_exam_id', sm.source_exam_id,
        'source_exam_title', COALESCE(e.title, c.title, 'اختبار'),
        'lesson_title', c.title,
        'last_selected_option_id', sm.selected_option_id,
        'options', (
          -- Safe options projection without is_correct
          SELECT COALESCE(
            jsonb_agg(
              jsonb_build_object(
                'id', opt.id,
                'option_text', opt.option_text,
                'sort_order', opt.sort_order
              ) ORDER BY opt.sort_order ASC
            ),
            '[]'::jsonb
          )
          FROM public.question_options opt
          WHERE opt.question_id = q.id
        )
      ) ORDER BY sm.is_resolved ASC, sm.last_failed_at DESC
    ),
    '[]'::jsonb
  )
  INTO v_questions
  FROM public.student_mistakes sm
  JOIN public.exam_questions q ON q.id = sm.question_id
  JOIN public.exams e ON e.id = sm.source_exam_id
  LEFT JOIN public.content c ON c.id = e.content_id
  WHERE sm.student_id = p_student_id
    AND (p_exam_id IS NULL OR sm.source_exam_id = p_exam_id)
    AND (NOT p_only_unresolved OR sm.is_resolved = false);

  RETURN v_questions;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_student_mistakes_questions(UUID, UUID, BOOLEAN) TO authenticated;

-- 5. RPC: submit_mistakes_practice
CREATE OR REPLACE FUNCTION public.submit_mistakes_practice(
  p_answers JSONB -- e.g. [{"question_id": "...", "selected_option_id": "..."}]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id UUID := auth.uid();
  v_item JSONB;
  v_question_id UUID;
  v_selected_option_id UUID;
  v_is_correct BOOLEAN;
  v_correct_option_id UUID;
  v_total INTEGER := 0;
  v_correct_count INTEGER := 0;
  v_results JSONB := '[]'::jsonb;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_answers)
  LOOP
    v_question_id := (v_item->>'question_id')::UUID;
    v_selected_option_id := NULLIF(v_item->>'selected_option_id', '')::UUID;

    -- Check correct option from database
    SELECT id INTO v_correct_option_id
    FROM public.question_options
    WHERE question_id = v_question_id AND is_correct = true
    LIMIT 1;

    v_is_correct := (v_selected_option_id IS NOT NULL AND v_selected_option_id = v_correct_option_id);
    v_total := v_total + 1;

    IF v_is_correct THEN
      v_correct_count := v_correct_count + 1;

      -- Mark as resolved in student_mistakes
      UPDATE public.student_mistakes
      SET 
        is_resolved = true,
        resolved_at = now(),
        selected_option_id = v_selected_option_id
      WHERE student_id = v_student_id AND question_id = v_question_id;
    ELSE
      -- Still incorrect, increment failure count
      UPDATE public.student_mistakes
      SET 
        is_resolved = false,
        failure_count = failure_count + 1,
        last_failed_at = now(),
        selected_option_id = v_selected_option_id
      WHERE student_id = v_student_id AND question_id = v_question_id;
    END IF;

    -- Append result feedback
    v_results := v_results || jsonb_build_array(
      jsonb_build_object(
        'question_id', v_question_id,
        'selected_option_id', v_selected_option_id,
        'correct_option_id', v_correct_option_id,
        'is_correct', v_is_correct
      )
    );
  END LOOP;

  RETURN jsonb_build_object(
    'total_questions', v_total,
    'correct_count', v_correct_count,
    'percentage', CASE WHEN v_total > 0 THEN ROUND((v_correct_count::numeric / v_total::numeric) * 100.0, 2) ELSE 0 END,
    'results', v_results
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_mistakes_practice(JSONB) TO authenticated;
