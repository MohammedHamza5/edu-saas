-- ==============================================================================
-- Migration: 0117_fix_grid_in_mistakes_practice.sql
-- Description:
--   1. Adds text_answer column to public.student_mistakes for numerical/grid-in inputs.
--   2. Updates fn_sync_exam_answer_to_mistakes trigger to sync text_answer from exam_answers.
--   3. Updates get_student_mistakes_questions RPC:
--      - For grid_in questions, returns '[]'::jsonb for options to prevent leaking the answer key.
--      - Resolves selected_option_text to previous text_answer for grid_in questions.
--      - Accurately computes is_skipped for both multiple-choice and grid-in questions.
--   4. Updates submit_mistakes_practice RPC to support numerical/grid-in evaluation using
--      public.is_math_answer_correct(student_answer, correct_answer).
--   5. Updates get_student_mistakes_summary RPC to recognize text_answer in skipped counts.
-- ==============================================================================

-- 1. Add text_answer column to public.student_mistakes
ALTER TABLE public.student_mistakes ADD COLUMN IF NOT EXISTS text_answer text NULL;

-- 2. Update trigger function on exam_answers to sync text_answer
CREATE OR REPLACE FUNCTION public.fn_sync_exam_answer_to_mistakes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant_id UUID;
  v_student_id UUID;
  v_exam_id UUID;
BEGIN
  -- Fetch attempt context
  SELECT att.tenant_id, att.student_id, att.exam_id
  INTO v_tenant_id, v_student_id, v_exam_id
  FROM public.exam_attempts att
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
      text_answer,
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
      NEW.text_answer,
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
      text_answer = EXCLUDED.text_answer,
      source_attempt_id = EXCLUDED.source_attempt_id;
  ELSIF NEW.is_correct = true THEN
    -- Student answered correctly on a subsequent attempt
    UPDATE public.student_mistakes
    SET 
      is_resolved = true,
      resolved_at = now(),
      selected_option_id = NEW.selected_option_id,
      text_answer = NEW.text_answer
    WHERE student_id = v_student_id 
      AND question_id = NEW.question_id 
      AND is_resolved = false;
  END IF;

  RETURN NEW;
END;
$$;

-- 3. Update get_student_mistakes_questions RPC
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
        'audio_url', q.audio_url,
        'audio_duration_seconds', q.audio_duration_seconds,
        'is_resolved', sm.is_resolved,
        'failure_count', sm.failure_count,
        'last_failed_at', sm.last_failed_at,
        'source_exam_id', sm.source_exam_id,
        'source_exam_title', COALESCE(e.title, c.title, 'اختبار'),
        'lesson_title', c.title,
        'last_selected_option_id', sm.selected_option_id,
        'is_skipped', (sm.selected_option_id IS NULL AND (sm.text_answer IS NULL OR trim(sm.text_answer) = '')),
        'reflection_reason', sm.reflection_reason,
        'selected_option_text', CASE 
          WHEN q.question_type = 'grid_in' THEN sm.text_answer
          ELSE (
            SELECT opt.option_text 
            FROM public.question_options opt 
            WHERE opt.id = sm.selected_option_id
            LIMIT 1
          )
        END,
        -- For grid_in questions, options must remain empty to prevent exposing the answer key
        'options', CASE 
          WHEN q.question_type = 'grid_in' THEN '[]'::jsonb
          ELSE (
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
        END
      ) ORDER BY sm.is_resolved ASC, sm.last_failed_at DESC
    ),
    '[]'::jsonb
  )
  INTO v_questions
  FROM public.student_mistakes sm
  JOIN public.exam_questions q ON q.id = sm.question_id
  JOIN public.exam_versions ev ON ev.id = q.exam_version_id
  JOIN public.exams ex ON ex.id = ev.exam_id
  JOIN public.content c ON c.id = ex.content_id
  LEFT JOIN public.exams e ON e.id = sm.source_exam_id
  WHERE sm.student_id = p_student_id
    AND (NOT p_only_unresolved OR sm.is_resolved = FALSE)
    AND (p_exam_id IS NULL OR sm.source_exam_id = p_exam_id);

  RETURN v_questions;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_student_mistakes_questions(UUID, UUID, BOOLEAN) TO authenticated;

