-- 0082_auto_finalize_exam_attempts_and_submission_reasons.sql
-- 1. Adds submission_reason to public.exam_attempts
-- 2. Implements auto_finalize_expired_attempts to automatically grade and close abandoned/expired exams
-- 3. Updates submit_exam to accept submission_reason ('student_submitted', 'time_expired', 'forced_exit', 'security_violations', 'tab_closed', 'system_timeout')
-- 4. Updates get_exam_review to allow review of both 'submitted' and 'expired' attempts

-- 1. Schema enhancement
ALTER TABLE public.exam_attempts
ADD COLUMN IF NOT EXISTS submission_reason text DEFAULT 'student_submitted';

-- Backfill legacy expired attempts
UPDATE public.exam_attempts
SET submission_reason = 'time_expired'
WHERE status = 'expired' AND (submission_reason IS NULL OR submission_reason = 'student_submitted');

-- 2. Atomic Auto-Finalization of expired attempts (handles laptop closing, browser exit, power cuts, timer expiry)
CREATE OR REPLACE FUNCTION public.auto_finalize_expired_attempts(p_exam_id uuid DEFAULT NULL)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_attempt record;
  v_question record;
  v_selected_opt_id uuid;
  v_is_correct boolean;
  v_points_earned numeric(8,2);
  v_total_score numeric(8,2);
  v_max_score numeric(8,2);
  v_percentage numeric(5,2);
  v_finalized_count int := 0;
BEGIN
  -- Loop through all active in_progress attempts whose allowed duration has elapsed
  FOR v_attempt IN
    SELECT a.id, a.exam_id, a.exam_version_id, a.student_id, a.started_at, e.duration_minutes, e.tenant_id, e.content_id
    FROM public.exam_attempts a
    JOIN public.exams e ON e.id = a.exam_id
    WHERE a.status = 'in_progress'
      AND (p_exam_id IS NULL OR a.exam_id = p_exam_id)
      AND e.duration_minutes IS NOT NULL
      AND e.duration_minutes > 0
      AND (a.started_at + (e.duration_minutes || ' minutes')::interval) < now()
  LOOP
    v_total_score := 0;
    v_max_score := 0;

    -- Grade each question in this exam version based on what was synced to exam_answers
    FOR v_question IN
      SELECT eq.id, eq.points
      FROM public.exam_questions eq
      WHERE eq.exam_version_id = v_attempt.exam_version_id
    LOOP
      v_max_score := v_max_score + v_question.points;

      -- Check if student selected an option
      SELECT selected_option_id INTO v_selected_opt_id
      FROM public.exam_answers
      WHERE attempt_id = v_attempt.id AND question_id = v_question.id;

      IF v_selected_opt_id IS NOT NULL THEN
        SELECT is_correct INTO v_is_correct
        FROM public.question_options
        WHERE id = v_selected_opt_id AND question_id = v_question.id;

        IF v_is_correct IS TRUE THEN
          v_points_earned := v_question.points;
          v_total_score := v_total_score + v_points_earned;
        ELSE
          v_points_earned := 0;
          v_is_correct := false;
        END IF;

        UPDATE public.exam_answers
        SET is_correct = v_is_correct, points_earned = v_points_earned
        WHERE attempt_id = v_attempt.id AND question_id = v_question.id;
      ELSE
        -- Insert skipped answer
        INSERT INTO public.exam_answers (attempt_id, question_id, selected_option_id, is_correct, points_earned)
        VALUES (v_attempt.id, v_question.id, NULL, false, 0)
        ON CONFLICT (attempt_id, question_id)
        DO UPDATE SET selected_option_id = NULL, is_correct = false, points_earned = 0;
      END IF;
    END LOOP;

    IF v_max_score > 0 THEN
      v_percentage := round((v_total_score / v_max_score) * 100, 2);
    ELSE
      v_percentage := 0;
    END IF;

    UPDATE public.exam_attempts
    SET
      status = 'expired',
      submission_reason = 'time_expired',
      score = v_total_score::integer,
      percentage = v_percentage,
      submitted_at = LEAST(now(), v_attempt.started_at + (v_attempt.duration_minutes || ' minutes')::interval)
    WHERE id = v_attempt.id;

    -- Record event in activity log
    INSERT INTO public.activity_events (tenant_id, user_id, group_id, content_id, event_type, metadata)
    VALUES (
      v_attempt.tenant_id, v_attempt.student_id, NULL, v_attempt.content_id, 'exam_submitted',
      jsonb_build_object(
        'attempt_id', v_attempt.id,
        'score', v_total_score,
        'max_score', v_max_score,
        'percentage', v_percentage,
        'status', 'expired',
        'submission_reason', 'time_expired'
      )
    );

    v_finalized_count := v_finalized_count + 1;
  END LOOP;

  RETURN v_finalized_count;
