-- ==============================================================================
-- Migration 0059: Multi-Exams Per Lesson Architecture
-- ==============================================================================
-- 1. Creates public.lesson_exams junction table supporting multiple quizzes per lesson unit
-- 2. Backfills existing content_groups.associated_exam_id into lesson_exams
-- 3. Implements backward-compatibility sync trigger with content_groups.associated_exam_id
-- 4. Updates assign_content_to_groups RPC to support attached_exams
-- 5. Updates get_group_course_progress RPC with multi-exam gatekeeper & attached_exams array
-- 6. Updates start_exam and submit_exam checks to support lesson_exams
-- ==============================================================================

-- 1. Create lesson_exams table
CREATE TABLE IF NOT EXISTS public.lesson_exams (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  group_id uuid NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  content_id uuid NOT NULL REFERENCES public.content(id) ON DELETE CASCADE,
  exam_id uuid NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
  sort_order int NOT NULL DEFAULT 0,
  is_required boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_lesson_group_exam UNIQUE (group_id, content_id, exam_id)
);

-- Indexes for lightning fast lookups
CREATE INDEX IF NOT EXISTS idx_lesson_exams_lookup ON public.lesson_exams(group_id, content_id);
CREATE INDEX IF NOT EXISTS idx_lesson_exams_exam ON public.lesson_exams(exam_id);
CREATE INDEX IF NOT EXISTS idx_lesson_exams_tenant ON public.lesson_exams(tenant_id);

-- Enable RLS
ALTER TABLE public.lesson_exams ENABLE ROW LEVEL SECURITY;

-- 2. RLS Policies
DROP POLICY IF EXISTS teacher_manage_lesson_exams ON public.lesson_exams;
CREATE POLICY teacher_manage_lesson_exams ON public.lesson_exams
  FOR ALL
  TO authenticated
  USING (
    tenant_id = public.my_tenant_id()
    AND public.has_role('teacher')
  )
  WITH CHECK (
    tenant_id = public.my_tenant_id()
    AND public.has_role('teacher')
  );

DROP POLICY IF EXISTS student_view_lesson_exams ON public.lesson_exams;
CREATE POLICY student_view_lesson_exams ON public.lesson_exams
  FOR SELECT
  TO authenticated
  USING (
    tenant_id = public.my_tenant_id()
    AND EXISTS (
      SELECT 1 FROM public.group_members gm
      WHERE gm.group_id = lesson_exams.group_id
        AND gm.student_id = auth.uid()
        AND gm.status = 'active'
    )
    AND EXISTS (
      SELECT 1 FROM public.content_groups cg
      WHERE cg.group_id = lesson_exams.group_id
        AND cg.content_id = lesson_exams.content_id
        AND cg.is_published = true
    )
  );

DROP POLICY IF EXISTS parent_view_lesson_exams ON public.lesson_exams;
CREATE POLICY parent_view_lesson_exams ON public.lesson_exams
  FOR SELECT
  TO authenticated
  USING (
    tenant_id = public.my_tenant_id()
    AND EXISTS (
      SELECT 1 FROM public.parent_students ps
      JOIN public.group_members gm ON gm.student_id = ps.student_id
      WHERE ps.parent_id = auth.uid()
        AND gm.group_id = lesson_exams.group_id
        AND gm.status = 'active'
    )
  );

-- 3. Data Backfill from existing content_groups
INSERT INTO public.lesson_exams (tenant_id, group_id, content_id, exam_id, sort_order, is_required)
SELECT cg.tenant_id, cg.group_id, cg.content_id, cg.associated_exam_id, 0, true
FROM public.content_groups cg
WHERE cg.associated_exam_id IS NOT NULL
ON CONFLICT (group_id, content_id, exam_id) DO NOTHING;

-- 4. Backward Compatibility Sync Trigger
-- Ensures content_groups.associated_exam_id always points to the first attached exam
CREATE OR REPLACE FUNCTION public.sync_lesson_exams_to_content_groups()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_group_id uuid;
  v_content_id uuid;
  v_primary_exam_id uuid;
