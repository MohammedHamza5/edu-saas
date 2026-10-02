-- ==============================================================================
-- Migration: 0029_filter_lectures_course_progress.sql
-- Description: 
--   1. Ensures get_group_course_progress only returns video lectures (c.type = 'video')
--      so standalone exams do not clutter the lectures path.
--   2. Ensures the first lecture is ALWAYS unlocked (access_state = 'available').
--   3. Enforces that a lecture with an associated exam is only completed once the student
--      passes the exam with >= effective_passing_score, unlocking the next lecture.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.get_group_course_progress(
  p_group_id UUID,
  p_student_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_caller_role TEXT;
  v_caller_tenant UUID;
  v_target_student UUID;
  v_enforce_seq BOOLEAN := true;
  v_lesson_row RECORD;
  v_lessons_arr JSONB := '[]'::JSONB;
  
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
BEGIN
  -- Authenticate caller
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

  -- Get enforce_sequential rule
  SELECT COALESCE(enforce_sequential_learning, true) INTO v_enforce_seq
  FROM public.groups
  WHERE id = p_group_id;

  -- Build JSON array by iterating ONLY over video lectures ordered by sort_order
  FOR v_lesson_row IN (
    SELECT 
      cg.id AS content_group_id,
      c.id AS content_id,
      COALESCE(cg.custom_title, c.title) AS title,
      c.description,
      cg.sort_order,
      cg.is_published,
      c.type AS content_type,
      cg.file_id AS pdf_file_id,
      f.file_name AS pdf_file_name,
      f.storage_path AS pdf_storage_path,
      cg.associated_exam_id AS lesson_exam_id,
      e.title AS lesson_exam_title,
      COALESCE(cg.passing_score_override, e.passing_score, g.default_passing_score, 60) AS effective_passing_score,
      cg.prerequisite_exam_id,
      vp.progress_seconds AS video_progress_seconds,
      vp.furthest_position_seconds AS furthest_legitimate_position,
      vp.duration_seconds AS video_duration_seconds,
      vp.watched_coverage_percent,
      COALESCE(vp.video_completed, false) AS video_completed,
      (
        SELECT MAX(ea.score) FROM public.exam_attempts ea
        WHERE ea.exam_id = cg.associated_exam_id AND ea.student_id = v_target_student AND ea.status = 'completed'
      ) AS exam_best_score,
      (
        SELECT EXISTS (
          SELECT 1 FROM public.exam_attempts ea
          WHERE ea.exam_id = cg.associated_exam_id AND ea.student_id = v_target_student AND ea.status = 'completed'
            AND ea.score >= COALESCE(cg.passing_score_override, e.passing_score, g.default_passing_score, 60)
        )
      ) AS exam_passed,
      (
        SELECT EXISTS (
          SELECT 1 FROM public.manual_lesson_unlocks mlu
          WHERE mlu.student_id = v_target_student AND mlu.content_id = c.id AND mlu.group_id = p_group_id
        )
      ) AS is_manually_unlocked
    FROM public.content_groups cg
    JOIN public.content c ON c.id = cg.content_id 
                         AND c.status = 'published' 
                         AND (c.type = 'video' OR c.type IS NULL OR c.type = 'lesson')
                         AND c.type != 'exam'
                         AND c.type != 'assignment'
    LEFT JOIN public.files f ON f.id = cg.file_id
    LEFT JOIN public.exams e ON e.id = cg.associated_exam_id
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
    WHERE cg.group_id = p_group_id
      AND (v_caller_role = 'teacher' OR cg.is_published = true)
    ORDER BY cg.sort_order ASC, c.sort_order ASC, c.created_at DESC
  ) LOOP
  
    -- Initialize states
    v_access_state := 'locked';
    v_unlock_source := null;
    v_progress_state := 'not_started';
    v_video_completed := v_lesson_row.video_completed;

    -- Evaluate access state
    -- 1. First lesson in the course is ALWAYS available
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

    -- Evaluate progress & completion
    IF v_lesson_row.lesson_exam_id IS NOT NULL THEN
      IF v_lesson_row.exam_passed THEN
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

    -- Evaluate PDF & Quiz states
    IF v_lesson_row.pdf_file_id IS NOT NULL THEN
      v_pdf_state := CASE WHEN v_can_access THEN 'available' ELSE 'locked' END;
    ELSE
      v_pdf_state := 'none';
    END IF;

    IF v_lesson_row.lesson_exam_id IS NOT NULL THEN
      IF NOT v_can_access THEN
        v_quiz_state := 'locked';
      ELSIF v_lesson_row.exam_passed THEN
        v_quiz_state := 'completed';
      ELSIF NOT v_video_completed THEN
        v_quiz_state := 'locked';
      ELSE
        v_quiz_state := 'ready';
      END IF;
    ELSE
      v_quiz_state := 'none';
    END IF;

    v_all_prev_completed := v_all_prev_completed AND v_prev_lesson_completed;

    -- Append lesson JSON
    v_lessons_arr := v_lessons_arr || jsonb_build_object(
      'content_group_id',               v_lesson_row.content_group_id,
      'content_id',                     v_lesson_row.content_id,
      'title',                          v_lesson_row.title,
      'description',                    v_lesson_row.description,
      'sort_order',                     v_lesson_row.sort_order,
      'is_published',                   v_lesson_row.is_published,
      'content_type',                   v_lesson_row.content_type,
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
      'exam_passed',                    v_lesson_row.exam_passed
    );
  END LOOP;

  RETURN jsonb_build_object(
    'group_id',                   p_group_id,
    'student_id',                 v_target_student,
    'enforce_sequential_learning', COALESCE(v_enforce_seq, true),
    'lessons',                    v_lessons_arr
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_group_course_progress(uuid, uuid) TO authenticated;
