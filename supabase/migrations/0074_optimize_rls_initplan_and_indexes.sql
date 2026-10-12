-- ==============================================================================
-- Migration 0074: Optimize RLS InitPlans, Break Recursive Subplan Explosion,
--                 Add Covering Indexes, and Speed up Course Progress RPC
-- ==============================================================================

-- 1. Index covering lesson_exams_content_id_fkey & qb_questions
CREATE INDEX IF NOT EXISTS idx_lesson_exams_content ON public.lesson_exams(content_id);
CREATE INDEX IF NOT EXISTS idx_qb_questions_published_rev ON public.qb_questions(current_published_revision_id);
CREATE INDEX IF NOT EXISTS idx_qb_questions_section ON public.qb_questions(section_id);

-- 2. Helper functions to break recursive RLS combinatorial explosion
-- SECURITY DEFINER bypasses child table RLS re-evaluation and reduces planning from 86s to <1ms
CREATE OR REPLACE FUNCTION public.can_student_access_exam(
    p_exam_id uuid,
    p_student_id uuid,
    p_tenant_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM public.exams e
        JOIN public.content c ON c.id = e.content_id
        WHERE e.id = p_exam_id
          AND c.status = 'published'
          AND c.tenant_id = p_tenant_id
          AND (
              c.group_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.group_members gm
                  JOIN public.groups g ON g.id = gm.group_id
                  WHERE gm.student_id = p_student_id
                    AND gm.group_id = c.group_id
                    AND gm.status = 'active'
                    AND (
                        c.published_at IS NULL
                        OR gm.joined_at <= c.published_at
                        OR g.previous_content_access = 'allow'
                    )
              )
              OR EXISTS (
                  SELECT 1 FROM public.content_groups cg
                  JOIN public.groups g ON g.id = cg.group_id
                  JOIN public.group_members gm ON gm.group_id = cg.group_id
                  WHERE (cg.content_id = c.id OR cg.associated_exam_id = e.id)
                    AND gm.student_id = p_student_id
                    AND gm.status = 'active'
                    AND (
                        c.published_at IS NULL
                        OR gm.joined_at <= c.published_at
                        OR g.previous_content_access = 'allow'
                    )
              )
              OR EXISTS (
                  SELECT 1 FROM public.lesson_exams le
                  JOIN public.groups g ON g.id = le.group_id
                  JOIN public.group_members gm ON gm.group_id = le.group_id
                  WHERE le.exam_id = e.id
                    AND gm.student_id = p_student_id
                    AND gm.status = 'active'
                    AND (
                        c.published_at IS NULL
                        OR gm.joined_at <= c.published_at
                        OR g.previous_content_access = 'allow'
                    )
              )
          )
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.can_student_access_question(
    p_question_id uuid,
    p_student_id uuid,
    p_tenant_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_exam_id uuid;
BEGIN
    SELECT ev.exam_id INTO v_exam_id
    FROM public.exam_questions eq
    JOIN public.exam_versions ev ON ev.id = eq.exam_version_id
    WHERE eq.id = p_question_id
      AND ev.status = 'published';

    IF v_exam_id IS NULL THEN
        RETURN false;
    END IF;

    RETURN public.can_student_access_exam(v_exam_id, p_student_id, p_tenant_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_exam_tenant_id(p_exam_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT tenant_id FROM public.exams WHERE id = p_exam_id;
$$;

GRANT EXECUTE ON FUNCTION public.can_student_access_exam(uuid, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_student_access_question(uuid, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_exam_tenant_id(uuid) TO authenticated;

-- 3. Optimize content_groups RLS policies with (SELECT auth.uid()) InitPlan
DROP POLICY IF EXISTS content_groups_student_read ON public.content_groups;
CREATE POLICY content_groups_student_read ON public.content_groups
    FOR SELECT
    USING (
        (SELECT has_role('student'))
        AND (SELECT tenant_is_active())
        AND is_published = true
        AND EXISTS (
            SELECT 1 FROM public.group_members gm
            WHERE gm.group_id = content_groups.group_id
              AND gm.student_id = (SELECT auth.uid())
              AND gm.status = 'active'
        )
    );

DROP POLICY IF EXISTS content_groups_parent_read ON public.content_groups;
CREATE POLICY content_groups_parent_read ON public.content_groups
    FOR SELECT
    USING (
        (SELECT has_role('parent'))
        AND (SELECT tenant_is_active())
        AND EXISTS (
            SELECT 1 FROM public.group_members gm
            JOIN public.parent_students ps ON ps.student_id = gm.student_id
            WHERE ps.parent_id = (SELECT auth.uid())
              AND gm.group_id = content_groups.group_id
              AND gm.status = 'active'
        )
    );

-- 4. Optimize exam_contexts RLS policy
DROP POLICY IF EXISTS exam_contexts_student_read ON public.exam_contexts;
CREATE POLICY exam_contexts_student_read ON public.exam_contexts
    FOR SELECT
    USING (
        (SELECT has_role('student'))
        AND (SELECT tenant_is_active())
        AND EXISTS (
            SELECT 1 FROM public.exam_versions ev
            WHERE ev.id = exam_contexts.exam_version_id
              AND ev.status = 'published'
              AND public.can_student_access_exam(ev.exam_id, (SELECT auth.uid()), (SELECT my_tenant_id()))
        )
    );

-- 5. Optimize exam_versions RLS policies
DROP POLICY IF EXISTS ev_teacher_all ON public.exam_versions;
CREATE POLICY ev_teacher_all ON public.exam_versions
    FOR ALL
    USING (
        (SELECT has_role('teacher'))
        AND (SELECT tenant_is_active())
        AND public.get_exam_tenant_id(exam_id) = (SELECT my_tenant_id())
    )
    WITH CHECK (
        (SELECT has_role('teacher'))
        AND (SELECT tenant_is_active())
        AND public.get_exam_tenant_id(exam_id) = (SELECT my_tenant_id())
    );

DROP POLICY IF EXISTS ev_student_read_published ON public.exam_versions;
CREATE POLICY ev_student_read_published ON public.exam_versions
    FOR SELECT
    USING (
        (SELECT has_role('student'))
        AND (SELECT tenant_is_active())
        AND status = 'published'
        AND public.can_student_access_exam(exam_id, (SELECT auth.uid()), (SELECT my_tenant_id()))
    );

-- 6. Optimize question_options RLS policies
DROP POLICY IF EXISTS qo_student_read_published ON public.question_options;
CREATE POLICY qo_student_read_published ON public.question_options
    FOR SELECT
    USING (
        (SELECT has_role('student'))
        AND (SELECT tenant_is_active())
        AND public.can_student_access_question(question_id, (SELECT auth.uid()), (SELECT my_tenant_id()))
    );

-- 7. Optimize video_folders and video_library
DROP POLICY IF EXISTS folders_teacher_all ON public.video_folders;
CREATE POLICY folders_teacher_all ON public.video_folders
    FOR ALL
    USING (
        tenant_id = (SELECT my_tenant_id())
        AND (SELECT users.role FROM public.users WHERE users.id = (SELECT auth.uid())) = 'teacher'
    )
    WITH CHECK (
        tenant_id = (SELECT my_tenant_id())
        AND (SELECT users.role FROM public.users WHERE users.id = (SELECT auth.uid())) = 'teacher'
    );

DROP POLICY IF EXISTS library_teacher_all ON public.video_library;
CREATE POLICY library_teacher_all ON public.video_library
    FOR ALL
    USING (
        tenant_id = (SELECT my_tenant_id())
        AND (SELECT users.role FROM public.users WHERE users.id = (SELECT auth.uid())) = 'teacher'
    )
    WITH CHECK (
        tenant_id = (SELECT my_tenant_id())
        AND (SELECT users.role FROM public.users WHERE users.id = (SELECT auth.uid())) = 'teacher'
    );

-- 8. Optimize qb_questions
DROP POLICY IF EXISTS qb_questions_student_read_published ON public.qb_questions;
CREATE POLICY qb_questions_student_read_published ON public.qb_questions
    FOR SELECT
    USING (
        status = 'published'
        AND tenant_id = (SELECT qb_my_tenant())
        AND EXISTS (
            SELECT 1 FROM public.users
            WHERE users.id = (SELECT auth.uid())
              AND users.role = 'student'
              AND users.status = 'active'
        )
    );

-- 9. Optimized get_group_course_progress RPC (eliminates N correlated subqueries and $O(N^2)$ jsonb copying)
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
    JOIN public.content c ON c.id = cg.content_id AND c.status = 'published'
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