END;
$$;

REVOKE ALL ON FUNCTION public.auto_finalize_expired_attempts(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.auto_finalize_expired_attempts(uuid) TO authenticated;

-- 3. Enhance submit_exam to accept submission_reason and accurately grade answers
DROP FUNCTION IF EXISTS public.submit_exam(uuid, jsonb);

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
  v_selected_opt_val text;
  v_is_correct boolean;
  v_points_earned numeric(8,2);
  v_total_score numeric(8,2) := 0;
  v_max_score numeric(8,2) := 0;
  v_percentage numeric(5,2) := 0;
  v_status text;
  v_reason text := COALESCE(p_reason, 'student_submitted');
  v_is_lecture_exam boolean;
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

  -- If attempt was already submitted or expired, return current values idempotently
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
    SELECT eq.id, eq.points
    FROM public.exam_questions eq
    WHERE eq.exam_version_id = v_attempt.exam_version_id
  LOOP
    v_max_score := v_max_score + v_question.points;

    -- Extract selected option ID safely as text using jsonb ->> operator
    v_selected_opt_val := p_answers->>v_question.id::text;

    -- If no answer in p_answers, check if it was pre-synced in exam_answers
    IF v_selected_opt_val IS NULL OR v_selected_opt_val = '' OR v_selected_opt_val = 'null' THEN
      SELECT selected_option_id::text INTO v_selected_opt_val
      FROM public.exam_answers
      WHERE attempt_id = p_attempt_id AND question_id = v_question.id;
    END IF;

    IF v_selected_opt_val IS NOT NULL AND v_selected_opt_val <> '' AND v_selected_opt_val <> 'null' THEN
      SELECT is_correct INTO v_is_correct
      FROM public.question_options
      WHERE id = v_selected_opt_val::uuid AND question_id = v_question.id;

      IF v_is_correct IS TRUE THEN
        v_points_earned := v_question.points;
        v_total_score := v_total_score + v_points_earned;
      ELSE
        v_points_earned := 0;
        v_is_correct := false;
      END IF;

      INSERT INTO public.exam_answers (attempt_id, question_id, selected_option_id, is_correct, points_earned)
      VALUES (p_attempt_id, v_question.id, v_selected_opt_val::uuid, v_is_correct, v_points_earned)
      ON CONFLICT (attempt_id, question_id)
      DO UPDATE SET
        selected_option_id = EXCLUDED.selected_option_id,
        is_correct = EXCLUDED.is_correct,
        points_earned = EXCLUDED.points_earned;
    ELSE
      INSERT INTO public.exam_answers (attempt_id, question_id, selected_option_id, is_correct, points_earned)
      VALUES (p_attempt_id, v_question.id, NULL, false, 0)
      ON CONFLICT (attempt_id, question_id)
      DO UPDATE SET
        selected_option_id = NULL,
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
      'status', v_status,
      'submission_reason', v_reason
    )
  );

  RETURN jsonb_build_object(
    'attempt_id', p_attempt_id,
    'exam_id', v_attempt.exam_id,
    'status', v_status,
    'submission_reason', v_reason,
    'score', CASE WHEN v_exam.show_result THEN v_total_score ELSE NULL END,
    'max_score', v_max_score,
    'percentage', CASE WHEN v_exam.show_result THEN v_percentage ELSE NULL END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.submit_exam(uuid, jsonb, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_exam(uuid, jsonb, text) TO authenticated;

-- 4. Update get_exam_review to allow review of both 'submitted' and 'expired' attempts
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

  -- Ensure caller is either the student who took it, or a teacher
  IF v_attempt.student_id != v_caller_id AND NOT COALESCE(v_is_teacher, false) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: You are not authorized to view this attempt review';
  END IF;

  IF v_attempt.status NOT IN ('submitted', 'expired') THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only submitted or expired attempts can be reviewed';
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
      COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'id', qo.id,
            'option_text', qo.option_text,
            'sort_order', qo.sort_order,
            'is_correct', qo.is_correct
          )
          ORDER BY qo.sort_order
        ) FILTER (WHERE qo.id IS NOT NULL),
        '[]'::jsonb
      ) AS options
    FROM public.exam_questions eq
    LEFT JOIN public.question_options qo ON qo.question_id = eq.id
    WHERE eq.exam_version_id = v_attempt.exam_version_id
    GROUP BY eq.id, eq.exam_version_id, eq.question_text, eq.question_type, eq.points, eq.sort_order, eq.image_url, eq.image_meta, eq.context_id
    ORDER BY eq.sort_order
  ) q_item;

  -- Build student's submitted answers
  SELECT COALESCE(jsonb_agg(a_item), '[]'::jsonb) INTO v_answers
  FROM (
    SELECT
      ea.id,
      ea.attempt_id,
      ea.question_id,
      ea.selected_option_id,
      ea.is_correct,
      ea.points_earned,
      ea.answered_at
    FROM public.exam_answers ea
    WHERE ea.attempt_id = p_attempt_id
    ORDER BY ea.answered_at
  ) a_item;

  RETURN jsonb_build_object(
    'attempt_id', v_attempt.id,
    'exam_id', v_attempt.exam_id,
    'exam_version_id', v_attempt.exam_version_id,
    'student_id', v_attempt.student_id,
    'started_at', v_attempt.started_at,
    'submitted_at', v_attempt.submitted_at,
    'status', v_attempt.status,
    'submission_reason', COALESCE(v_attempt.submission_reason, 'student_submitted'),
    'score', v_attempt.score,
    'percentage', v_attempt.percentage,
    'exam_title', v_exam.title,
    'passing_score', v_exam.passing_score,
    'questions', v_questions,
    'answers', v_answers
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_exam_review(uuid) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.get_exam_review(uuid) TO authenticated;

-- 5. Auto-finalize before fetching exam attempts for teachers
CREATE OR REPLACE FUNCTION public.get_teacher_exam_attempts(p_exam_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_teacher_id uuid := auth.uid();
  v_is_teacher boolean;
  v_attempts jsonb;
BEGIN
  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be authenticated';
  END IF;

  SELECT (role = 'teacher') INTO v_is_teacher FROM public.users WHERE id = v_teacher_id;
  IF NOT COALESCE(v_is_teacher, false) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only teachers can access this function';
  END IF;

  -- Automatically finalize any expired attempts before loading
  PERFORM public.auto_finalize_expired_attempts(p_exam_id);

  SELECT COALESCE(jsonb_agg(row_to_json(att)), '[]'::jsonb) INTO v_attempts
  FROM (
    SELECT
      a.id,
      a.exam_id,
      a.exam_version_id,
      a.student_id,
      a.started_at,
      a.submitted_at,
      a.status,
      a.submission_reason,
      a.score,
      a.percentage,
      json_build_object(
        'id', u.id,
        'full_name', u.full_name,
        'email', u.email,
        'avatar_url', u.avatar_url
      ) AS users,
      COALESCE(
        (
          SELECT json_agg(row_to_json(ans))
          FROM public.exam_answers ans
          WHERE ans.attempt_id = a.id
        ),
        '[]'::json
      ) AS exam_answers
    FROM public.exam_attempts a
    JOIN public.users u ON u.id = a.student_id
    WHERE a.exam_id = p_exam_id
    ORDER BY COALESCE(a.submitted_at, a.started_at) DESC
  ) att;

  RETURN v_attempts;
END;
$$;

REVOKE ALL ON FUNCTION public.get_teacher_exam_attempts(uuid) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.get_teacher_exam_attempts(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
