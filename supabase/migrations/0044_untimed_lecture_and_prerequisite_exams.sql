-- 0044: جعل امتحانات المحاضرات واختبارات الاجتياز غير مقيدة بوقت نهائياً (Untimed)
-- وحل مشكلة انتهاء الوقت ومنع إعادة المحاولة بشكل جذري

CREATE OR REPLACE FUNCTION public.start_exam(p_exam_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id uuid := auth.uid();
  v_tenant_id uuid;
  v_exam record;
  v_version record;
  v_active_attempt record;
  v_attempt_id uuid;
  v_started_at timestamptz;
  v_questions jsonb;
  v_contexts jsonb;
  v_is_lecture_exam boolean;
  v_is_late boolean := false;
  v_has_passed boolean := false;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be authenticated';
  END IF;

  SELECT tenant_id INTO v_tenant_id FROM public.users WHERE id = v_student_id AND status = 'active';
  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Active student profile required';
  END IF;

  SELECT e.*, c.group_id, c.status AS content_status INTO v_exam
  FROM public.exams e
  JOIN public.content c ON c.id = e.content_id
  WHERE e.id = p_exam_id AND e.tenant_id = v_tenant_id;

  IF v_exam.id IS NULL THEN
    RAISE EXCEPTION 'EXAM_NOT_FOUND: Exam does not exist';
  END IF;

  IF v_exam.content_status != 'published' THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Exam is not published';
  END IF;

  -- فحص هل الامتحان تابع لمحاضرة (واجب أو اختبار اجتياز للدخول للمحاضرة التالية أو مدته 0)
  v_is_lecture_exam :=
    (v_exam.duration_minutes IS NULL OR v_exam.duration_minutes <= 0)
    OR EXISTS (
      SELECT 1 FROM public.content_groups cg
      WHERE cg.associated_exam_id = p_exam_id OR cg.prerequisite_exam_id = p_exam_id
    )
    OR EXISTS (
      SELECT 1 FROM public.content c2
      WHERE c2.associated_exam_id = p_exam_id OR c2.prerequisite_exam_id = p_exam_id
    );

  IF NOT v_is_lecture_exam THEN
    IF v_exam.start_at IS NOT NULL AND now() < v_exam.start_at THEN
      RAISE EXCEPTION 'EXAM_NOT_STARTED: Exam start time is in the future';
    END IF;
    -- الدخول بعد end_at مسموح للامتحانات العامة (متأخر)
    v_is_late := v_exam.end_at IS NOT NULL AND now() > v_exam.end_at;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.group_members gm
    WHERE gm.student_id = v_student_id
      AND gm.group_id = v_exam.group_id
      AND gm.status = 'active'
  ) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Student is not an active member of this group';
  END IF;

  -- فحص ما إذا كان الطالب قد اجتاز هذا الامتحان مسبقاً بدرجة النجاح
  SELECT EXISTS (
    SELECT 1 FROM public.exam_attempts
    WHERE exam_id = p_exam_id
      AND student_id = v_student_id
      AND status = 'submitted'
      AND (v_exam.passing_score IS NULL OR score >= v_exam.passing_score)
  ) INTO v_has_passed;

  -- فحص أي محاولة قيد التنفيذ
  SELECT * INTO v_active_attempt
  FROM public.exam_attempts
  WHERE exam_id = p_exam_id AND student_id = v_student_id AND status = 'in_progress';

  IF v_active_attempt.id IS NOT NULL THEN
    -- لا تنتهي محاولات امتحانات المحاضرات نهائياً، أما الامتحانات العامة فتفحص التوقيت
    IF NOT v_is_lecture_exam AND v_exam.duration_minutes > 0
       AND (v_active_attempt.started_at + (v_exam.duration_minutes || ' minutes')::interval) < now() THEN
      UPDATE public.exam_attempts
      SET status = 'expired'
      WHERE id = v_active_attempt.id;
    ELSE
      v_attempt_id := v_active_attempt.id;
      v_started_at := v_active_attempt.started_at;
      SELECT * INTO v_version FROM public.exam_versions WHERE id = v_active_attempt.exam_version_id;
    END IF;
  END IF;

  -- إذا لم تكن هناك محاولة نشطة صالحة: نتحقق من إمكانية بدء محاولة جديدة
  IF v_attempt_id IS NULL THEN
    IF v_is_lecture_exam THEN
      -- امتحان محاضرة: إذا كان الطالب قد اجتازه بالفعل ولا يُسمح بالإعادة، نمنعه
      IF v_has_passed AND NOT v_exam.allow_retake THEN
        RAISE EXCEPTION 'ATTEMPTS_LIMIT_REACHED: You have already passed this lecture exam';
      END IF;
      -- إذا لم يجتزْه الطالب بعد، يُسمح له دائماً ببدء محاولة جديدة
    ELSE
      -- امتحان عام: القيود العادية
      IF NOT v_exam.allow_retake AND EXISTS (
        SELECT 1 FROM public.exam_attempts
        WHERE exam_id = p_exam_id AND student_id = v_student_id AND status IN ('submitted', 'expired')
      ) THEN
        RAISE EXCEPTION 'ATTEMPTS_LIMIT_REACHED: Retake is not allowed for this exam';
      END IF;
    END IF;

    SELECT * INTO v_version
    FROM public.exam_versions
    WHERE exam_id = p_exam_id AND status = 'published'
    ORDER BY version_number DESC
    LIMIT 1;

    IF v_version.id IS NULL THEN
      RAISE EXCEPTION 'EXAM_NOT_FOUND: No published version available for this exam';
    END IF;

    v_started_at := now();

    INSERT INTO public.exam_attempts (exam_id, exam_version_id, student_id, started_at, status)
    VALUES (p_exam_id, v_version.id, v_student_id, v_started_at, 'in_progress')
    RETURNING id INTO v_attempt_id;

    INSERT INTO public.activity_events (tenant_id, user_id, group_id, content_id, event_type, metadata)
    VALUES (
      v_tenant_id, v_student_id, v_exam.group_id, v_exam.content_id, 'exam_started',
      jsonb_build_object('attempt_id', v_attempt_id, 'version_id', v_version.id)
    );
  END IF;

  SELECT COALESCE(jsonb_agg(ctx_item), '[]'::jsonb) INTO v_contexts
  FROM (
    SELECT ec.id, ec.title, ec.context_text, ec.image_url, ec.image_meta, ec.sort_order
    FROM public.exam_contexts ec
    WHERE ec.exam_version_id = v_version.id
    ORDER BY ec.sort_order
  ) ctx_item;

  SELECT COALESCE(jsonb_agg(q_item), '[]'::jsonb) INTO v_questions
  FROM (
    SELECT
      eq.id, eq.question_text, eq.question_type, eq.points, eq.sort_order,
      eq.image_url, eq.image_meta, eq.context_id,
      (
        SELECT COALESCE(jsonb_agg(
          jsonb_build_object(
            'id', qo.id,
            'option_text', qo.option_text,
            'sort_order', qo.sort_order,
            'image_url', qo.image_url,
            'image_meta', qo.image_meta
          ) ORDER BY qo.sort_order
        ), '[]'::jsonb)
        FROM public.question_options qo
        WHERE qo.question_id = eq.id
      ) AS options
    FROM public.exam_questions eq
    WHERE eq.exam_version_id = v_version.id
    ORDER BY CASE WHEN v_exam.shuffle_questions THEN random() ELSE eq.sort_order END
  ) q_item;

  RETURN jsonb_build_object(
    'attempt_id', v_attempt_id,
    'exam_version_id', v_version.id,
    'started_at', COALESCE(v_started_at, now()),
    'duration_minutes', CASE WHEN v_is_lecture_exam THEN 0 ELSE COALESCE(v_exam.duration_minutes, 0) END,
    'show_result', v_exam.show_result,
    'is_late', v_is_late,
    'contexts', v_contexts,
    'questions', v_questions
  );
