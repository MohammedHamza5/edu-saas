-- ==============================================================================
-- Migration 0017: Fix Course Lesson Reordering & Sync Between Teacher and Student
-- Ensures that lesson ordering performed by teachers (in ContentCubit/content table)
-- is 100% reflected on the student side (content_groups & get_group_course_progress).
-- ==============================================================================

-- 1. Sync existing content_groups sort_order from content.sort_order
UPDATE public.content_groups cg
SET sort_order = c.sort_order
FROM public.content c
WHERE cg.content_id = c.id
  AND cg.sort_order != c.sort_order;

-- 2. Drop obsolete overload of reorder_content_items to avoid ambiguous signature
DROP FUNCTION IF EXISTS public.reorder_content_items(UUID[]);

-- 3. Update reorder_content_items to update BOTH content and content_groups
CREATE OR REPLACE FUNCTION public.reorder_content_items(
  p_ids UUID[],
  p_group_id UUID DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_now TIMESTAMPTZ := NOW();
BEGIN
  IF p_ids IS NULL OR array_length(p_ids, 1) IS NULL THEN
    RETURN;
  END IF;

  FOR i IN 1..array_length(p_ids, 1) LOOP
    -- 1) Update public.content.sort_order
    UPDATE public.content
    SET
      sort_order = i - 1,
      updated_at = v_now
    WHERE id = p_ids[i];

    -- 2) Update public.content_groups.sort_order for this group or all groups
    IF p_group_id IS NOT NULL THEN
      UPDATE public.content_groups
      SET sort_order = i - 1
      WHERE content_id = p_ids[i] AND group_id = p_group_id;
    ELSE
      UPDATE public.content_groups
      SET sort_order = i - 1
      WHERE content_id = p_ids[i];
    END IF;
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.reorder_content_items(UUID[], UUID) TO authenticated;