BEGIN
  v_group_id := COALESCE(NEW.group_id, OLD.group_id);
  v_content_id := COALESCE(NEW.content_id, OLD.content_id);

  -- Get the primary exam for this lesson (lowest sort_order, earliest created)
  SELECT exam_id INTO v_primary_exam_id
  FROM public.lesson_exams
  WHERE group_id = v_group_id AND content_id = v_content_id
  ORDER BY sort_order ASC, created_at ASC
  LIMIT 1;

  UPDATE public.content_groups
  SET associated_exam_id = v_primary_exam_id
  WHERE group_id = v_group_id AND content_id = v_content_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_lesson_exams_to_cg ON public.lesson_exams;
CREATE TRIGGER trg_sync_lesson_exams_to_cg
AFTER INSERT OR UPDATE OR DELETE ON public.lesson_exams
FOR EACH ROW
EXECUTE FUNCTION public.sync_lesson_exams_to_content_groups();

-- 5. Updated assign_content_to_groups to support attached_exams array
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
  v_chapter_id uuid;
  v_file_id uuid;
  v_assoc_exam_id uuid;
  v_prereq_exam_id uuid;
  v_sort_order int;
  v_custom_title text;
  v_is_published boolean;
  v_existing_sort_order int;
  v_max_group_order int;
  v_attached_exams jsonb;
  v_exam_elem jsonb;
  v_idx int;
  v_target_exam_id uuid;
  v_target_sort int;
  v_target_req boolean;
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

  -- Create temporary table to preserve existing sort orders
  CREATE TEMP TABLE IF NOT EXISTS temp_existing_sort_orders (
    group_id uuid PRIMARY KEY,
    sort_order int
  ) ON COMMIT DROP;

  TRUNCATE temp_existing_sort_orders;

  INSERT INTO temp_existing_sort_orders (group_id, sort_order)
  SELECT group_id, sort_order
  FROM public.content_groups
  WHERE content_id = p_content_id;

  -- Delete existing group junction entries for this content
  DELETE FROM public.content_groups
  WHERE content_id = p_content_id;

  -- If groups provided, insert new junction entries
  IF p_group_ids IS NOT NULL AND array_length(p_group_ids, 1) > 0 THEN
    v_primary_group := p_group_ids[1];

    FOREACH v_target_group_id IN ARRAY p_group_ids
    LOOP
      IF EXISTS (SELECT 1 FROM public.groups WHERE id = v_target_group_id AND tenant_id = v_caller_tenant) THEN
        v_chapter_id := NULL;
        v_file_id := NULL;
        v_assoc_exam_id := NULL;
        v_prereq_exam_id := NULL;
        v_sort_order := NULL;
        v_custom_title := NULL;
        v_is_published := true;
        v_existing_sort_order := NULL;
        v_attached_exams := NULL;

        -- Check existing sort order
        SELECT sort_order INTO v_existing_sort_order
        FROM temp_existing_sort_orders
        WHERE group_id = v_target_group_id
        LIMIT 1;

        IF p_group_configs IS NOT NULL AND jsonb_array_length(p_group_configs) > 0 THEN
          SELECT cfg INTO v_config
          FROM jsonb_array_elements(p_group_configs) cfg
          WHERE (cfg->>'group_id')::uuid = v_target_group_id
          LIMIT 1;

          IF v_config IS NOT NULL THEN
            v_chapter_id := CASE WHEN v_config->>'chapter_id' IS NOT NULL AND (v_config->>'chapter_id') != '' THEN (v_config->>'chapter_id')::uuid ELSE NULL END;
            v_file_id := CASE WHEN v_config->>'file_id' IS NOT NULL AND (v_config->>'file_id') != '' THEN (v_config->>'file_id')::uuid ELSE NULL END;
            v_assoc_exam_id := CASE WHEN v_config->>'associated_exam_id' IS NOT NULL AND (v_config->>'associated_exam_id') != '' THEN (v_config->>'associated_exam_id')::uuid ELSE NULL END;
            v_prereq_exam_id := CASE WHEN v_config->>'prerequisite_exam_id' IS NOT NULL AND (v_config->>'prerequisite_exam_id') != '' THEN (v_config->>'prerequisite_exam_id')::uuid ELSE NULL END;
            v_custom_title := NULLIF(trim(v_config->>'custom_title'), '');
            v_is_published := COALESCE((v_config->>'is_published')::boolean, true);
            v_attached_exams := v_config->'attached_exams';

            IF v_config->>'sort_order' IS NOT NULL AND (v_config->>'sort_order') != '' THEN
              v_sort_order := (v_config->>'sort_order')::int;
            END IF;
          END IF;
        END IF;

        -- Calculate max sort_order
        IF v_chapter_id IS NOT NULL THEN
          SELECT COALESCE(MAX(sort_order), -1) + 1 INTO v_max_group_order
          FROM public.content_groups
          WHERE group_id = v_target_group_id AND chapter_id = v_chapter_id;
        ELSE
          SELECT COALESCE(MAX(sort_order), -1) + 1 INTO v_max_group_order
          FROM public.content_groups
          WHERE group_id = v_target_group_id AND chapter_id IS NULL;
        END IF;

        v_sort_order := COALESCE(v_sort_order, v_existing_sort_order, v_max_group_order, 0);

        -- If attached_exams is passed, set primary assoc_exam_id from the first attached exam
        IF v_attached_exams IS NOT NULL AND jsonb_typeof(v_attached_exams) = 'array' AND jsonb_array_length(v_attached_exams) > 0 THEN
          v_assoc_exam_id := ((v_attached_exams->0)->>'exam_id')::uuid;
        END IF;

        INSERT INTO public.content_groups (
          tenant_id,
          content_id,
          group_id,
          chapter_id,
          file_id,
          associated_exam_id,
          prerequisite_exam_id,
          sort_order,
          custom_title,
          is_published
        ) VALUES (
          v_caller_tenant,
          p_content_id,
          v_target_group_id,
          v_chapter_id,
          v_file_id,
          v_assoc_exam_id,
          v_prereq_exam_id,
          v_sort_order,
          v_custom_title,
          v_is_published
        );

        -- Sync lesson_exams table for this lesson
        IF v_attached_exams IS NOT NULL AND jsonb_typeof(v_attached_exams) = 'array' THEN
          -- Clear existing lesson_exams for this lesson in this group
          DELETE FROM public.lesson_exams
          WHERE group_id = v_target_group_id AND content_id = p_content_id;

          v_idx := 0;
          FOR v_exam_elem IN SELECT * FROM jsonb_array_elements(v_attached_exams)
          LOOP
            v_target_exam_id := (v_exam_elem->>'exam_id')::uuid;
            v_target_sort := COALESCE((v_exam_elem->>'sort_order')::int, v_idx);
            v_target_req := COALESCE((v_exam_elem->>'is_required')::boolean, true);

            IF v_target_exam_id IS NOT NULL THEN
              INSERT INTO public.lesson_exams (
                tenant_id,
                group_id,
                content_id,
                exam_id,
                sort_order,
                is_required
              ) VALUES (
                v_caller_tenant,
                v_target_group_id,
                p_content_id,
                v_target_exam_id,
                v_target_sort,
                v_target_req
              )
              ON CONFLICT (group_id, content_id, exam_id)
              DO UPDATE SET
                sort_order = EXCLUDED.sort_order,
                is_required = EXCLUDED.is_required,
                updated_at = now();
            END IF;
            v_idx := v_idx + 1;
          END LOOP;
        ELSIF v_assoc_exam_id IS NOT NULL THEN
          -- Legacy fallback: single associated_exam_id
          INSERT INTO public.lesson_exams (
            tenant_id,
            group_id,
            content_id,
            exam_id,
            sort_order,
            is_required
          ) VALUES (
            v_caller_tenant,
            v_target_group_id,
            p_content_id,
            v_assoc_exam_id,
            0,
            true
          )
          ON CONFLICT (group_id, content_id, exam_id) DO NOTHING;
        ELSE
          -- No exams attached: clear lesson_exams
          DELETE FROM public.lesson_exams
          WHERE group_id = v_target_group_id AND content_id = p_content_id;
        END IF;

      END IF;
    END LOOP;
  END IF;

  -- Update primary group on content
  UPDATE public.content
  SET 
    group_id = v_primary_group,
    associated_exam_id = v_assoc_exam_id,
    updated_at = now()
  WHERE id = p_content_id;

  RETURN jsonb_build_object(
    'success', true,
    'content_id', p_content_id,
    'assigned_groups_count', array_length(p_group_ids, 1)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.assign_content_to_groups(uuid, uuid[], jsonb) TO authenticated;

-- 6. Updated get_group_course_progress with multi-exam gatekeeper & attached_exams array
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
  v_has_required_exams BOOLEAN;
  v_all_required_passed BOOLEAN;
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
      COALESCE(cg.associated_exam_id, c.associated_exam_id) AS lesson_exam_id,
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
        WHERE ea.exam_id = COALESCE(cg.associated_exam_id, c.associated_exam_id)
          AND ea.student_id = v_target_student
          AND ea.status IN ('submitted', 'completed')
      ) AS exam_best_score,
      (
        SELECT EXISTS (
          SELECT 1 FROM public.exam_attempts ea
          WHERE ea.exam_id = COALESCE(cg.associated_exam_id, c.associated_exam_id)
            AND ea.student_id = v_target_student
            AND ea.status IN ('submitted', 'completed')
            AND ea.score >= COALESCE(cg.passing_score_override, e.passing_score, g.default_passing_score, 60)
        )
      ) AS exam_passed,
      (
        SELECT EXISTS (
          SELECT 1 FROM public.manual_lesson_unlocks mlu
          WHERE mlu.student_id = v_target_student AND mlu.content_id = c.id AND mlu.group_id = p_group_id
        )
      ) AS is_manually_unlocked,
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
              ORDER BY ea.created_at DESC LIMIT 1
            )
          ) ORDER BY le.sort_order ASC, le.created_at ASC
        ), '[]'::jsonb)
        FROM public.lesson_exams le
        JOIN public.exams ex ON ex.id = le.exam_id
        WHERE le.group_id = p_group_id AND le.content_id = c.id
      ) AS attached_exams
    FROM public.content_groups cg
    JOIN public.content c ON c.id = cg.content_id 
                         AND c.status = 'published' 
                         AND (c.type = 'video' OR c.type IS NULL OR c.type = 'lesson')
                         AND c.type != 'exam'
                         AND c.type != 'assignment'
    LEFT JOIN public.chapters ch ON ch.id = cg.chapter_id
    LEFT JOIN public.files f ON f.id = cg.file_id
    LEFT JOIN public.exams e ON e.id = COALESCE(cg.associated_exam_id, c.associated_exam_id)
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
    ORDER BY COALESCE(ch.sort_order, 999999) ASC, cg.sort_order ASC, c.sort_order ASC, c.created_at ASC
  ) LOOP
  
    v_access_state := 'locked';
    v_unlock_source := null;
    v_progress_state := 'not_started';
    v_video_completed := v_lesson_row.video_completed;

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

    -- Multi-exam Gatekeeper Logic:
    -- 1. Check if there are any required exams in lesson_exams
    v_has_required_exams := EXISTS (
      SELECT 1 FROM public.lesson_exams le
      WHERE le.group_id = p_group_id AND le.content_id = v_lesson_row.content_id AND le.is_required = true
    );

    IF v_has_required_exams THEN
      -- Student must pass ALL required exams
      v_all_required_passed := NOT EXISTS (
        SELECT 1 FROM public.lesson_exams le
        JOIN public.exams ex ON ex.id = le.exam_id
        WHERE le.group_id = p_group_id
          AND le.content_id = v_lesson_row.content_id
          AND le.is_required = true
          AND NOT EXISTS (
            SELECT 1 FROM public.exam_attempts ea
            WHERE ea.exam_id = le.exam_id
              AND ea.student_id = v_target_student
              AND ea.status IN ('submitted', 'completed')
              AND ea.score >= COALESCE(ex.passing_score, 60)
          )
      );
    ELSE
      -- Fallback to legacy single exam if present
      IF v_lesson_row.lesson_exam_id IS NOT NULL THEN
        v_all_required_passed := v_lesson_row.exam_passed;
      ELSE
        v_all_required_passed := true;
      END IF;
    END IF;

    IF (v_has_required_exams OR v_lesson_row.lesson_exam_id IS NOT NULL) THEN
      IF v_all_required_passed THEN
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

    IF v_lesson_row.lesson_exam_id IS NOT NULL OR v_has_required_exams THEN
      IF v_all_required_passed THEN
        v_quiz_state := 'passed';
      ELSIF v_lesson_row.exam_best_score IS NOT NULL THEN
        v_quiz_state := 'failed';
      ELSE
        v_quiz_state := CASE WHEN v_can_access THEN 'available' ELSE 'locked' END;
      END IF;
    ELSE
      v_quiz_state := 'none';
    END IF;

    v_all_prev_completed := v_all_prev_completed AND v_prev_lesson_completed;

    v_lessons_arr := v_lessons_arr || jsonb_build_object(
      'content_group_id',             v_lesson_row.content_group_id,
      'content_id',                   v_lesson_row.content_id,
      'title',                        v_lesson_row.title,
      'description',                  v_lesson_row.description,
      'sort_order',                   v_lesson_row.sort_order,
      'is_published',                 v_lesson_row.is_published,
      'chapter_id',                   v_lesson_row.chapter_id,
      'chapter_title',                v_lesson_row.chapter_title,
      'chapter_sort_order',           v_lesson_row.chapter_sort_order,
      'access_state',                 v_access_state,
      'unlock_source',                v_unlock_source,
      'progress_state',               v_progress_state,
      'can_access',                   v_can_access,
      'video_progress_seconds',       v_lesson_row.video_progress_seconds,
      'furthest_legitimate_position', v_lesson_row.furthest_legitimate_position,
      'video_duration_seconds',       v_lesson_row.video_duration_seconds,
      'watched_coverage_percent',     v_lesson_row.watched_coverage_percent,
      'video_completed',              v_video_completed,
      'pdf_file_id',                  v_lesson_row.pdf_file_id,
      'pdf_file_name',                v_lesson_row.pdf_file_name,
      'pdf_storage_path',             v_lesson_row.pdf_storage_path,
      'pdf_state',                    v_pdf_state,
      'lesson_exam_id',               v_lesson_row.lesson_exam_id,
      'lesson_exam_title',            v_lesson_row.lesson_exam_title,
      'effective_passing_score',      v_lesson_row.effective_passing_score,
      'exam_best_score',              v_lesson_row.exam_best_score,
      'exam_passed',                  v_lesson_row.exam_passed,
      'quiz_state',                   v_quiz_state,
      'attached_exams',               v_lesson_row.attached_exams
    );
  END LOOP;

  RETURN jsonb_build_object(
    'group_id', p_group_id,
    'student_id', v_target_student,
    'enforce_sequential_learning', v_enforce_seq,
    'lessons', v_lessons_arr
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_group_course_progress(uuid, uuid) TO authenticated;

-- 7. Update start_exam & submit_exam helper recognition for lesson_exams
-- Ensures untimed & unlimited retakes apply to any exam linked in lesson_exams
CREATE OR REPLACE FUNCTION public.is_lecture_exam(p_exam_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT (
    EXISTS (SELECT 1 FROM public.lesson_exams le WHERE le.exam_id = p_exam_id)
    OR EXISTS (SELECT 1 FROM public.content_groups cg WHERE cg.associated_exam_id = p_exam_id)
    OR EXISTS (SELECT 1 FROM public.content c2 WHERE c2.associated_exam_id = p_exam_id)
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_lecture_exam(uuid) TO authenticated;

-- 8. Update get_lesson_context to return attached_exams array
CREATE OR REPLACE FUNCTION public.get_lesson_context(
  p_content_id uuid,
  p_group_id   uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id     uuid := auth.uid();
  v_caller_tenant uuid;
  v_caller_role   text;
  v_result        jsonb;
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

  -- Verify access permissions
  IF v_caller_role = 'student' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.group_members gm
      WHERE gm.group_id = p_group_id
        AND gm.student_id = v_caller_id
        AND gm.status = 'active'
    ) THEN
      RAISE EXCEPTION 'NOT_AUTHORIZED';
    END IF;
  ELSIF v_caller_role = 'teacher' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.groups g
      WHERE g.id = p_group_id AND g.tenant_id = v_caller_tenant
    ) THEN
      RAISE EXCEPTION 'NOT_AUTHORIZED';
    END IF;
  ELSIF v_caller_role = 'parent' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.group_members gm
      JOIN public.parent_students ps ON ps.student_id = gm.student_id
      WHERE gm.group_id = p_group_id
        AND ps.parent_id = v_caller_id
        AND gm.status = 'active'
    ) THEN
      RAISE EXCEPTION 'NOT_AUTHORIZED';
    END IF;
  END IF;

  SELECT jsonb_build_object(
    'content_group_id',             cg.id,
    'content_id',                   cg.content_id,
    'group_id',                     cg.group_id,
    'sort_order',                   cg.sort_order,
    'passing_score_override',       cg.passing_score_override,
    'pdf_file_id',                  cg.file_id,
    'pdf_file_name',                f.file_name,
    'pdf_storage_path',             f.storage_path,
    'lesson_exam_id',               cg.associated_exam_id,
    'lesson_exam_title',            e.title,
    'lesson_exam_passing_score',    COALESCE(cg.passing_score_override, e.passing_score, g.default_passing_score, 60),
    'group_default_passing_score',  g.default_passing_score,
    'enforce_sequential',           g.enforce_sequential_learning,
    'is_manually_unlocked', CASE
      WHEN v_caller_role = 'student' THEN EXISTS (
        SELECT 1 FROM public.manual_lesson_unlocks mlu
        WHERE mlu.student_id = v_caller_id
          AND mlu.content_id = p_content_id
          AND mlu.group_id = p_group_id
      )
      ELSE false
    END,
    'attached_exams', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'exam_id', le.exam_id,
          'title', ex.title,
          'is_required', le.is_required,
          'sort_order', le.sort_order,
          'passing_score', COALESCE(ex.passing_score, g.default_passing_score, 60),
          'total_questions', COALESCE(
            (SELECT count(*) FROM public.exam_questions eq WHERE eq.exam_id = ex.id),
            (SELECT count(*) FROM public.questions q WHERE q.exam_version_id = ex.active_version_id),
            0
          ),
          'is_passed', CASE
            WHEN v_caller_role = 'student' THEN EXISTS (
              SELECT 1 FROM public.exam_attempts ea
              WHERE ea.exam_id = le.exam_id
                AND ea.student_id = v_caller_id
                AND ea.is_submitted = true
                AND (ea.score * 100.0 / NULLIF(COALESCE(ex.max_score, 100), 0)) >= COALESCE(ex.passing_score, g.default_passing_score, 60)
            )
            ELSE false
          END,
          'score', CASE
            WHEN v_caller_role = 'student' THEN (
              SELECT (ea.score * 100.0 / NULLIF(COALESCE(ex.max_score, 100), 0))::int
              FROM public.exam_attempts ea
              WHERE ea.exam_id = le.exam_id
                AND ea.student_id = v_caller_id
                AND ea.is_submitted = true
              ORDER BY ea.created_at DESC
              LIMIT 1
            )
            ELSE NULL
          END
        ) ORDER BY le.sort_order ASC, le.created_at ASC
      )
      FROM public.lesson_exams le
      JOIN public.exams ex ON ex.id = le.exam_id
      WHERE le.group_id = p_group_id AND le.content_id = p_content_id
    ), '[]'::jsonb)
  ) INTO v_result
  FROM public.content_groups cg
  JOIN public.groups g ON g.id = cg.group_id
  LEFT JOIN public.files f ON f.id = cg.file_id
  LEFT JOIN public.exams e ON e.id = cg.associated_exam_id
  WHERE cg.group_id = p_group_id
    AND cg.content_id = p_content_id
  LIMIT 1;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_lesson_context(uuid, uuid) TO authenticated;

