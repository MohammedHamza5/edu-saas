-- Migration 0086: Fix Lecture File Linking & Add Fallback Resolution
-- Ensures PDF handouts and study materials attached to lectures are reliably retrieved
-- even if content_groups.file_id was temporarily omitted or pending junction sync.

-- 1. Update get_lesson_context with fallback to files table by content_id
CREATE OR REPLACE FUNCTION public.get_lesson_context(p_content_id uuid, p_group_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_id uuid := auth.uid();
  v_cg record;
  v_file_id uuid := null;
  v_file_name text := null;
  v_file_storage_path text := null;
  v_exam_id uuid := null;
  v_exam_title text := null;
  v_exam_passing_score int := null;
  v_group record;
  v_latest_version_id uuid := null;
  v_questions_count int := 0;
  v_is_manually_unlocked boolean := false;
  v_manual_reason text := null;
  v_attached_exams jsonb := '[]'::jsonb;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be authenticated';
  END IF;

  SELECT * INTO v_cg FROM public.content_groups
  WHERE content_id = p_content_id AND group_id = p_group_id;

  IF v_cg IS NULL THEN
    RETURN jsonb_build_object('error', 'NOT_FOUND');
  END IF;

  SELECT * INTO v_group FROM public.groups WHERE id = p_group_id;

  -- 1. Resolve attached PDF (with fallback if cg.file_id is null)
  IF v_cg.file_id IS NOT NULL THEN
    SELECT id, file_name, storage_path INTO v_file_id, v_file_name, v_file_storage_path
    FROM public.files WHERE id = v_cg.file_id;
  ELSE
    SELECT id, file_name, storage_path INTO v_file_id, v_file_name, v_file_storage_path
    FROM public.files WHERE content_id = p_content_id
    ORDER BY created_at DESC LIMIT 1;
    
    -- Self-heal the junction record if found
    IF v_file_id IS NOT NULL THEN
      UPDATE public.content_groups
      SET file_id = v_file_id
      WHERE content_id = p_content_id AND group_id = p_group_id;
    END IF;
  END IF;

  -- 2. Resolve associated and attached exams
  IF v_cg.associated_exam_id IS NOT NULL THEN
    SELECT id, passing_score, COALESCE(title, (SELECT title FROM public.content WHERE id = exams.content_id), '')
    INTO v_exam_id, v_exam_passing_score, v_exam_title
    FROM public.exams WHERE id = v_cg.associated_exam_id;

    IF v_exam_id IS NOT NULL THEN
      SELECT id INTO v_latest_version_id
      FROM public.exam_versions
      WHERE exam_id = v_exam_id AND status = 'published'
      ORDER BY version_number DESC LIMIT 1;

      IF v_latest_version_id IS NOT NULL THEN
        SELECT count(*)::int INTO v_questions_count
        FROM public.exam_questions
        WHERE exam_version_id = v_latest_version_id;
      END IF;

      v_attached_exams := jsonb_build_array(
        jsonb_build_object(
          'exam_id', v_exam_id,
          'exam_title', v_exam_title,
          'sort_order', 0,
          'is_required', true,
          'passing_score', COALESCE(v_cg.passing_score_override, v_exam_passing_score, 60),
          'questions_count', v_questions_count
        )
      );
    END IF;
  END IF;

  -- 3. Check manual unlock for caller student
  SELECT EXISTS(
    SELECT 1 FROM public.manual_lesson_unlocks
    WHERE content_id = p_content_id AND group_id = p_group_id AND student_id = v_caller_id
  ), reason INTO v_is_manually_unlocked, v_manual_reason
  FROM public.manual_lesson_unlocks
  WHERE content_id = p_content_id AND group_id = p_group_id AND student_id = v_caller_id
  LIMIT 1;

  RETURN jsonb_build_object(
    'content_group_id', v_cg.id,
    'content_id', p_content_id,
    'group_id', p_group_id,
    'sort_order', v_cg.sort_order,
    'pdf_file_id', v_file_id,
    'pdf_file_name', v_file_name,
    'pdf_storage_path', v_file_storage_path,
    'lesson_exam_id', v_cg.associated_exam_id,
    'lesson_exam_title', v_exam_title,
    'lesson_exam_passing_score', COALESCE(v_cg.passing_score_override, v_exam_passing_score, v_group.default_passing_score, 60),
    'lesson_exam_questions_count', v_questions_count,
    'attached_exams', v_attached_exams,
    'passing_score_override', v_cg.passing_score_override,
    'group_default_passing_score', v_group.default_passing_score,
    'enforce_sequential', COALESCE(v_group.enforce_sequential_learning, true),
    'is_manually_unlocked', COALESCE(v_is_manually_unlocked, false),
    'manual_unlock_reason', v_manual_reason
  );
END;
$function$;

-- 2. Update get_group_course_progress to resolve PDF files with fallback
CREATE OR REPLACE FUNCTION public.get_group_course_progress(p_group_id uuid, p_student_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
      COALESCE(cg.file_id, f.file_id) AS pdf_file_id,
      f.file_name AS pdf_file_name,
      f.storage_path AS pdf_storage_path,
      COALESCE(cg.associated_exam_id, c.associated_exam_id, CASE WHEN c.type = 'exam' THEN e.id ELSE NULL END) AS lesson_exam_id,
      COALESCE(e.title, c.title) AS lesson_exam_title,
      COALESCE(cg.passing_score_override, e.passing_score, g.default_passing_score, 60) AS effective_passing_score,
      cg.prerequisite_exam_id,
      COALESCE(vp.progress_seconds, 0) AS video_progress_seconds,
      COALESCE(vp.furthest_position_seconds, 0) AS furthest_legitimate_position,
      COALESCE(vp.duration_seconds, 0) AS video_duration_seconds,
      COALESCE(vp.watched_coverage_percent, 0) AS watched_coverage_percent,
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
    JOIN public.content c ON c.id = cg.content_id
    JOIN public.groups g ON g.id = p_group_id
    LEFT JOIN public.chapters ch ON ch.id = cg.chapter_id
    LEFT JOIN LATERAL (
      SELECT f_sub.id AS file_id, f_sub.file_name, f_sub.storage_path
      FROM public.files f_sub
      WHERE (cg.file_id IS NOT NULL AND f_sub.id = cg.file_id)
         OR (cg.file_id IS NULL AND f_sub.content_id = c.id)
      ORDER BY (f_sub.id = cg.file_id) DESC, f_sub.created_at DESC
      LIMIT 1
    ) f ON true
    LEFT JOIN public.exams e ON (e.id = COALESCE(cg.associated_exam_id, c.associated_exam_id) OR (c.type = 'exam' AND e.content_id = c.id))
    LEFT JOIN LATERAL (
      SELECT 
        COALESCE(vp_sub.progress_seconds, 0) AS progress_seconds,
        COALESCE(vp_sub.furthest_position_seconds, 0) AS furthest_position_seconds,
        COALESCE(vp_sub.duration_seconds, v.duration, 0) AS duration_seconds,
        COALESCE(vp_sub.watched_coverage_percentage, vp_sub.percentage, 0) AS watched_coverage_percent,
        COALESCE(vp_sub.completed, false) AS video_completed
      FROM public.videos v
      LEFT JOIN public.video_progress vp_sub ON vp_sub.video_id = v.id AND vp_sub.student_id = v_target_student
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
      AND (v_caller_role = 'teacher' OR (cg.is_published = true AND c.status = 'published'))
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

    IF v_lesson_row.content_type = 'exam' THEN
      IF v_exam_passed THEN
        v_progress_state := 'completed';
        v_prev_lesson_completed := true;
      ELSIF v_lesson_row.exam_best_score IS NOT NULL THEN
        v_progress_state := 'in_progress';
        v_prev_lesson_completed := false;
      ELSE
        v_progress_state := 'not_started';
        v_prev_lesson_completed := false;
      END IF;
    ELSIF v_lesson_row.lesson_exam_id IS NOT NULL THEN
      IF v_video_completed AND v_exam_passed THEN
        v_progress_state := 'completed';
        v_prev_lesson_completed := true;
      ELSIF v_video_completed OR v_lesson_row.video_progress_seconds > 0 THEN
        v_progress_state := 'in_progress';
        v_prev_lesson_completed := false;
      ELSE
        v_progress_state := 'not_started';
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
      'last_position_seconds',          v_lesson_row.video_progress_seconds,
      'furthest_legitimate_position',   v_lesson_row.furthest_legitimate_position,
      'video_duration_seconds',         v_lesson_row.video_duration_seconds,
      'watched_coverage_percent',       v_lesson_row.watched_coverage_percent,
      'video_completed',                v_video_completed,
      'has_pdf',                        (v_lesson_row.pdf_file_id IS NOT NULL),
      'pdf_state',                      v_pdf_state,
      'pdf_file_id',                    v_lesson_row.pdf_file_id,
      'pdf_file_name',                  v_lesson_row.pdf_file_name,
      'pdf_storage_path',               v_lesson_row.pdf_storage_path,
      'has_quiz',                       (v_lesson_row.lesson_exam_id IS NOT NULL),
      'quiz_state',                     v_quiz_state,
      'quiz_id',                        v_lesson_row.lesson_exam_id,
      'quiz_title',                     v_lesson_row.lesson_exam_title,
      'lesson_exam_id',                 v_lesson_row.lesson_exam_id,
      'lesson_exam_title',              v_lesson_row.lesson_exam_title,
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
        AND (v_caller_role = 'teacher' OR ch.is_published = true)
    ),
    'lessons',                    to_jsonb(v_lessons_list)
  );
END;
$function$;
