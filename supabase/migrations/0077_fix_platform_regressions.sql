-- ==============================================================================
-- Migration 0077: Fix Platform Regressions, Course Progress RPC, and Lesson Exams
-- ==============================================================================

-- 1. Ensure lesson_exams has the is_required column required by the client
ALTER TABLE public.lesson_exams 
  ADD COLUMN IF NOT EXISTS is_required boolean NOT NULL DEFAULT true;

-- Ensure RLS on lesson_exams is completely consistent and indexed
CREATE INDEX IF NOT EXISTS idx_lesson_exams_composite 
  ON public.lesson_exams(group_id, content_id, exam_id);

DROP POLICY IF EXISTS lesson_exams_teacher ON public.lesson_exams;
DROP POLICY IF EXISTS teacher_manage_lesson_exams ON public.lesson_exams;
CREATE POLICY lesson_exams_teacher ON public.lesson_exams
  FOR ALL TO authenticated
  USING (
    (SELECT has_role('teacher'))
    AND (SELECT tenant_is_active())
    AND tenant_id = (SELECT my_tenant_id())
  )
  WITH CHECK (
    (SELECT has_role('teacher'))
    AND (SELECT tenant_is_active())
    AND tenant_id = (SELECT my_tenant_id())
  );

DROP POLICY IF EXISTS lesson_exams_student ON public.lesson_exams;
DROP POLICY IF EXISTS student_view_lesson_exams ON public.lesson_exams;
CREATE POLICY lesson_exams_student ON public.lesson_exams
  FOR SELECT TO authenticated
  USING (
    (SELECT has_role('student'))
    AND (SELECT tenant_is_active())
    AND tenant_id = (SELECT my_tenant_id())
    AND EXISTS (
      SELECT 1 FROM public.group_members gm
      WHERE gm.group_id = lesson_exams.group_id
        AND gm.student_id = (SELECT auth.uid())
        AND gm.status = 'active'
    )
  );

