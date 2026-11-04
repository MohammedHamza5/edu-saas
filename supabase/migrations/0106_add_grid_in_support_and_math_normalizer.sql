-- ==============================================================================
-- Migration: 0106_add_grid_in_support_and_math_normalizer.sql
-- Description:
--   1. Adds 'grid_in' (Student-Produced Response / Numerical) question type to exam_questions.
--   2. Adds text_answer column to exam_answers for numerical/text student inputs.
--   3. Introduces Mathematical Normalization functions in PostgreSQL (fractions, decimals,
--      Arabic/English numerals, decimal comma conversions, whitespace, and floating-point tolerance).
--   4. Updates sync_exam_answers, submit_exam, and get_exam_review RPCs to natively
--      grade and persist grid_in questions without breaking multiple choice.
-- ==============================================================================

-- 1. Support 'grid_in' question type in exam_questions
ALTER TABLE public.exam_questions DROP CONSTRAINT IF EXISTS exam_questions_question_type_check;
ALTER TABLE public.exam_questions ADD CONSTRAINT exam_questions_question_type_check 
  CHECK (question_type IN ('multiple_choice', 'true_false', 'grid_in'));

-- 2. Add text_answer column to exam_answers
ALTER TABLE public.exam_answers ADD COLUMN IF NOT EXISTS text_answer text NULL;

-- 3. Mathematical Normalization Engine
CREATE OR REPLACE FUNCTION public.normalize_math_answer(p_input text)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_cleaned text;
  v_num numeric;
  v_den numeric;
BEGIN
  IF p_input IS NULL OR trim(p_input) = '' THEN
    RETURN NULL;
  END IF;

  v_cleaned := trim(p_input);

  -- 3.1 Translate Eastern Arabic & Persian numerals to Western ASCII digits
  v_cleaned := translate(v_cleaned, '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789');

  -- 3.2 Translate Arabic decimal separator (٫) and comma (,) to dot (.)
  v_cleaned := replace(v_cleaned, '٫', '.');
  v_cleaned := replace(v_cleaned, ',', '.');

  -- 3.3 Translate Unicode minus / dashes to standard hyphen-minus
  v_cleaned := replace(v_cleaned, '−', '-');
  v_cleaned := replace(v_cleaned, '–', '-');
  v_cleaned := replace(v_cleaned, '—', '-');

  -- 3.4 Strip all remaining whitespaces
  v_cleaned := regexp_replace(v_cleaned, '\s+', '', 'g');

  -- 3.5 Handle Fractions (e.g. 1/2, -3/4, 25/5)
  IF v_cleaned ~ '^-?[0-9]+(\.[0-9]+)?/[0-9]+(\.[0-9]+)?$' THEN
    BEGIN
      v_num := split_part(v_cleaned, '/', 1)::numeric;
      v_den := split_part(v_cleaned, '/', 2)::numeric;
      IF v_den = 0 THEN
        RETURN NULL;
      END IF;
      RETURN round(v_num / v_den, 6);
    EXCEPTION WHEN OTHERS THEN
      RETURN NULL;
    END;
  END IF;

  -- 3.6 Handle Decimals and Integers (e.g. .5, 0.5, -3, 8)
  IF v_cleaned ~ '^-?\.?[0-9]+(\.[0-9]+)?$' OR v_cleaned ~ '^-?[0-9]+\.?$' THEN
    BEGIN
      RETURN round(v_cleaned::numeric, 6);
    EXCEPTION WHEN OTHERS THEN
      RETURN NULL;
    END;
  END IF;

  RETURN NULL;
END;
$$;

-- 4. Mathematical Equivalence Checker
CREATE OR REPLACE FUNCTION public.is_math_answer_correct(p_student_text text, p_correct_text text)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_s_num numeric;
  v_c_num numeric;
BEGIN
  IF p_student_text IS NULL OR trim(p_student_text) = '' THEN
    RETURN false;
  END IF;

  IF p_correct_text IS NULL OR trim(p_correct_text) = '' THEN
    RETURN false;
  END IF;

  -- Direct case-insensitive string match
  IF trim(lower(p_student_text)) = trim(lower(p_correct_text)) THEN
    RETURN true;
  END IF;

  v_s_num := public.normalize_math_answer(p_student_text);
  v_c_num := public.normalize_math_answer(p_correct_text);

  IF v_s_num IS NOT NULL AND v_c_num IS NOT NULL THEN
    IF abs(v_s_num - v_c_num) < 0.001 THEN
      RETURN true;
    END IF;
  END IF;

  RETURN false;
END;
$$;

