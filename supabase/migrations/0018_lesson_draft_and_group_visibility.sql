-- ============================================================================
-- Migration: 0018_lesson_draft_and_group_visibility.sql
-- Description: Adds per-group lesson visibility (draft vs published),
--              bulk visibility toggles, and updates RLS + get_group_course_progress.
-- ============================================================================

-- 1. Add is_published column to content_groups junction table
ALTER TABLE public.content_groups
  ADD COLUMN IF NOT EXISTS is_published boolean NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_content_groups_published
  ON public.content_groups(group_id, is_published);

-- 2. Update RLS policy for students on content_groups
DROP POLICY IF EXISTS content_groups_student_read ON public.content_groups;
CREATE POLICY content_groups_student_read ON public.content_groups
  FOR SELECT TO authenticated
  USING (
    public.has_role('student') 
    AND public.tenant_is_active() 
    AND is_published = true
    AND EXISTS (
      SELECT 1 FROM public.group_members gm
      WHERE gm.group_id = content_groups.group_id
        AND gm.student_id = auth.uid()
        AND gm.status = 'active'
    )
  );

-- 3. Update assign_content_to_groups to support is_published in group_configs
CREATE OR REPLACE FUNCTION public.assign_content_to_groups(
  p_content_id uuid,
  p_group_ids uuid[],
  p_group_configs jsonb DEFAULT '[]'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_role text;
  v_caller_tenant uuid;
  v_content_tenant uuid;
  v_primary_group uuid := NULL;
  v_target_group_id uuid;
  v_config jsonb;
  v_file_id uuid;
  v_assoc_exam_id uuid;
  v_prereq_exam_id uuid;
  v_sort_order int;
  v_custom_title text;
  v_is_published boolean;
BEGIN
  -- Authenticate & authorize caller
  IF NOT public.has_role('teacher') THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only teachers can distribute content to groups';
  END IF;

  v_caller_tenant := public.my_tenant_id();

  SELECT tenant_id INTO v_content_tenant
  FROM public.content
  WHERE id = p_content_id;

  IF v_content_tenant IS NULL THEN
    RAISE EXCEPTION 'CONTENT_NOT_FOUND: Content record does not exist';
  END IF;

  IF v_content_tenant != v_caller_tenant THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Content belongs to another tenant';
  END IF;

  -- Delete existing group junction entries for this content
  DELETE FROM public.content_groups
  WHERE content_id = p_content_id;

  -- If groups provided, insert new junction entries
  IF p_group_ids IS NOT NULL AND array_length(p_group_ids, 1) > 0 THEN
    v_primary_group := p_group_ids[1];

    FOREACH v_target_group_id IN ARRAY p_group_ids
    LOOP
      IF EXISTS (SELECT 1 FROM public.groups WHERE id = v_target_group_id AND tenant_id = v_caller_tenant) THEN
        v_file_id := NULL;
        v_assoc_exam_id := NULL;
        v_prereq_exam_id := NULL;
        v_sort_order := 0;
        v_custom_title := NULL;
        v_is_published := true;

        IF p_group_configs IS NOT NULL AND jsonb_array_length(p_group_configs) > 0 THEN
          SELECT cfg INTO v_config
          FROM jsonb_array_elements(p_group_configs) cfg
          WHERE (cfg->>'group_id')::uuid = v_target_group_id
          LIMIT 1;

          IF v_config IS NOT NULL THEN
            v_file_id := CASE WHEN v_config->>'file_id' IS NOT NULL AND (v_config->>'file_id') != '' THEN (v_config->>'file_id')::uuid ELSE NULL END;
            v_assoc_exam_id := CASE WHEN v_config->>'associated_exam_id' IS NOT NULL AND (v_config->>'associated_exam_id') != '' THEN (v_config->>'associated_exam_id')::uuid ELSE NULL END;
            v_prereq_exam_id := CASE WHEN v_config->>'prerequisite_exam_id' IS NOT NULL AND (v_config->>'prerequisite_exam_id') != '' THEN (v_config->>'prerequisite_exam_id')::uuid ELSE NULL END;
            v_sort_order := COALESCE((v_config->>'sort_order')::int, 0);
            v_custom_title := NULLIF(trim(v_config->>'custom_title'), '');
            v_is_published := COALESCE((v_config->>'is_published')::boolean, true);
          END IF;
        END IF;

        INSERT INTO public.content_groups (
          tenant_id,
          content_id,
          group_id,
          file_id,
          associated_exam_id,
          prerequisite_exam_id,
          sort_order,
          custom_title,
          is_published
        )
        VALUES (
          v_caller_tenant,
          p_content_id,
          v_target_group_id,
          v_file_id,
          v_assoc_exam_id,
          v_prereq_exam_id,
          v_sort_order,
          v_custom_title,
          v_is_published
        )
        ON CONFLICT (content_id, group_id) DO UPDATE
        SET file_id = EXCLUDED.file_id,
            associated_exam_id = EXCLUDED.associated_exam_id,
            prerequisite_exam_id = EXCLUDED.prerequisite_exam_id,
            sort_order = EXCLUDED.sort_order,
            custom_title = EXCLUDED.custom_title,
            is_published = EXCLUDED.is_published;
      END IF;
    END LOOP;
  END IF;

  -- Update primary group_id on content
  UPDATE public.content
  SET group_id = v_primary_group,
      updated_at = now()
  WHERE id = p_content_id;

  RETURN jsonb_build_object(
    'success', true,
    'content_id', p_content_id,
    'primary_group_id', v_primary_group,
    'assigned_count', COALESCE(array_length(p_group_ids, 1), 0)
  );
END;
$$;

-- 4. Atomic RPC: toggle single lesson visibility in a group
CREATE OR REPLACE FUNCTION public.toggle_lesson_group_visibility(
  p_content_id uuid,
  p_group_id uuid,
  p_is_published boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_tenant uuid;
BEGIN
  IF NOT public.has_role('teacher') THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only teachers can toggle lesson visibility';
  END IF;

  v_caller_tenant := public.my_tenant_id();

  UPDATE public.content_groups
  SET is_published = p_is_published
  WHERE content_id = p_content_id
    AND group_id = p_group_id
    AND tenant_id = v_caller_tenant;

  -- If publishing, also ensure the master content record status is published
  IF p_is_published THEN
    UPDATE public.content
    SET status = 'published',
        published_at = COALESCE(published_at, now()),
        updated_at = now()
    WHERE id = p_content_id
      AND tenant_id = v_caller_tenant;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'content_id', p_content_id,
    'group_id', p_group_id,
    'is_published', p_is_published
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.toggle_lesson_group_visibility(uuid, uuid, boolean) TO authenticated;

-- 5. Atomic RPC: bulk toggle all lessons visibility in a group
CREATE OR REPLACE FUNCTION public.toggle_group_all_content_visibility(
  p_group_id uuid,
  p_is_published boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_tenant uuid;
  v_updated_count int;
BEGIN
  IF NOT public.has_role('teacher') THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only teachers can toggle group content visibility';
  END IF;

  v_caller_tenant := public.my_tenant_id();

  UPDATE public.content_groups
  SET is_published = p_is_published
  WHERE group_id = p_group_id
    AND tenant_id = v_caller_tenant;

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;

  -- If publishing all, also ensure all linked master content records are published
  IF p_is_published THEN
    UPDATE public.content
    SET status = 'published',
        published_at = COALESCE(published_at, now()),
        updated_at = now()
    WHERE id IN (
      SELECT content_id FROM public.content_groups
      WHERE group_id = p_group_id AND tenant_id = v_caller_tenant
    )
    AND tenant_id = v_caller_tenant;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'group_id', p_group_id,
    'is_published', p_is_published,
    'updated_count', v_updated_count
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.toggle_group_all_content_visibility(uuid, boolean) TO authenticated;

-- 6. Update get_group_course_progress to respect is_published for students
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
      AND (v_caller_role = 'teacher' OR cg.is_published = true)
    ORDER BY cg.sort_order ASC, c.sort_order ASC, c.created_at ASC
  ) LOOP
  
    -- Initialize states
    v_access_state := 'locked';
    v_unlock_source := null;
    v_progress_state := 'not_started';
    
    v_video_completed := v_lesson_row.video_completed;

    -- Evaluate access state
    IF v_lesson_row.is_manually_unlocked THEN
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

    v_can_access := (v_access_state == 'available');

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
      'furthest_legitimate_position',    v_lesson_row.furthest_legitimate_position,
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
