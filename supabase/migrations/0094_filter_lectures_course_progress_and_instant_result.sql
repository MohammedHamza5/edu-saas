-- ==============================================================================
-- Migration: 0094_filter_lectures_course_progress_and_instant_result.sql
-- Description:
--   1. Ensures get_group_course_progress strictly returns only video lectures (c.type = 'video')
--      so that standalone exams / non-video content never contaminate the curriculum sequence
--      or get falsely flagged as the "next lecture".
--   2. Enhances submit_exam RPC to return the submitted answers array (with is_correct & selected_option_id),
--      allowing ExamResultPage to instantly render the interactive answer sheet matrix (0ms latency)
--      without needing an additional blocking RPC network round-trip.
-- ==============================================================================

-- 1. Update get_group_course_progress to strictly filter c.type = 'video'
CREATE OR REPLACE FUNCTION public.get_group_course_progress(
  p_group_id UUID,
  p_student_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_caller_role TEXT;
  v_caller_tenant UUID;
  v_target_student UUID;
  v_enforce_seq BOOLEAN := true;
  v_lesson_row RECORD;
  v_lessons_list JSONB[] := '{}';
  
  -- State variables per iteration
  v_is_first BOOLEAN := true;
  v_access_state TEXT;
  v_unlock_source TEXT;
  v_progress_state TEXT;
  v_video_completed BOOLEAN;
  v_quiz_state TEXT;
  v_pdf_state TEXT;
  v_can_access BOOLEAN;
  v_all_prev_completed BOOLEAN := true;
  v_prev_lesson_completed BOOLEAN := true;
  v_exam_passed BOOLEAN;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT role, tenant_id INTO v_caller_role, v_caller_tenant
  FROM public.users
  WHERE id = v_caller_id AND status IN ('active', 'pending');

  IF v_caller_tenant IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  IF v_caller_role = 'student' THEN
    v_target_student := v_caller_id;
    IF NOT EXISTS (
      SELECT 1 FROM public.group_members
      WHERE group_id = p_group_id AND student_id = v_caller_id AND status = 'active'
    ) THEN
      RAISE EXCEPTION 'NOT_AUTHORIZED';
    END IF;
  ELSIF v_caller_role = 'teacher' THEN
    v_target_student := p_student_id;
    IF NOT EXISTS (
      SELECT 1 FROM public.groups
      WHERE id = p_group_id AND tenant_id = v_caller_tenant
    ) THEN
      RAISE EXCEPTION 'NOT_AUTHORIZED';
    END IF;
    IF p_student_id IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public.users
      WHERE id = p_student_id AND tenant_id = v_caller_tenant
    ) THEN
      RAISE EXCEPTION 'NOT_AUTHORIZED';
    END IF;
  ELSIF v_caller_role = 'parent' THEN
    v_target_student := p_student_id;
    IF v_target_student IS NULL OR NOT EXISTS (
      SELECT 1 FROM public.parent_students ps
      JOIN public.group_members gm ON gm.student_id = ps.student_id
      WHERE ps.parent_id = v_caller_id
        AND ps.student_id = v_target_student
        AND gm.group_id = p_group_id
        AND gm.status = 'active'
    ) THEN
      RAISE EXCEPTION 'NOT_AUTHORIZED';
    END IF;
  ELSE
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  SELECT COALESCE(enforce_sequential_learning, true) INTO v_enforce_seq
  FROM public.groups
  WHERE id = p_group_id;

  FOR v_lesson_row IN (
    SELECT 
      cg.id AS content_group_id,
      c.id AS content_id,
      COALESCE(cg.custom_title, c.title) AS title,
      c.description,
      cg.sort_order,
      cg.is_published,
      c.type AS content_type,
      cg.chapter_id,
      ch.title AS chapter_title,
      COALESCE(ch.sort_order, 999999) AS chapter_sort_order,
      cg.file_id AS pdf_file_id,
      f.file_name AS pdf_file_name,
      f.storage_path AS pdf_storage_path,
      COALESCE(cg.associated_exam_id, c.associated_exam_id, CASE WHEN c.type = 'exam' THEN e.id ELSE NULL END) AS lesson_exam_id,
      e.title AS lesson_exam_title,
      COALESCE(cg.passing_score_override, e.passing_score, g.default_passing_score, 60) AS effective_passing_score,
      cg.prerequisite_exam_id,
      vp.progress_seconds AS video_progress_seconds,
      vp.furthest_position_seconds AS furthest_legitimate_position,
      vp.duration_seconds AS video_duration_seconds,
      vp.watched_coverage_percent,
      COALESCE(vp.video_completed, false) AS video_completed,
      ea_agg.exam_best_score,
      COALESCE(mlu_agg.is_manually_unlocked, false) AS is_manually_unlocked,
      (
        SELECT COALESCE(jsonb_agg(
          jsonb_build_object(
            'exam_id', le.exam_id,
            'exam_title', ex.title,
            'sort_order', le.sort_order,
            'is_required', le.is_required,
            'passing_score', COALESCE(ex.passing_score, g.default_passing_score, 60),
            'best_score', (
              SELECT MAX(ea.score) FROM public.exam_attempts ea
              WHERE ea.exam_id = le.exam_id
                AND ea.student_id = v_target_student
                AND ea.status IN ('submitted', 'completed')
            ),
            'is_passed', (
              SELECT EXISTS (
                SELECT 1 FROM public.exam_attempts ea
                WHERE ea.exam_id = le.exam_id
                  AND ea.student_id = v_target_student
                  AND ea.status IN ('submitted', 'completed')
                  AND ea.score >= COALESCE(ex.passing_score, g.default_passing_score, 60)
              )
            ),
            'attempt_count', (
              SELECT COUNT(*) FROM public.exam_attempts ea
              WHERE ea.exam_id = le.exam_id
                AND ea.student_id = v_target_student
            ),
            'latest_attempt_status', (
              SELECT ea.status FROM public.exam_attempts ea
              WHERE ea.exam_id = le.exam_id
                AND ea.student_id = v_target_student
              ORDER BY ea.started_at DESC LIMIT 1
            )
          ) ORDER BY le.sort_order ASC, le.created_at ASC
        ), '[]'::jsonb)
        FROM public.lesson_exams le
        JOIN public.exams ex ON ex.id = le.exam_id
        WHERE le.group_id = p_group_id AND le.content_id = c.id
      ) AS attached_exams
    FROM public.content_groups cg
    JOIN public.content c ON c.id = cg.content_id AND c.status = 'published' AND c.type = 'video'
    LEFT JOIN public.chapters ch ON ch.id = cg.chapter_id
    LEFT JOIN public.files f ON f.id = cg.file_id
    LEFT JOIN public.exams e ON (e.id = COALESCE(cg.associated_exam_id, c.associated_exam_id) OR (c.type = 'exam' AND e.content_id = c.id))
    LEFT JOIN public.groups g ON g.id = p_group_id
    LEFT JOIN LATERAL (
      SELECT 
        COALESCE(vp.progress_seconds, 0) AS progress_seconds,
        COALESCE(vp.furthest_position_seconds, 0) AS furthest_position_seconds,
        COALESCE(vp.duration_seconds, v.duration, 0) AS duration_seconds,
        COALESCE(vp.watched_coverage_percentage, vp.percentage, 0) AS watched_coverage_percent,
        COALESCE(vp.completed, false) AS video_completed
      FROM public.videos v
      LEFT JOIN public.video_progress vp ON vp.video_id = v.id AND vp.student_id = v_target_student
      WHERE v.content_id = c.id
      ORDER BY v.created_at DESC
      LIMIT 1
    ) vp ON true
    LEFT JOIN LATERAL (
      SELECT MAX(ea.score) AS exam_best_score
      FROM public.exam_attempts ea
      WHERE ea.exam_id = COALESCE(cg.associated_exam_id, c.associated_exam_id, CASE WHEN c.type = 'exam' THEN e.id ELSE NULL END)
        AND ea.student_id = v_target_student
        AND ea.status IN ('submitted', 'completed')
    ) ea_agg ON true
    LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1 FROM public.manual_lesson_unlocks mlu
        WHERE mlu.student_id = v_target_student 
          AND mlu.content_id = c.id 
          AND mlu.group_id = p_group_id
      ) AS is_manually_unlocked
    ) mlu_agg ON true
    WHERE cg.group_id = p_group_id
      AND (v_caller_role = 'teacher' OR cg.is_published = true)
    ORDER BY COALESCE(ch.sort_order, 999999) ASC, cg.sort_order ASC, c.sort_order ASC, c.created_at ASC
  ) LOOP
  
    v_access_state := 'locked';
    v_unlock_source := null;
    v_progress_state := 'not_started';
    v_video_completed := v_lesson_row.video_completed;
    v_exam_passed := (v_lesson_row.exam_best_score IS NOT NULL AND v_lesson_row.exam_best_score >= v_lesson_row.effective_passing_score);

    IF v_is_first THEN
      v_access_state := 'available';
      v_unlock_source := 'automatic';
      v_is_first := false;
    ELSIF v_lesson_row.is_manually_unlocked THEN
      v_access_state := 'available';
      v_unlock_source := 'manual';
    ELSIF NOT COALESCE(v_enforce_seq, true) THEN
      v_access_state := 'available';
      v_unlock_source := 'automatic';
    ELSIF v_all_prev_completed THEN
      v_access_state := 'available';
      v_unlock_source := 'automatic';
    ELSE
      v_access_state := 'locked';
      v_unlock_source := null;
    END IF;

    v_can_access := (v_access_state = 'available');

    IF v_lesson_row.lesson_exam_id IS NOT NULL THEN
      IF v_exam_passed THEN
        v_progress_state := 'completed';
        v_prev_lesson_completed := true;
      ELSE
        IF v_video_completed THEN
          v_progress_state := 'in_progress';
        ELSIF v_lesson_row.video_progress_seconds > 0 THEN
          v_progress_state := 'in_progress';
        ELSE
          v_progress_state := 'not_started';
        END IF;
        v_prev_lesson_completed := false;
      END IF;
    ELSE
      IF v_video_completed THEN
        v_progress_state := 'completed';
        v_prev_lesson_completed := true;
      ELSIF v_lesson_row.video_progress_seconds > 0 THEN
        v_progress_state := 'in_progress';
        v_prev_lesson_completed := false;
      ELSE
        v_progress_state := 'not_started';
        v_prev_lesson_completed := false;
      END IF;
    END IF;

    IF v_lesson_row.pdf_file_id IS NOT NULL THEN
      v_pdf_state := CASE WHEN v_can_access THEN 'available' ELSE 'locked' END;
    ELSE
      v_pdf_state := 'none';
    END IF;

    IF v_lesson_row.lesson_exam_id IS NOT NULL THEN
      IF NOT v_can_access THEN
        v_quiz_state := 'locked';
      ELSIF v_exam_passed THEN
        v_quiz_state := 'completed';
      ELSIF v_lesson_row.content_type = 'exam' THEN
        v_quiz_state := 'ready';
      ELSIF NOT v_video_completed THEN
        v_quiz_state := 'locked';
      ELSE
        v_quiz_state := 'ready';
      END IF;
    ELSE
      v_quiz_state := 'none';
    END IF;

    v_all_prev_completed := v_all_prev_completed AND v_prev_lesson_completed;

    v_lessons_list := array_append(v_lessons_list, jsonb_build_object(
      'content_group_id',               v_lesson_row.content_group_id,
      'content_id',                     v_lesson_row.content_id,
      'group_id',                       p_group_id,
      'title',                          v_lesson_row.title,
      'description',                    v_lesson_row.description,
      'sort_order',                     v_lesson_row.sort_order,
      'is_published',                   v_lesson_row.is_published,
      'content_type',                   v_lesson_row.content_type,
      'chapter_id',                     v_lesson_row.chapter_id,
      'chapter_title',                  v_lesson_row.chapter_title,
      'chapter_sort_order',             v_lesson_row.chapter_sort_order,
      'access_state',                   v_access_state,
      'unlock_source',                  v_unlock_source,
      'progress_state',                 v_progress_state,
      'video_progress_seconds',         v_lesson_row.video_progress_seconds,
      'furthest_legitimate_position',   v_lesson_row.furthest_legitimate_position,
      'video_duration_seconds',         v_lesson_row.video_duration_seconds,
      'watched_coverage_percent',       v_lesson_row.watched_coverage_percent,
      'video_completed',                v_video_completed,
      'has_pdf',                        (v_lesson_row.pdf_file_id IS NOT NULL),
      'pdf_state',                      v_pdf_state,
      'pdf_file_id',                    v_lesson_row.pdf_file_id,
      'pdf_file_name',                  v_lesson_row.pdf_file_name,
      'has_quiz',                       (v_lesson_row.lesson_exam_id IS NOT NULL),
      'quiz_state',                     v_quiz_state,
      'quiz_id',                        v_lesson_row.lesson_exam_id,
      'quiz_title',                     v_lesson_row.lesson_exam_title,
      'effective_passing_score',        v_lesson_row.effective_passing_score,
      'exam_best_score',                v_lesson_row.exam_best_score,
      'exam_passed',                    v_exam_passed,
      'attached_exams',                 COALESCE(v_lesson_row.attached_exams, '[]'::jsonb)
    ));
  END LOOP;

  RETURN jsonb_build_object(
    'group_id',                   p_group_id,
    'student_id',                 v_target_student,
    'enforce_sequential_learning', COALESCE(v_enforce_seq, true),
    'chapters', (
      SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
          'id', ch.id,
          'title', ch.title,
          'description', ch.description,
          'sort_order', ch.sort_order,
          'source_folder_id', ch.source_folder_id,
          'created_at', ch.created_at
        ) ORDER BY ch.sort_order ASC, ch.created_at ASC
      ), '[]'::jsonb)
      FROM public.chapters ch
      WHERE ch.group_id = p_group_id
    ),
    'lessons',                    COALESCE(to_jsonb(v_lessons_list), '[]'::jsonb)
  );
END;
$$;

-- 2. Update submit_exam to return answers array with is_correct for instant client review
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

GRANT EXECUTE ON FUNCTION public.get_group_course_progress(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_exam(uuid, jsonb) TO authenticated;
NOTIFY pgrst, 'reload schema';