-- 4. Database Trigger: Guarantee that any change to content.sort_order or group_id
-- automatically propagates to content_groups
CREATE OR REPLACE FUNCTION public.trg_sync_content_to_content_groups()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.group_id IS NOT NULL THEN
    INSERT INTO public.content_groups (
      tenant_id,
      content_id,
      group_id,
      sort_order,
      associated_exam_id,
      prerequisite_exam_id
    )
    VALUES (
      NEW.tenant_id,
      NEW.id,
      NEW.group_id,
      COALESCE(NEW.sort_order, 0),
      NEW.associated_exam_id,
      NEW.prerequisite_exam_id
    )
    ON CONFLICT (content_id, group_id) DO UPDATE
    SET sort_order = EXCLUDED.sort_order,
        associated_exam_id = COALESCE(EXCLUDED.associated_exam_id, content_groups.associated_exam_id),
        prerequisite_exam_id = COALESCE(EXCLUDED.prerequisite_exam_id, content_groups.prerequisite_exam_id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_content_to_content_groups ON public.content;
CREATE TRIGGER trg_sync_content_to_content_groups
AFTER INSERT OR UPDATE OF group_id, sort_order ON public.content
FOR EACH ROW
EXECUTE FUNCTION public.trg_sync_content_to_content_groups();

-- 5. Update get_group_course_progress to sort deterministically by:
-- ORDER BY cg.sort_order ASC, c.sort_order ASC, c.created_at ASC
CREATE OR REPLACE FUNCTION public.get_group_course_progress(
  p_group_id uuid,
  p_student_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id      uuid := auth.uid();
  v_caller_tenant  uuid;
  v_caller_role    text;
  v_target_student uuid;
  v_enforce_seq    boolean;
  v_result         jsonb := '[]'::jsonb;
  v_lesson_row     record;
  
  -- Tracking states for sequential evaluation
  v_is_first           boolean := true;
  v_prev_completed     boolean := true;
  
  -- Computed fields
  v_access_state       text;
  v_progress_state     text;
  v_unlock_source      text;
  
  -- Data fields
  v_video_completed    boolean;
  v_exam_passed        boolean;
  v_has_progress       boolean;
  v_effective_passing  int;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT tenant_id, role INTO v_caller_tenant, v_caller_role
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
  SELECT enforce_sequential_learning INTO v_enforce_seq
  FROM public.groups
  WHERE id = p_group_id;

  -- Build JSON array by iterating over lessons ordered by sort_order
  FOR v_lesson_row IN (
    SELECT 
      cg.id AS content_group_id,
      c.id AS content_id,
      COALESCE(cg.custom_title, c.title) AS title,
      c.description,
      cg.sort_order,
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
          SELECT 1 FROM public.exam_attempts ea
          WHERE ea.exam_id = cg.prerequisite_exam_id AND ea.student_id = v_target_student AND ea.status = 'completed'
            AND ea.score >= COALESCE(
              (SELECT passing_score_override FROM public.content_groups cg2 WHERE cg2.associated_exam_id = cg.prerequisite_exam_id AND cg2.group_id = p_group_id LIMIT 1),
              (SELECT passing_score FROM public.exams WHERE id = cg.prerequisite_exam_id LIMIT 1),
              g.default_passing_score, 60
            )
        )
      ) AS prereq_passed,
      (
        SELECT EXISTS (
          SELECT 1 FROM public.manual_lesson_unlocks mlu
          WHERE mlu.student_id = v_target_student AND mlu.content_id = c.id AND mlu.group_id = p_group_id
        )
      ) AS is_manually_unlocked
    FROM public.content_groups cg
    JOIN public.content c ON c.id = cg.content_id AND c.status = 'published'
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
    ORDER BY cg.sort_order ASC, c.sort_order ASC, c.created_at ASC
  ) LOOP
  
    -- Initialize states
    v_access_state := 'locked';
    v_unlock_source := null;
    v_progress_state := 'not_started';
    
    v_video_completed := v_lesson_row.video_completed;
    v_exam_passed := COALESCE(v_lesson_row.exam_passed, false);
    v_has_progress := (COALESCE(v_lesson_row.watched_coverage_percent, 0) > 0);
    v_effective_passing := v_lesson_row.effective_passing_score;

    -- Evaluate Progress State
    IF v_lesson_row.content_type != 'video' THEN
       v_video_completed := true; -- PDFs and assignments don't have video progress
    END IF;

    IF v_video_completed AND v_lesson_row.lesson_exam_id IS NOT NULL AND v_exam_passed THEN
      v_progress_state := 'completed';
    ELSIF v_video_completed AND v_lesson_row.lesson_exam_id IS NULL THEN
      v_progress_state := 'completed';
    ELSIF v_video_completed AND v_lesson_row.lesson_exam_id IS NOT NULL AND NOT v_exam_passed THEN
      IF v_lesson_row.exam_best_score IS NOT NULL THEN
        v_progress_state := 'quiz_failed';
      ELSE
        v_progress_state := 'quiz_available';
      END IF;
    ELSIF v_has_progress THEN
      v_progress_state := 'in_progress';
    ELSE
      v_progress_state := 'not_started';
    END IF;

    -- Evaluate Access State and Unlock Source
    IF v_target_student IS NULL THEN
      -- If teacher is just viewing the course structure without a student context
      v_access_state := 'unlocked';
      v_unlock_source := 'manual_override';
    ELSE
      IF v_lesson_row.is_manually_unlocked THEN
        v_access_state := 'unlocked';
        v_unlock_source := 'manual_override';
      ELSIF v_has_progress OR v_progress_state = 'completed' THEN
        -- Permanent unlock history: if student started or finished it, they keep access
        v_access_state := 'unlocked';
        v_unlock_source := 'prerequisite_completion';
      ELSIF NOT v_enforce_seq THEN
        v_access_state := 'unlocked';
        v_unlock_source := 'first_lesson'; -- default when non-sequential
      ELSIF v_is_first THEN
        v_access_state := 'unlocked';
        v_unlock_source := 'first_lesson';
      ELSIF v_lesson_row.prerequisite_exam_id IS NOT NULL THEN
        IF v_lesson_row.prereq_passed THEN
          v_access_state := 'unlocked';
          v_unlock_source := 'prerequisite_completion';
        END IF;
      ELSIF v_prev_completed THEN
        v_access_state := 'unlocked';
        v_unlock_source := 'prerequisite_completion';
      END IF;
    END IF;

    -- Update tracking for next iteration
    v_is_first := false;
    v_prev_completed := (v_progress_state = 'completed' OR v_lesson_row.is_manually_unlocked);

    -- Append to result array
    v_result := v_result || jsonb_build_object(
      'content_group_id',              v_lesson_row.content_group_id,
      'content_id',                    v_lesson_row.content_id,
      'group_id',                      p_group_id,
      'title',                         v_lesson_row.title,
      'description',                   v_lesson_row.description,
      'sort_order',                    v_lesson_row.sort_order,
      'content_type',                  v_lesson_row.content_type,
      'pdf_file_id',                   v_lesson_row.pdf_file_id,
      'pdf_file_name',                 v_lesson_row.pdf_file_name,
      'pdf_storage_path',              v_lesson_row.pdf_storage_path,
      'lesson_exam_id',                v_lesson_row.lesson_exam_id,
      'lesson_exam_title',             v_lesson_row.lesson_exam_title,
      'effective_passing_score',       v_effective_passing,
      'prerequisite_exam_id',          v_lesson_row.prerequisite_exam_id,
      
      -- Unified State Tracking
      'access_state',                  v_access_state,
      'progress_state',                v_progress_state,
      'unlock_source',                 v_unlock_source,
      
      'last_position_seconds',         COALESCE(v_lesson_row.video_progress_seconds, 0),
      'video_progress_seconds',        COALESCE(v_lesson_row.video_progress_seconds, 0),
      'furthest_legitimate_position',  COALESCE(v_lesson_row.furthest_legitimate_position, 0),
      'video_duration_seconds',        COALESCE(v_lesson_row.video_duration_seconds, 0),
      'watched_coverage_percent',      COALESCE(v_lesson_row.watched_coverage_percent, 0),
      'video_completed',               v_video_completed,
      'exam_best_score',               v_lesson_row.exam_best_score,
      'exam_passed',                   v_exam_passed,
      'is_manually_unlocked',          v_lesson_row.is_manually_unlocked
    );
  END LOOP;

  RETURN v_result;
END;
$$;