-- 4. Update submit_mistakes_practice RPC to handle grid_in questions
CREATE OR REPLACE FUNCTION public.submit_mistakes_practice(
  p_answers JSONB -- e.g. [{"question_id": "...", "selected_option_id": "...", "text_answer": "..."}]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_student_id UUID := auth.uid();
  v_item JSONB;
  v_question_id UUID;
  v_selected_option_id UUID;
  v_text_answer TEXT;
  v_question_type TEXT;
  v_is_correct BOOLEAN;
  v_correct_option_id UUID;
  v_correct_text TEXT;
  v_total INTEGER := 0;
  v_correct_count INTEGER := 0;
  v_results JSONB := '[]'::jsonb;
  v_is_legitimate_mistake BOOLEAN;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be authenticated';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_answers)
  LOOP
    v_question_id := (v_item->>'question_id')::UUID;
    v_selected_option_id := NULLIF(v_item->>'selected_option_id', '')::UUID;
    v_text_answer := trim(v_item->>'text_answer');

    -- Security check: Verify that this question actually exists in the student's mistakes bank
    SELECT EXISTS (
      SELECT 1 FROM public.student_mistakes sm
      WHERE sm.student_id = v_student_id AND sm.question_id = v_question_id
    ) INTO v_is_legitimate_mistake;

    IF NOT v_is_legitimate_mistake THEN
      -- Silently skip illegitimate question to prevent oracle extraction
      CONTINUE;
    END IF;

    -- Fetch question type and correct option data from database
    SELECT q.question_type, qo.id, qo.option_text
    INTO v_question_type, v_correct_option_id, v_correct_text
    FROM public.exam_questions q
    LEFT JOIN public.question_options qo ON qo.question_id = q.id AND qo.is_correct = true
    WHERE q.id = v_question_id
    LIMIT 1;

    -- Grade according to question type
    IF v_question_type = 'grid_in' THEN
      v_is_correct := public.is_math_answer_correct(v_text_answer, v_correct_text);
    ELSE
      v_is_correct := (v_selected_option_id IS NOT NULL AND v_selected_option_id = v_correct_option_id);
    END IF;

    v_total := v_total + 1;

    IF v_is_correct THEN
      v_correct_count := v_correct_count + 1;

      -- Mark as resolved in student_mistakes
      UPDATE public.student_mistakes
      SET 
        is_resolved = true,
        resolved_at = now(),
        selected_option_id = v_selected_option_id,
        text_answer = CASE WHEN v_question_type = 'grid_in' THEN v_text_answer ELSE text_answer END
      WHERE student_id = v_student_id AND question_id = v_question_id;
    ELSE
      -- Still incorrect, increment failure count
      UPDATE public.student_mistakes
      SET 
        is_resolved = false,
        failure_count = failure_count + 1,
        last_failed_at = now(),
        selected_option_id = v_selected_option_id,
        text_answer = CASE WHEN v_question_type = 'grid_in' THEN v_text_answer ELSE text_answer END
      WHERE student_id = v_student_id AND question_id = v_question_id;
    END IF;

    -- Append result feedback
    v_results := v_results || jsonb_build_array(
      jsonb_build_object(
        'question_id', v_question_id,
        'question_type', v_question_type,
        'selected_option_id', v_selected_option_id,
        'text_answer', v_text_answer,
        'correct_option_id', v_correct_option_id,
        'correct_text', CASE WHEN v_question_type = 'grid_in' THEN v_correct_text ELSE NULL END,
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

-- 5. Update get_student_mistakes_summary RPC to account for text_answer
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
    COUNT(*) FILTER (WHERE is_resolved = false AND (selected_option_id IS NOT NULL OR (text_answer IS NOT NULL AND trim(text_answer) != ''))),
    COUNT(*) FILTER (WHERE is_resolved = false AND selected_option_id IS NULL AND (text_answer IS NULL OR trim(text_answer) = '')),
    COUNT(*) FILTER (WHERE selected_option_id IS NOT NULL OR (text_answer IS NOT NULL AND trim(text_answer) != '')),
    COUNT(*) FILTER (WHERE selected_option_id IS NULL AND (text_answer IS NULL OR trim(text_answer) = '')),
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
        'total_mistakes', s.total,
        'unresolved_count', s.unresolved
      )
    ),
    '[]'::jsonb
  )
  INTO v_sources
  FROM (
    SELECT 
      sm.source_exam_id,
      COUNT(*) AS total,
      COUNT(*) FILTER (WHERE sm.is_resolved = false) AS unresolved
    FROM public.student_mistakes sm
    WHERE sm.student_id = p_student_id
    GROUP BY sm.source_exam_id
  ) s
  LEFT JOIN public.exams e ON e.id = s.source_exam_id
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
    'sources', v_sources
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_student_mistakes_summary(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
