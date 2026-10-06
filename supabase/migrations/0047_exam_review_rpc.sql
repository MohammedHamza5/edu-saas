-- 0047: Add get_exam_review RPC for post-submission student exam review
-- Allows students to review their submitted answers, seeing which options they selected,
-- which ones were wrong, and the correct model answers.

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

  -- Build answers
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

REVOKE ALL ON FUNCTION public.get_exam_review(uuid) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.get_exam_review(uuid) TO authenticated;
NOTIFY pgrst, 'reload schema';
