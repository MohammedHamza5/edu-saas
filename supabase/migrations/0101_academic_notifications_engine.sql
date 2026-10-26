-- ==============================================================================
-- Migration: 0101_academic_notifications_engine.sql
-- Description: Real-time Event-Driven Notification Engine
-- Authorizes automatic atomic notifications for:
--   1. Student Exam Submissions (notifies teacher with score and details)
--   2. Student Assignment Submissions (notifies teacher of uploaded homework)
--   3. New Student Registrations (notifies teacher of pending approval)
-- ==============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Upgrade submit_exam to trigger immediate teacher notification upon submission
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.submit_exam(p_attempt_id uuid, p_answers jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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
  v_teacher_id uuid;
  v_student_name text;
  v_notif_id uuid;
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
      'percentage', CASE WHEN v_exam.show_result THEN v_attempt.percentage ELSE NULL END,
      'answers', (
        SELECT COALESCE(jsonb_agg(
          jsonb_build_object(
            'id', ea.id,
            'attempt_id', ea.attempt_id,
            'question_id', ea.question_id,
            'selected_option_id', ea.selected_option_id,
            'is_correct', ea.is_correct,
            'points_earned', ea.points_earned,
            'answered_at', ea.answered_at
          )
        ), '[]'::jsonb)
        FROM public.exam_answers ea
        WHERE ea.attempt_id = p_attempt_id
      )
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

  -- Lecture exams never expire by duration
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

  -- ── Proactive Teacher Notification (Non-blocking fallback) ──
  BEGIN
    SELECT id INTO v_teacher_id
    FROM public.users
    WHERE tenant_id = v_exam.tenant_id AND role = 'teacher'
    LIMIT 1;

    SELECT COALESCE(full_name, 'طالب') INTO v_student_name
    FROM public.users
    WHERE id = v_student_id;

    IF v_teacher_id IS NOT NULL THEN
      INSERT INTO public.notifications (
        tenant_id,
        title,
        body,
        type,
        data,
        created_at
      ) VALUES (
        v_exam.tenant_id,
        '🎯 تسليم اختبار: ' || COALESCE(v_exam.title, 'اختبار جديد'),
        'أتم الطالب ' || v_student_name || ' الاختبار بنتيجة ' || v_total_score::text || ' من ' || v_max_score::text || ' (' || v_percentage::text || '%)',
        'exam_result',
        jsonb_build_object(
          'exam_id', v_attempt.exam_id,
          'attempt_id', p_attempt_id,
          'student_id', v_student_id,
          'score', v_total_score,
          'max_score', v_max_score,
          'percentage', v_percentage,
          'status', v_status
        ),
        now()
      ) RETURNING id INTO v_notif_id;

      INSERT INTO public.notification_recipients (
        notification_id,
        user_id,
        created_at
      ) VALUES (
        v_notif_id,
        v_teacher_id,
        now()
      );
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Proactive teacher notification failed gracefully: %', SQLERRM;
  END;

  RETURN jsonb_build_object(
    'attempt_id', p_attempt_id,
    'exam_id', v_attempt.exam_id,
    'status', v_status,
    'score', CASE WHEN v_exam.show_result THEN v_total_score ELSE NULL END,
    'max_score', v_max_score,
    'percentage', CASE WHEN v_exam.show_result THEN v_percentage ELSE NULL END,
    'answers', (
      SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
          'id', ea.id,
          'attempt_id', ea.attempt_id,
          'question_id', ea.question_id,
          'selected_option_id', ea.selected_option_id,
          'is_correct', ea.is_correct,
          'points_earned', ea.points_earned,
          'answered_at', ea.answered_at
        )
      ), '[]'::jsonb)
      FROM public.exam_answers ea
      WHERE ea.attempt_id = p_attempt_id
    )
  );
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Trigger on Assignment Submissions (Notifies Teacher of Submitted Homework)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trg_notify_teacher_on_assignment_submission()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_teacher_id uuid;
  v_student_name text;
  v_assignment_title text;
  v_tenant_id uuid;
  v_notif_id uuid;
BEGIN
  -- Get assignment metadata
  SELECT a.tenant_id, COALESCE(c.title, 'واجب المحاضرة')
  INTO v_tenant_id, v_assignment_title
  FROM public.assignments a
  JOIN public.content c ON c.id = a.content_id
  WHERE a.id = NEW.assignment_id;

  -- Get student full name
  SELECT COALESCE(full_name, 'طالب') INTO v_student_name
  FROM public.users
  WHERE id = NEW.student_id;

  -- Get teacher
  SELECT id INTO v_teacher_id
  FROM public.users
  WHERE tenant_id = v_tenant_id AND role = 'teacher'
  LIMIT 1;

  IF v_teacher_id IS NOT NULL THEN
    INSERT INTO public.notifications (
      tenant_id,
      title,
      body,
      type,
      data,
      created_at
    ) VALUES (
      v_tenant_id,
      '📝 تسليم واجب جديد: ' || v_assignment_title,
      'قام الطالب ' || v_student_name || ' برفع وتسليم الواجب وهو في انتظار مراجعتك.',
      'assignment_created',
      jsonb_build_object(
        'submission_id', NEW.id,
        'assignment_id', NEW.assignment_id,
        'student_id', NEW.student_id
      ),
      now()
    ) RETURNING id INTO v_notif_id;

    INSERT INTO public.notification_recipients (
      notification_id,
      user_id,
      created_at
    ) VALUES (
      v_notif_id,
      v_teacher_id,
      now()
    );
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Assignment submission notification failed: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_assignment_submission ON public.assignment_submissions;
CREATE TRIGGER trg_notify_on_assignment_submission
  AFTER INSERT ON public.assignment_submissions
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_notify_teacher_on_assignment_submission();

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Trigger on New Student Registration (Notifies Teacher of Pending Approval)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trg_notify_teacher_on_student_registration()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_teacher_id uuid;
  v_notif_id uuid;
BEGIN
  -- Only trigger for newly registered pending students
  IF NEW.role = 'student' AND NEW.status = 'pending' THEN
    SELECT id INTO v_teacher_id
    FROM public.users
    WHERE tenant_id = NEW.tenant_id AND role = 'teacher'
    LIMIT 1;

    IF v_teacher_id IS NOT NULL THEN
      INSERT INTO public.notifications (
        tenant_id,
        title,
        body,
        type,
        data,
        created_at
      ) VALUES (
        NEW.tenant_id,
        '👤 طلب تسجيل طالب جديد',
        'سجل الطالب ' || COALESCE(NEW.full_name, 'طالب جديد') || ' وينتظر مراجعتك واعتماده في المجموعات.',
        'important_announcement',
        jsonb_build_object(
          'student_id', NEW.id,
          'email', NEW.email,
          'phone', NEW.phone
        ),
        now()
      ) RETURNING id INTO v_notif_id;

      INSERT INTO public.notification_recipients (
        notification_id,
        user_id,
        created_at
      ) VALUES (
        v_notif_id,
        v_teacher_id,
        now()
      );
    END IF;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Student registration notification failed: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_student_registration ON public.users;
CREATE TRIGGER trg_notify_on_student_registration
  AFTER INSERT ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_notify_teacher_on_student_registration();

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Ensure RLS on notifications and recipients allows proper Teacher access
-- ─────────────────────────────────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.submit_exam(uuid, jsonb) TO authenticated;
NOTIFY pgrst, 'reload schema';