END;
$$;

-- 2) تحديث submit_exam: عدم انتهاء صلاحية أي امتحان محاضرة عند التسليم
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
  v_version record;
  v_ans_record record;
  v_question record;
  v_selected_option record;
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

    SELECT value::text INTO v_selected_option
    FROM jsonb_each_text(p_answers)
    WHERE key = v_question.id::text;

    IF v_selected_option IS NOT NULL THEN
      SELECT is_correct INTO v_is_correct
      FROM public.question_options
      WHERE id = v_selected_option::uuid AND question_id = v_question.id;

      IF v_is_correct THEN
        v_points_earned := v_question.points;
        v_total_score := v_total_score + v_points_earned;
      ELSE
        v_points_earned := 0;
      END IF;

      INSERT INTO public.exam_answers (attempt_id, question_id, selected_option_id, is_correct, points_earned)
      VALUES (p_attempt_id, v_question.id, v_selected_option::uuid, v_is_correct, v_points_earned);
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
    'status', v_status,
    'score', CASE WHEN v_exam.show_result THEN v_total_score ELSE NULL END,
    'percentage', CASE WHEN v_exam.show_result THEN v_percentage ELSE NULL END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.start_exam(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_exam(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.submit_exam(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_exam(uuid, jsonb) TO authenticated;

-- 3) تصفير مدة أي امتحان مرتبط بمحاضرة وتصحيح المحاولات المعلقة
UPDATE public.exams
SET duration_minutes = 0
WHERE id IN (
  SELECT associated_exam_id FROM public.content_groups WHERE associated_exam_id IS NOT NULL
  UNION
  SELECT prerequisite_exam_id FROM public.content_groups WHERE prerequisite_exam_id IS NOT NULL
  UNION
  SELECT associated_exam_id FROM public.content WHERE associated_exam_id IS NOT NULL
  UNION
  SELECT prerequisite_exam_id FROM public.content WHERE prerequisite_exam_id IS NOT NULL
);

-- تحديث المحاولات المنتهية بالخطأ لامتحانات المحاضرات إلى in_progress مع توقيت حالي
UPDATE public.exam_attempts ea
SET status = 'in_progress', started_at = now()
WHERE ea.status IN ('expired', 'in_progress')
  AND ea.exam_id IN (
    SELECT associated_exam_id FROM public.content_groups WHERE associated_exam_id IS NOT NULL
    UNION
    SELECT prerequisite_exam_id FROM public.content_groups WHERE prerequisite_exam_id IS NOT NULL
    UNION
    SELECT associated_exam_id FROM public.content WHERE associated_exam_id IS NOT NULL
    UNION
    SELECT prerequisite_exam_id FROM public.content WHERE prerequisite_exam_id IS NOT NULL
  );

NOTIFY pgrst, 'reload schema';