-- 5. Update sync_exam_answers to handle both UUID option IDs (MCQ) and text answers (Grid-in)
CREATE OR REPLACE FUNCTION public.sync_exam_answers(
    p_attempt_id uuid,
    p_answers jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_student_id uuid := auth.uid();
    v_attempt record;
    v_q_id text;
    v_val text;
    v_synced_count int := 0;
    v_is_uuid boolean;
BEGIN
    IF v_student_id IS NULL THEN
        RAISE EXCEPTION 'AUTH_REQUIRED: User must be authenticated';
    END IF;

    SELECT id, exam_id, status INTO v_attempt
    FROM public.exam_attempts
    WHERE id = p_attempt_id AND student_id = v_student_id;

    IF v_attempt.id IS NULL THEN
        RAISE EXCEPTION 'ATTEMPT_NOT_FOUND: Attempt not found or not owned by student';
    END IF;

    IF v_attempt.status <> 'in_progress' THEN
        RETURN jsonb_build_object(
            'success', false,
            'status', v_attempt.status,
            'message', 'Attempt is not in progress'
        );
    END IF;

    FOR v_q_id, v_val IN SELECT * FROM jsonb_each_text(p_answers)
    LOOP
        IF v_val IS NOT NULL AND v_val <> '' AND v_val <> 'null' THEN
            -- Check if value is a valid UUID
            v_is_uuid := (v_val ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

            IF v_is_uuid THEN
                INSERT INTO public.exam_answers (
                    attempt_id,
                    question_id,
                    selected_option_id,
                    text_answer,
                    answered_at
                )
                VALUES (
                    p_attempt_id,
                    v_q_id::uuid,
                    v_val::uuid,
                    NULL,
                    now()
                )
                ON CONFLICT (attempt_id, question_id)
                DO UPDATE SET 
                    selected_option_id = EXCLUDED.selected_option_id,
                    text_answer = NULL,
                    answered_at = EXCLUDED.answered_at;
            ELSE
                INSERT INTO public.exam_answers (
                    attempt_id,
                    question_id,
                    selected_option_id,
                    text_answer,
                    answered_at
                )
                VALUES (
                    p_attempt_id,
                    v_q_id::uuid,
                    NULL,
                    v_val,
                    now()
                )
                ON CONFLICT (attempt_id, question_id)
                DO UPDATE SET 
                    selected_option_id = NULL,
                    text_answer = EXCLUDED.text_answer,
                    answered_at = EXCLUDED.answered_at;
            END IF;

            v_synced_count := v_synced_count + 1;
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'attempt_id', p_attempt_id,
        'synced_count', v_synced_count
    );
END;
$$;

-- 6. Update submit_exam to evaluate both MCQ and Grid-in questions
CREATE OR REPLACE FUNCTION public.submit_exam(
  p_attempt_id uuid,
  p_answers jsonb,
  p_reason text DEFAULT 'student_submitted'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id uuid := auth.uid();
  v_attempt record;
  v_exam record;
  v_question record;
  v_input_val text;
  v_is_correct boolean;
  v_points_earned numeric(8,2);
  v_total_score numeric(8,2) := 0;
  v_max_score numeric(8,2) := 0;
  v_percentage numeric(5,2) := 0;
  v_status text;
  v_reason text := COALESCE(p_reason, 'student_submitted');
  v_is_lecture_exam boolean;
  v_is_uuid boolean;
  v_matching_opt_id uuid;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be authenticated';
  END IF;

  SELECT * INTO v_attempt
  FROM public.exam_attempts
  WHERE id = p_attempt_id AND student_id = v_student_id;

  IF v_attempt.id IS NULL THEN
    RAISE EXCEPTION 'ATTEMPT_NOT_FOUND: Attempt does not exist';
  END IF;

  -- Idempotency check
  IF v_attempt.status IN ('submitted', 'expired') THEN
    SELECT show_result INTO v_exam FROM public.exams WHERE id = v_attempt.exam_id;
    RETURN jsonb_build_object(
      'attempt_id', v_attempt.id,
      'exam_id', v_attempt.exam_id,
      'status', v_attempt.status,
      'submission_reason', v_attempt.submission_reason,
      'score', CASE WHEN v_exam.show_result THEN v_attempt.score ELSE NULL END,
      'percentage', CASE WHEN v_exam.show_result THEN v_attempt.percentage ELSE NULL END
    );
  END IF;

  SELECT e.*, c.group_id INTO v_exam
  FROM public.exams e
  JOIN public.content c ON c.id = e.content_id
  WHERE e.id = v_attempt.exam_id;

  v_is_lecture_exam :=
    (v_exam.duration_minutes IS NULL OR v_exam.duration_minutes <= 0)
    OR EXISTS (
      SELECT 1 FROM public.content_groups cg
      WHERE cg.associated_exam_id = v_exam.id OR cg.prerequisite_exam_id = v_exam.id
    )
    OR EXISTS (
      SELECT 1 FROM public.content c2
      WHERE c2.associated_exam_id = v_exam.id OR c2.prerequisite_exam_id = v_exam.id
    );

  -- Determine final status & reason
  IF NOT v_is_lecture_exam AND v_exam.duration_minutes > 0
     AND (v_attempt.started_at + (v_exam.duration_minutes || ' minutes')::interval) < now() THEN
    v_status := 'expired';
    IF v_reason = 'student_submitted' THEN
      v_reason := 'time_expired';
    END IF;
  ELSE
    v_status := 'submitted';
  END IF;

  -- Grade questions
  FOR v_question IN
    SELECT eq.id, eq.points, eq.question_type
    FROM public.exam_questions eq
    WHERE eq.exam_version_id = v_attempt.exam_version_id
  LOOP
    v_max_score := v_max_score + v_question.points;
    v_is_correct := false;
    v_points_earned := 0;
    v_matching_opt_id := NULL;

    -- Extract student input safely as text
    v_input_val := p_answers->>v_question.id::text;

    -- If not passed in p_answers, inspect pre-synced value in exam_answers
    IF v_input_val IS NULL OR v_input_val = '' OR v_input_val = 'null' THEN
      IF v_question.question_type = 'grid_in' THEN
        SELECT text_answer INTO v_input_val
        FROM public.exam_answers
        WHERE attempt_id = p_attempt_id AND question_id = v_question.id;
      ELSE
        SELECT selected_option_id::text INTO v_input_val
        FROM public.exam_answers
        WHERE attempt_id = p_attempt_id AND question_id = v_question.id;
      END IF;
    END IF;

    IF v_input_val IS NOT NULL AND v_input_val <> '' AND v_input_val <> 'null' THEN
      IF v_question.question_type = 'grid_in' THEN
        -- Check if student's normalized math answer matches any correct model answer
        SELECT qo.id INTO v_matching_opt_id
        FROM public.question_options qo
        WHERE qo.question_id = v_question.id
          AND qo.is_correct = true
          AND public.is_math_answer_correct(v_input_val, qo.option_text)
        LIMIT 1;

        IF v_matching_opt_id IS NOT NULL THEN
          v_is_correct := true;
          v_points_earned := v_question.points;
          v_total_score := v_total_score + v_points_earned;
        ELSE
          v_is_correct := false;
          v_points_earned := 0;
        END IF;

        INSERT INTO public.exam_answers (
          attempt_id, question_id, selected_option_id, text_answer, is_correct, points_earned
        )
        VALUES (
          p_attempt_id, v_question.id, v_matching_opt_id, v_input_val, v_is_correct, v_points_earned
        )
        ON CONFLICT (attempt_id, question_id)
        DO UPDATE SET
          selected_option_id = EXCLUDED.selected_option_id,
          text_answer = EXCLUDED.text_answer,
          is_correct = EXCLUDED.is_correct,
          points_earned = EXCLUDED.points_earned;
      ELSE
        -- Standard Multiple Choice / True-False logic
        v_is_uuid := (v_input_val ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
        IF v_is_uuid THEN
          SELECT is_correct INTO v_is_correct
          FROM public.question_options
          WHERE id = v_input_val::uuid AND question_id = v_question.id;

          IF v_is_correct IS TRUE THEN
            v_points_earned := v_question.points;
            v_total_score := v_total_score + v_points_earned;
          ELSE
            v_points_earned := 0;
            v_is_correct := false;
          END IF;

          INSERT INTO public.exam_answers (
            attempt_id, question_id, selected_option_id, text_answer, is_correct, points_earned
          )
          VALUES (
            p_attempt_id, v_question.id, v_input_val::uuid, NULL, v_is_correct, v_points_earned
          )
          ON CONFLICT (attempt_id, question_id)
          DO UPDATE SET
            selected_option_id = EXCLUDED.selected_option_id,
            text_answer = NULL,
            is_correct = EXCLUDED.is_correct,
            points_earned = EXCLUDED.points_earned;
        ELSE
          -- Unparseable answer for multiple choice
          INSERT INTO public.exam_answers (attempt_id, question_id, selected_option_id, text_answer, is_correct, points_earned)
          VALUES (p_attempt_id, v_question.id, NULL, v_input_val, false, 0)
          ON CONFLICT (attempt_id, question_id)
          DO UPDATE SET
            selected_option_id = NULL,
            text_answer = EXCLUDED.text_answer,
            is_correct = false,
            points_earned = 0;
        END IF;
      END IF;
    ELSE
      -- Skipped question
      INSERT INTO public.exam_answers (attempt_id, question_id, selected_option_id, text_answer, is_correct, points_earned)
      VALUES (p_attempt_id, v_question.id, NULL, NULL, false, 0)
      ON CONFLICT (attempt_id, question_id)
      DO UPDATE SET
        selected_option_id = NULL,
        text_answer = NULL,
        is_correct = false,
        points_earned = 0;
    END IF;
  END LOOP;

  IF v_max_score > 0 THEN
    v_percentage := round((v_total_score / v_max_score) * 100, 2);
  ELSE
    v_percentage := 0;
  END IF;

  UPDATE public.exam_attempts
  SET
    status = v_status,
    submission_reason = v_reason,
    score = v_total_score::integer,
    percentage = v_percentage,
    submitted_at = now()
  WHERE id = p_attempt_id;

  INSERT INTO public.activity_events (tenant_id, user_id, group_id, content_id, event_type, metadata)
  VALUES (
    v_exam.tenant_id, v_student_id, v_exam.group_id, v_exam.content_id, 'exam_submitted',
    jsonb_build_object(
      'attempt_id', p_attempt_id,
      'score', v_total_score,
      'max_score', v_max_score,
      'percentage', v_percentage,
      'submission_reason', v_reason
    )
  );

  RETURN jsonb_build_object(
    'attempt_id', p_attempt_id,
    'exam_id', v_attempt.exam_id,
    'status', v_status,
    'submission_reason', v_reason,
    'score', CASE WHEN v_exam.show_result THEN v_total_score::integer ELSE NULL END,
    'percentage', CASE WHEN v_exam.show_result THEN v_percentage ELSE NULL END
  );
END;
$$;

-- 7. Update get_exam_review to return text_answer for grid_in questions
CREATE OR REPLACE FUNCTION public.get_exam_review(p_attempt_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id   uuid := auth.uid();
  v_attempt     record;
  v_exam        record;
  v_questions   jsonb := '[]'::jsonb;
  v_answers     jsonb := '[]'::jsonb;
  v_is_teacher  boolean := false;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be authenticated';
  END IF;

  SELECT * INTO v_attempt
  FROM public.exam_attempts
  WHERE id = p_attempt_id;

  IF v_attempt.id IS NULL THEN
    RAISE EXCEPTION 'ATTEMPT_NOT_FOUND: Attempt does not exist';
  END IF;

  SELECT (role = 'teacher') INTO v_is_teacher
  FROM public.users
  WHERE id = v_caller_id;

  IF v_attempt.student_id != v_caller_id AND NOT COALESCE(v_is_teacher, false) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: You are not authorized to view this attempt review';
  END IF;

  IF v_attempt.status != 'submitted' THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only submitted attempts can be reviewed';
  END IF;

  SELECT * INTO v_exam
  FROM public.exams
  WHERE id = v_attempt.exam_id;

  -- Build questions with options (including is_correct for post-submission review)
  SELECT COALESCE(jsonb_agg(q_item), '[]'::jsonb) INTO v_questions
  FROM (
    SELECT
      eq.id,
      eq.exam_version_id,
      eq.question_text,
      eq.question_type,
      eq.points,
      eq.sort_order,
      eq.image_url,
      eq.image_meta,
      eq.context_id,
      (
        SELECT COALESCE(jsonb_agg(
          jsonb_build_object(
            'id', qo.id,
            'question_id', qo.question_id,
            'option_text', qo.option_text,
            'sort_order', qo.sort_order,
            'image_url', qo.image_url,
            'image_meta', qo.image_meta,
            'is_correct', qo.is_correct
          ) ORDER BY qo.sort_order, qo.id
        ), '[]'::jsonb)
        FROM public.question_options qo
        WHERE qo.question_id = eq.id
      ) AS options
    FROM public.exam_questions eq
    WHERE eq.exam_version_id = v_attempt.exam_version_id
    ORDER BY eq.sort_order, eq.id
  ) q_item;

  -- Build answers including text_answer
  SELECT COALESCE(jsonb_agg(a_item), '[]'::jsonb) INTO v_answers
  FROM (
    SELECT
      ea.id,
      ea.attempt_id,
      ea.question_id,
      ea.selected_option_id,
      ea.text_answer,
      ea.is_correct,
      ea.points_earned,
      ea.answered_at
    FROM public.exam_answers ea
    WHERE ea.attempt_id = v_attempt.id
  ) a_item;

  RETURN jsonb_build_object(
    'id', v_attempt.id,
    'exam_id', v_attempt.exam_id,
    'exam_version_id', v_attempt.exam_version_id,
    'student_id', v_attempt.student_id,
    'started_at', v_attempt.started_at,
    'submitted_at', v_attempt.submitted_at,
    'status', v_attempt.status,
    'score', v_attempt.score,
    'percentage', v_attempt.percentage,
    'questions', v_questions,
    'answers', v_answers
  );
END;
$$;
