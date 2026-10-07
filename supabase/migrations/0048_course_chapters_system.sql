-- Migration 0048: Course Chapters System & Folder Assignment
-- ==============================================================================
-- 1. Table public.chapters
-- Organizes lessons inside a course/group into sequential academic chapters.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.chapters (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  group_id uuid NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  sort_order int NOT NULL DEFAULT 0,
  source_folder_id uuid REFERENCES public.video_folders(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chapters_group_sort ON public.chapters(group_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_chapters_tenant ON public.chapters(tenant_id);
CREATE INDEX IF NOT EXISTS idx_chapters_source_folder ON public.chapters(source_folder_id);

ALTER TABLE public.chapters ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS chapters_teacher_all ON public.chapters;
CREATE POLICY chapters_teacher_all ON public.chapters
  FOR ALL TO authenticated
  USING (public.has_role('teacher') AND public.tenant_is_active() AND tenant_id = public.my_tenant_id())
  WITH CHECK (public.has_role('teacher') AND public.tenant_is_active() AND tenant_id = public.my_tenant_id());

DROP POLICY IF EXISTS chapters_student_read ON public.chapters;
CREATE POLICY chapters_student_read ON public.chapters
  FOR SELECT TO authenticated
  USING (
    public.has_role('student')
    AND public.tenant_is_active()
    AND tenant_id = public.my_tenant_id()
    AND EXISTS (
      SELECT 1 FROM public.group_members gm
      WHERE gm.group_id = chapters.group_id
        AND gm.student_id = auth.uid()
        AND gm.status = 'active'
    )
  );

DROP POLICY IF EXISTS chapters_parent_read ON public.chapters;
CREATE POLICY chapters_parent_read ON public.chapters
  FOR SELECT TO authenticated
  USING (
    public.has_role('parent')
    AND public.tenant_is_active()
    AND tenant_id = public.my_tenant_id()
    AND EXISTS (
      SELECT 1 FROM public.parent_students ps
      JOIN public.group_members gm ON gm.student_id = ps.student_id
      WHERE ps.parent_id = auth.uid()
        AND gm.group_id = chapters.group_id
        AND gm.status = 'active'
    )
  );

-- ==============================================================================
-- 2. Add chapter_id to public.content_groups
-- ==============================================================================
ALTER TABLE public.content_groups
  ADD COLUMN IF NOT EXISTS chapter_id uuid REFERENCES public.chapters(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_content_groups_chapter ON public.content_groups(chapter_id);

-- ==============================================================================
-- 3. Atomic RPC: assign_folder_as_chapter_to_group
-- Converts an entire Video Bank folder into a course chapter with all its ready videos.
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.assign_folder_as_chapter_to_group(
  p_folder_id uuid,
  p_group_id uuid,
  p_chapter_title text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_caller_role text;
  v_tenant_id uuid;
  v_folder_name text;
  v_chapter_title text;
  v_chapter_id uuid;
  v_chapter_order int;
  v_video_row record;
  v_content_id uuid;
  v_current_lesson_order int := 0;
  v_added_count int := 0;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT role, tenant_id INTO v_caller_role, v_tenant_id
  FROM public.users
  WHERE id = v_caller_id AND status IN ('active', 'pending');

  IF v_caller_role != 'teacher' OR v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  SELECT name INTO v_folder_name
  FROM public.video_folders
  WHERE id = p_folder_id AND tenant_id = v_tenant_id;

  IF v_folder_name IS NULL THEN
    RAISE EXCEPTION 'FOLDER_NOT_FOUND';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.groups
    WHERE id = p_group_id AND tenant_id = v_tenant_id
  ) THEN
    RAISE EXCEPTION 'GROUP_NOT_FOUND';
  END IF;

  v_chapter_title := COALESCE(NULLIF(TRIM(p_chapter_title), ''), v_folder_name);

  SELECT COALESCE(MAX(sort_order), -1) + 1 INTO v_chapter_order
  FROM public.chapters
  WHERE group_id = p_group_id;

  INSERT INTO public.chapters (
    tenant_id,
    group_id,
    title,
    sort_order,
    source_folder_id
  ) VALUES (
    v_tenant_id,
    p_group_id,
    v_chapter_title,
    v_chapter_order,
    p_folder_id
  ) RETURNING id INTO v_chapter_id;

  SELECT COALESCE(MAX(sort_order), -1) + 1 INTO v_current_lesson_order
  FROM public.content_groups
  WHERE group_id = p_group_id;

  FOR v_video_row IN (
    SELECT id, title, description, provider, provider_video_id, thumbnail_url, duration
    FROM public.video_library
    WHERE folder_id = p_folder_id 
      AND tenant_id = v_tenant_id
      AND status = 'ready'
    ORDER BY created_at ASC
  ) LOOP
    SELECT c.id INTO v_content_id
    FROM public.content c
    JOIN public.videos v ON v.content_id = c.id
    WHERE v.library_video_id = v_video_row.id
      AND c.tenant_id = v_tenant_id
    LIMIT 1;

    IF v_content_id IS NULL THEN
      INSERT INTO public.content (
        tenant_id,
        group_id,
        title,
        description,
        type,
        status,
        sort_order
      ) VALUES (
        v_tenant_id,
        p_group_id,
        v_video_row.title,
        v_video_row.description,
        'video',
        'published',
        v_current_lesson_order
      ) RETURNING id INTO v_content_id;

      INSERT INTO public.videos (
        content_id,
        library_video_id,
        provider,
        provider_video_id,
        thumbnail_url,
        duration,
        status
      ) VALUES (
        v_content_id,
        v_video_row.id,
        COALESCE(v_video_row.provider, 'bunny'),
        v_video_row.provider_video_id,
        v_video_row.thumbnail_url,
        v_video_row.duration,
        'ready'
      );
    END IF;

    INSERT INTO public.content_groups (
      tenant_id,
      content_id,
      group_id,
      chapter_id,
      sort_order,
      is_published
    ) VALUES (
      v_tenant_id,
      v_content_id,
      p_group_id,
      v_chapter_id,
      v_current_lesson_order,
      true
    )
    ON CONFLICT (content_id, group_id) DO UPDATE SET
      chapter_id = EXCLUDED.chapter_id,
      sort_order = EXCLUDED.sort_order,
      is_published = true;

    v_current_lesson_order := v_current_lesson_order + 1;
    v_added_count := v_added_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'chapter_id', v_chapter_id,
    'chapter_title', v_chapter_title,
    'lessons_count', v_added_count
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.assign_folder_as_chapter_to_group(uuid, uuid, text) TO authenticated;

-- ==============================================================================
-- 4. Helper RPCs for Chapter Management in Course Builder
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.create_chapter(
  p_group_id uuid,
  p_title text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_tenant_id uuid;
  v_next_order int;
  v_new_chapter_id uuid;
BEGIN
  SELECT tenant_id INTO v_tenant_id
  FROM public.users
  WHERE id = v_caller_id AND role = 'teacher' AND status = 'active';

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  SELECT COALESCE(MAX(sort_order), -1) + 1 INTO v_next_order
  FROM public.chapters
  WHERE group_id = p_group_id;

  INSERT INTO public.chapters (
    tenant_id,
    group_id,
    title,
    sort_order
  ) VALUES (
    v_tenant_id,
    p_group_id,
    TRIM(p_title),
    v_next_order
  ) RETURNING id INTO v_new_chapter_id;

  RETURN jsonb_build_object(
    'id', v_new_chapter_id,
    'title', TRIM(p_title),
    'sort_order', v_next_order
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_chapter(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.update_chapter(
  p_chapter_id uuid,
  p_title text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_tenant_id uuid;
BEGIN
  SELECT tenant_id INTO v_tenant_id
  FROM public.users
  WHERE id = v_caller_id AND role = 'teacher' AND status = 'active';

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  UPDATE public.chapters
  SET title = TRIM(p_title), updated_at = now()
  WHERE id = p_chapter_id AND tenant_id = v_tenant_id;

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_chapter(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.delete_chapter(
  p_chapter_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_tenant_id uuid;
BEGIN
  SELECT tenant_id INTO v_tenant_id
  FROM public.users
  WHERE id = v_caller_id AND role = 'teacher' AND status = 'active';

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  -- Remove chapter linkage from lessons
  UPDATE public.content_groups
  SET chapter_id = NULL
  WHERE chapter_id = p_chapter_id AND tenant_id = v_tenant_id;

  -- Delete chapter
  DELETE FROM public.chapters
  WHERE id = p_chapter_id AND tenant_id = v_tenant_id;

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_chapter(uuid) TO authenticated;

-- ==============================================================================
-- 5. Updated get_group_course_progress RPC with Chapter Data
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
      ) AS is_manually_unlocked
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

    v_lessons_arr := v_lessons_arr || jsonb_build_object(
      'content_group_id',               v_lesson_row.content_group_id,
      'content_id',                     v_lesson_row.content_id,
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
      'exam_passed',                    v_lesson_row.exam_passed
    );
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
    'lessons',                    v_lessons_arr
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_group_course_progress(uuid, uuid) TO authenticated;
