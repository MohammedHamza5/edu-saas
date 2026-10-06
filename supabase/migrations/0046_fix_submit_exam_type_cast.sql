-- 0046_fix_submit_exam_type_cast.sql
-- Fix submit_exam PL/pgSQL variable type for selected option (was record, causing 42846 cannot cast type record to uuid)
-- Ensure submit_exam returns exam_id and max_score properly

CREATE OR REPLACE FUNCTION public.submit_exam(p_attempt_id uuid, p_answers jsonb)
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

  IF v_attempt.status IN ('submitted', 'expired') THEN
    SELECT show_result INTO v_exam FROM public.exams WHERE id = v_attempt.exam_id;
    RETURN jsonb_build_object(
      'attempt_id', v_attempt.id,
      'exam_id', v_attempt.exam_id,
      'status', v_attempt.status,
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

  -- التحقق من التوقيت: امتحانات المحاضرات لا تنتهي أبداً
  IF NOT v_is_lecture_exam AND v_exam.duration_minutes > 0
     AND (v_attempt.started_at + (v_exam.duration_minutes || ' minutes')::interval) < now() THEN
    v_status := 'expired';
  ELSE
    v_status := 'submitted';
  END IF;

  DELETE FROM public.exam_answers WHERE attempt_id = p_attempt_id;

  FOR v_question IN
    SELECT eq.id, eq.points
    FROM public.exam_questions eq
    WHERE eq.exam_version_id = v_attempt.exam_version_id
  LOOP
    v_max_score := v_max_score + v_question.points;

    -- Extract selected option ID safely as text using jsonb ->> operator
    v_selected_opt_val := p_answers->>v_question.id::text;

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
      VALUES (p_attempt_id, v_question.id, v_selected_opt_val::uuid, v_is_correct, v_points_earned);
    ELSE
      INSERT INTO public.exam_answers (attempt_id, question_id, selected_option_id, is_correct, points_earned)
      VALUES (p_attempt_id, v_question.id, NULL, false, 0);
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
    score = v_total_score,
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
      'status', v_status
    )
  );

  RETURN jsonb_build_object(
    'attempt_id', p_attempt_id,
    'exam_id', v_attempt.exam_id,
    'status', v_status,
    'score', CASE WHEN v_exam.show_result THEN v_total_score ELSE NULL END,
    'max_score', v_max_score,
    'percentage', CASE WHEN v_exam.show_result THEN v_percentage ELSE NULL END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.submit_exam(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_exam(uuid, jsonb) TO authenticated;

NOTIFY pgrst, 'reload schema';
