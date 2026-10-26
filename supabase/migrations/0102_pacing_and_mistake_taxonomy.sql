-- ============================================================================
-- Migration: 0102_pacing_and_mistake_taxonomy.sql
-- Description:
-- 1. Add reflection_reason column to public.student_mistakes for Student Error Taxonomy.
-- 2. Add metadata & timing support to public.exam_attempts & public.exam_answers.
-- 3. Create update_mistake_reflection RPC for students to record their learning reflections.
-- 4. Enhance get_student_mistakes_summary and get_student_mistakes_questions to return taxonomy.
-- ============================================================================

-- 1. Add reflection_reason column to public.student_mistakes
ALTER TABLE public.student_mistakes
ADD COLUMN IF NOT EXISTS reflection_reason text
CHECK (reflection_reason IN ('concept_gap', 'careless_error', 'misread_question', 'time_pressure'));

-- 2. Add metadata columns for Exam Pacing Radar and Guess Flags
ALTER TABLE public.exam_attempts
ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

ALTER TABLE public.exam_answers
ADD COLUMN IF NOT EXISTS time_spent_seconds integer DEFAULT NULL,
ADD COLUMN IF NOT EXISTS is_flagged_guess boolean DEFAULT false;

-- 3. Create RPC: update_mistake_reflection
CREATE OR REPLACE FUNCTION public.update_mistake_reflection(
  p_mistake_id UUID,
  p_reflection_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_student_id UUID;
  v_updated_row JSONB;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  -- Validate reflection reason value
  IF p_reflection_reason IS NOT NULL AND p_reflection_reason NOT IN ('concept_gap', 'careless_error', 'misread_question', 'time_pressure') THEN
    RAISE EXCEPTION 'INVALID_REFLECTION_REASON';
  END IF;

  -- Verify mistake exists and belongs to caller
  SELECT student_id INTO v_student_id
  FROM public.student_mistakes
  WHERE id = p_mistake_id;

  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'MISTAKE_NOT_FOUND';
  END IF;

  IF v_caller != v_student_id AND NOT public.has_role('teacher') THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  UPDATE public.student_mistakes
  SET reflection_reason = p_reflection_reason
  WHERE id = p_mistake_id;

  RETURN jsonb_build_object(
    'success', true,
    'mistake_id', p_mistake_id,
    'reflection_reason', p_reflection_reason
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_mistake_reflection(UUID, TEXT) TO authenticated;

-- 4. Enhance get_student_mistakes_summary with Reflection Taxonomy counts
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
  -- Taxonomy counts
  v_concept_gap_count INTEGER;
  v_careless_error_count INTEGER;
  v_misread_question_count INTEGER;
  v_time_pressure_count INTEGER;
  v_unclassified_count INTEGER;
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
    COUNT(*) FILTER (WHERE selected_option_id IS NULL),
    COUNT(*) FILTER (WHERE reflection_reason = 'concept_gap'),
    COUNT(*) FILTER (WHERE reflection_reason = 'careless_error'),
    COUNT(*) FILTER (WHERE reflection_reason = 'misread_question'),
    COUNT(*) FILTER (WHERE reflection_reason = 'time_pressure'),
    COUNT(*) FILTER (WHERE reflection_reason IS NULL AND is_resolved = false)
  INTO 
    v_total_count, 
    v_unresolved_count, 
    v_resolved_count,
    v_unresolved_wrong_count,
    v_unresolved_skipped_count,
    v_total_wrong_count,
    v_total_skipped_count,
    v_concept_gap_count,
    v_careless_error_count,
    v_misread_question_count,
    v_time_pressure_count,
    v_unclassified_count
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
    'concept_gap_count', COALESCE(v_concept_gap_count, 0),
    'careless_error_count', COALESCE(v_careless_error_count, 0),
    'misread_question_count', COALESCE(v_misread_question_count, 0),
    'time_pressure_count', COALESCE(v_time_pressure_count, 0),
    'unclassified_count', COALESCE(v_unclassified_count, 0),
    'sources', COALESCE(v_sources, '[]'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_student_mistakes_summary(UUID) TO authenticated;

-- 5. Enhance get_student_mistakes_questions with reflection_reason
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
        'reflection_reason', sm.reflection_reason,
        'selected_option_text', (
          SELECT opt.option_text 
          FROM public.question_options opt 
          WHERE opt.id = sm.selected_option_id
          LIMIT 1
        ),
        'options', (
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
