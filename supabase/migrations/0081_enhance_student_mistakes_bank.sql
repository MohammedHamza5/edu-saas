-- ============================================================================
-- Migration: 0081_enhance_student_mistakes_bank.sql
-- Description:
-- 1. Enhance public.get_student_mistakes_summary to return granular counts
--    for wrong answers vs skipped questions.
-- 2. Enhance public.get_student_mistakes_questions to include is_skipped and
--    selected_option_text for instant clear student feedback.
-- 3. Idempotent safe backfill to ensure any unattempted questions in submitted
--    attempts are reflected in student_mistakes.
-- ============================================================================

-- 1. Enhance get_student_mistakes_summary
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
  v_unresolved_wrong_count INTEGER;
  v_unresolved_skipped_count INTEGER;
  v_total_wrong_count INTEGER;
  v_total_skipped_count INTEGER;
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
    COUNT(*) FILTER (WHERE is_resolved = true),
    COUNT(*) FILTER (WHERE is_resolved = false AND selected_option_id IS NOT NULL),
    COUNT(*) FILTER (WHERE is_resolved = false AND selected_option_id IS NULL),
    COUNT(*) FILTER (WHERE selected_option_id IS NOT NULL),
    COUNT(*) FILTER (WHERE selected_option_id IS NULL)
  INTO 
    v_total_count, 
    v_unresolved_count, 
    v_resolved_count,
    v_unresolved_wrong_count,
    v_unresolved_skipped_count,
    v_total_wrong_count,
    v_total_skipped_count
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
    'unresolved_wrong_count', COALESCE(v_unresolved_wrong_count, 0),
    'unresolved_skipped_count', COALESCE(v_unresolved_skipped_count, 0),
    'total_wrong_count', COALESCE(v_total_wrong_count, 0),
    'total_skipped_count', COALESCE(v_total_skipped_count, 0),
    'sources', COALESCE(v_sources, '[]'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_student_mistakes_summary(UUID) TO authenticated;

-- 2. Enhance get_student_mistakes_questions
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
        'is_skipped', (sm.selected_option_id IS NULL),
        'selected_option_text', (
          SELECT opt.option_text 
          FROM public.question_options opt 
          WHERE opt.id = sm.selected_option_id
          LIMIT 1
        ),
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

-- 3. Idempotent backfill of any unattempted questions from submitted attempts
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
  NULL,
  false,
  COALESCE(MIN(ea.answered_at), att.submitted_at, now()),
  COALESCE(MAX(ea.answered_at), att.submitted_at, now()),
  1
FROM public.exam_answers ea
JOIN public.exam_attempts att ON att.id = ea.attempt_id
JOIN public.exams e ON e.id = att.exam_id
WHERE ea.is_correct = false 
  AND ea.selected_option_id IS NULL
  AND att.status IN ('submitted', 'expired')
GROUP BY e.tenant_id, att.student_id, ea.question_id, att.exam_id, att.id, att.submitted_at
ON CONFLICT (student_id, question_id) DO NOTHING;

NOTIFY pgrst, 'reload schema';