DROP POLICY IF EXISTS lesson_exams_parent ON public.lesson_exams;
DROP POLICY IF EXISTS parent_view_lesson_exams ON public.lesson_exams;
CREATE POLICY lesson_exams_parent ON public.lesson_exams
  FOR SELECT TO authenticated
  USING (
    (SELECT has_role('parent'))
    AND (SELECT tenant_is_active())
    AND tenant_id = (SELECT my_tenant_id())
    AND EXISTS (
      SELECT 1 FROM public.parent_students ps
      JOIN public.group_members gm ON gm.student_id = ps.student_id
      WHERE ps.parent_id = (SELECT auth.uid())
        AND gm.group_id = lesson_exams.group_id
        AND gm.status = 'active'
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON public.lesson_exams TO authenticated;


-- 2. Rock-Solid, High-Performance get_group_course_progress RPC
-- Eliminates missing column errors (watched_coverage_percentage / video_id)
-- Correctly handles teachers, students, and parents with zero RLS recursion
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
    LEFT JOIN public.files f ON f.id = cg.file_id
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
$$;

GRANT EXECUTE ON FUNCTION public.get_group_course_progress(uuid, uuid) TO authenticated;


-- 3. Upgrade get_teacher_group_exams RPC to cover multi-exam associations
CREATE OR REPLACE FUNCTION public.get_teacher_group_exams(
    p_group_id uuid,
    p_page int DEFAULT 0,
    p_page_size int DEFAULT 15
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_tenant_id uuid;
    v_user_role text;
    v_result jsonb;
BEGIN
    SELECT role, tenant_id INTO v_user_role, v_tenant_id
    FROM public.users
    WHERE id = auth.uid();

    IF v_user_role != 'teacher' OR v_tenant_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: only teachers can view teacher exams';
    END IF;

    WITH matched_exams AS (
        SELECT 
            e.id,
            e.content_id,
            e.tenant_id,
            e.duration_minutes,
            e.max_score,
            e.passing_score,
            e.shuffle_questions,
            e.show_result,
            e.allow_retake,
            e.start_at,
            e.end_at,
            e.created_at,
            e.updated_at,
            e.folder_id,
            c.title AS exam_title,
            c.group_id AS content_group_id,
            c.description AS content_description,
            c.status AS content_status
        FROM public.exams e
        JOIN public.content c ON c.id = e.content_id
        WHERE c.group_id = p_group_id
          AND e.tenant_id = v_tenant_id
          AND c.status != 'archived'
        UNION
        SELECT 
            e.id,
            e.content_id,
            e.tenant_id,
            e.duration_minutes,
            e.max_score,
            e.passing_score,
            e.shuffle_questions,
            e.show_result,
            e.allow_retake,
            e.start_at,
            e.end_at,
            e.created_at,
            e.updated_at,
            e.folder_id,
            c.title AS exam_title,
            c.group_id AS content_group_id,
            c.description AS content_description,
            c.status AS content_status
        FROM public.exams e
        JOIN public.content c ON c.id = e.content_id
        JOIN public.content_groups cg ON cg.associated_exam_id = e.id
        WHERE cg.group_id = p_group_id
          AND e.tenant_id = v_tenant_id
          AND c.status != 'archived'
        UNION
        SELECT 
            e.id,
            e.content_id,
            e.tenant_id,
            e.duration_minutes,
            e.max_score,
            e.passing_score,
            e.shuffle_questions,
            e.show_result,
            e.allow_retake,
            e.start_at,
            e.end_at,
            e.created_at,
            e.updated_at,
            e.folder_id,
            c.title AS exam_title,
            c.group_id AS content_group_id,
            c.description AS content_description,
            c.status AS content_status
        FROM public.exams e
        JOIN public.content c ON c.id = e.content_id
        JOIN public.lesson_exams le ON le.exam_id = e.id
        WHERE le.group_id = p_group_id
          AND e.tenant_id = v_tenant_id
          AND c.status != 'archived'
        ORDER BY created_at DESC
        LIMIT p_page_size OFFSET (p_page * p_page_size)
    ),
    exam_stats AS (
        SELECT 
            me.id AS exam_id,
            count(ea.id)::int AS attempts_count
        FROM matched_exams me
        LEFT JOIN public.exam_attempts ea ON ea.exam_id = me.id
        GROUP BY me.id
    ),
    exam_versions_agg AS (
        SELECT 
            ev.exam_id,
            jsonb_agg(
                jsonb_build_object(
                    'id', ev.id,
                    'exam_id', ev.exam_id,
                    'version_number', ev.version_number,
                    'status', ev.status,
                    'created_at', ev.created_at,
                    'published_at', ev.published_at,
                    'exam_questions', jsonb_build_array(
                        jsonb_build_object('count', (
                            SELECT count(*)::int
                            FROM public.exam_questions eq
                            WHERE eq.exam_version_id = ev.id
                        ))
                    )
                ) ORDER BY ev.version_number DESC
            ) AS versions_json
        FROM public.exam_versions ev
        WHERE ev.exam_id IN (SELECT id FROM matched_exams)
        GROUP BY ev.exam_id
    )
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', me.id,
                'content_id', me.content_id,
                'tenant_id', me.tenant_id,
                'duration_minutes', me.duration_minutes,
                'max_score', me.max_score,
                'passing_score', me.passing_score,
                'shuffle_questions', me.shuffle_questions,
                'show_result', me.show_result,
                'allow_retake', me.allow_retake,
                'start_at', me.start_at,
                'end_at', me.end_at,
                'created_at', me.created_at,
                'updated_at', me.updated_at,
                'title', me.exam_title,
                'folder_id', me.folder_id,
                'folder', (
                    SELECT jsonb_build_object('id', ef.id, 'name', ef.name, 'color', ef.color, 'icon', ef.icon)
                    FROM public.exam_folders ef
                    WHERE ef.id = me.folder_id
                ),
                'content', jsonb_build_object(
                    'id', me.content_id,
                    'group_id', me.content_group_id,
                    'title', me.exam_title,
                    'description', me.content_description,
                    'status', me.content_status,
                    'groups', (SELECT jsonb_build_object('name', g.name) FROM public.groups g WHERE g.id = me.content_group_id)
                ),
                'exam_versions', COALESCE(eva.versions_json, '[]'::jsonb),
                'attempts_count', COALESCE(es.attempts_count, 0),
                'linked_lesson_id', (
                    SELECT cg.content_id::text
                    FROM public.content_groups cg
                    WHERE cg.associated_exam_id = me.id AND cg.group_id = p_group_id
                    LIMIT 1
                ),
                'linked_lesson_title', (
                    SELECT c_linked.title
                    FROM public.content_groups cg
                    JOIN public.content c_linked ON c_linked.id = cg.content_id
                    WHERE cg.associated_exam_id = me.id AND cg.group_id = p_group_id
                    LIMIT 1
                ),
                'is_lecture_exam', (
                    EXISTS (
                        SELECT 1 FROM public.content_groups cg
                        WHERE cg.associated_exam_id = me.id AND cg.group_id = p_group_id
                    )
                )
            ) ORDER BY me.created_at DESC
        ),
        '[]'::jsonb
    ) INTO v_result
    FROM matched_exams me
    LEFT JOIN exam_stats es ON es.exam_id = me.id
    LEFT JOIN exam_versions_agg eva ON eva.exam_id = me.id;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_teacher_group_exams(uuid, int, int) TO authenticated;


-- 4. Stabilize sort_order for Existing Group Content
-- Group SAT: '266d0e81-55e6-493e-98b6-76d6d3769bac'
-- Chapter '(trail octoper)2026real exams'
UPDATE public.content_groups
SET sort_order = 1
WHERE group_id = '266d0e81-55e6-493e-98b6-76d6d3769bac'
  AND content_id = '2523fa53-0435-48f6-bf1e-712e34a501ae';

UPDATE public.content_groups
SET sort_order = 2
WHERE group_id = '266d0e81-55e6-493e-98b6-76d6d3769bac'
  AND content_id = '87589294-f184-4e9a-83f3-02ff626c2ecb';

-- Chapter 'questions bank'
UPDATE public.content_groups
SET sort_order = 1
WHERE group_id = '266d0e81-55e6-493e-98b6-76d6d3769bac'
  AND content_id = 'c809dad8-fa61-4bc8-8ed0-0575f660a498';

UPDATE public.content_groups
SET sort_order = 2
WHERE group_id = '266d0e81-55e6-493e-98b6-76d6d3769bac'
  AND content_id = '6a503e06-a700-4ab3-aeb0-6957b496430e';

UPDATE public.content_groups
SET sort_order = 3
WHERE group_id = '266d0e81-55e6-493e-98b6-76d6d3769bac'
  AND content_id = 'b6905c22-4248-4f62-9fd5-340e908d0a02';

UPDATE public.content_groups
SET sort_order = 4
WHERE group_id = '266d0e81-55e6-493e-98b6-76d6d3769bac'
  AND content_id = '072a0da9-005e-4068-b29a-af6ed54a962e';

UPDATE public.content_groups
SET sort_order = 5
WHERE group_id = '266d0e81-55e6-493e-98b6-76d6d3769bac'
  AND content_id = '9ce08ebf-9363-48cd-a5f8-4485de310922';

-- Group ACT: '8a501a59-a187-430c-8eee-b879ee2c2310'
-- Chapter 'test 1'
UPDATE public.content_groups
SET sort_order = 1
WHERE group_id = '8a501a59-a187-430c-8eee-b879ee2c2310'
  AND content_id = '36f4eb4a-6ce6-42d2-a795-9415f7f6923d';
