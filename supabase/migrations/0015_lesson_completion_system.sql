-- ============================================================================
-- Migration: 0015_lesson_completion_system.sql
-- Description:
-- 1. furthest_position_seconds في video_progress (أبعد نقطة مشاهدة حقيقية)
-- 2. passing_score_override في content_groups (passing score مخصص لكل مجموعة)
-- 3. default_passing_score في groups (قيمة افتراضية للمجموعة)
-- 4. جدول manual_lesson_unlocks + RLS (فتح يدوي بدون تعديل أي درجة)
-- 5. RPC: get_lesson_context (بيانات الدرس الخاصة بالمجموعة)
-- 6. RPC: manual_unlock_lesson (SECURITY DEFINER - المعلم فقط)
-- 7. RPC: get_group_course_progress (حالة الطالب الكاملة لدروس المجموعة)
-- ============================================================================

-- ============================================================
-- 1. furthest_position_seconds في video_progress
-- ============================================================
ALTER TABLE public.video_progress
  ADD COLUMN IF NOT EXISTS furthest_position_seconds int NOT NULL DEFAULT 0;

-- تهيئة القيم الموجودة من progress_seconds
UPDATE public.video_progress
SET furthest_position_seconds = GREATEST(
  progress_seconds,
  CASE WHEN duration_seconds > 0 THEN
    (duration_seconds * percentage / 100.0)::int
  ELSE 0 END
)
WHERE furthest_position_seconds = 0 AND (progress_seconds > 0 OR percentage > 0);

-- ============================================================
-- 2. passing_score_override في content_groups
-- ============================================================
ALTER TABLE public.content_groups
  ADD COLUMN IF NOT EXISTS passing_score_override int
  CHECK (passing_score_override IS NULL OR (passing_score_override >= 1 AND passing_score_override <= 100));

-- ============================================================
-- 3. default_passing_score في groups
-- ============================================================
ALTER TABLE public.groups
  ADD COLUMN IF NOT EXISTS default_passing_score int NOT NULL DEFAULT 60
  CHECK (default_passing_score >= 1 AND default_passing_score <= 100);

-- ============================================================
-- 4. جدول manual_lesson_unlocks
-- ============================================================
CREATE TABLE IF NOT EXISTS public.manual_lesson_unlocks (
  id           uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid         NOT NULL REFERENCES public.tenants(id)  ON DELETE CASCADE,
  student_id   uuid         NOT NULL REFERENCES public.users(id)    ON DELETE CASCADE,
  content_id   uuid         NOT NULL REFERENCES public.content(id)  ON DELETE CASCADE,
  group_id     uuid         NOT NULL REFERENCES public.groups(id)   ON DELETE CASCADE,
  unlocked_by  uuid         NOT NULL REFERENCES public.users(id),
  reason       text,
  created_at   timestamptz  NOT NULL DEFAULT now(),
  CONSTRAINT manual_lesson_unlocks_unique UNIQUE (student_id, content_id, group_id)
);

CREATE INDEX IF NOT EXISTS idx_manual_unlocks_student
  ON public.manual_lesson_unlocks(student_id, group_id);
CREATE INDEX IF NOT EXISTS idx_manual_unlocks_tenant
  ON public.manual_lesson_unlocks(tenant_id);
CREATE INDEX IF NOT EXISTS idx_manual_unlocks_content
  ON public.manual_lesson_unlocks(content_id);

ALTER TABLE public.manual_lesson_unlocks ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'manual_lesson_unlocks' AND policyname = 'mlu_teacher_all'
  ) THEN
    CREATE POLICY mlu_teacher_all ON public.manual_lesson_unlocks
      FOR ALL TO authenticated
      USING (
        public.has_role('teacher')
        AND public.tenant_is_active()
        AND tenant_id = public.my_tenant_id()
      )
      WITH CHECK (
        public.has_role('teacher')
        AND public.tenant_is_active()
        AND tenant_id = public.my_tenant_id()
      );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'manual_lesson_unlocks' AND policyname = 'mlu_student_read'
  ) THEN
    CREATE POLICY mlu_student_read ON public.manual_lesson_unlocks
      FOR SELECT TO authenticated
      USING (
        public.has_role('student')
        AND public.tenant_is_active()
        AND student_id = auth.uid()
      );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'manual_lesson_unlocks' AND policyname = 'mlu_parent_read'
  ) THEN
    CREATE POLICY mlu_parent_read ON public.manual_lesson_unlocks
      FOR SELECT TO authenticated
      USING (
        public.has_role('parent')
        AND public.tenant_is_active()
        AND EXISTS (
          SELECT 1 FROM public.parent_students ps
          WHERE ps.parent_id = auth.uid()
            AND ps.student_id = manual_lesson_unlocks.student_id
        )
      );
  END IF;
END $$;

-- ============================================================
-- 5. RPC: get_lesson_context
-- ============================================================
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

  -- التحقق من صلاحية الوصول
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
    'manual_unlock_reason', CASE
      WHEN v_caller_role = 'student' THEN (
        SELECT mlu.reason FROM public.manual_lesson_unlocks mlu
        WHERE mlu.student_id = v_caller_id
          AND mlu.content_id = p_content_id
          AND mlu.group_id = p_group_id
        LIMIT 1
      )
      ELSE null
    END
  ) INTO v_result
  FROM public.content_groups cg
  LEFT JOIN public.files f   ON f.id = cg.file_id
  LEFT JOIN public.exams e   ON e.id = cg.associated_exam_id
  LEFT JOIN public.groups g  ON g.id = cg.group_id
  WHERE cg.content_id = p_content_id
    AND cg.group_id = p_group_id;

  IF v_result IS NULL THEN
    -- الدرس غير معيَّن لهذه المجموعة — أعد بيانات فارغة آمنة
    RETURN jsonb_build_object(
      'content_id', p_content_id,
      'group_id', p_group_id,
      'pdf_file_id', null,
      'lesson_exam_id', null,
      'is_manually_unlocked', false
    );
  END IF;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_lesson_context(uuid, uuid) TO authenticated;

-- ============================================================
-- 6. RPC: manual_unlock_lesson
-- ============================================================
CREATE OR REPLACE FUNCTION public.manual_unlock_lesson(
  p_student_id uuid,
  p_content_id uuid,
  p_group_id   uuid,
  p_reason     text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_teacher_id     uuid := auth.uid();
  v_teacher_tenant uuid;
  v_student_tenant uuid;
BEGIN
  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT tenant_id INTO v_teacher_tenant
  FROM public.users
  WHERE id = v_teacher_id AND role = 'teacher' AND status = 'active';

  IF v_teacher_tenant IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  SELECT tenant_id INTO v_student_tenant
  FROM public.users
  WHERE id = p_student_id AND role = 'student';

  IF v_student_tenant IS NULL OR v_student_tenant != v_teacher_tenant THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.groups
    WHERE id = p_group_id AND tenant_id = v_teacher_tenant
  ) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = p_group_id AND student_id = p_student_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'STUDENT_NOT_IN_GROUP';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.content_groups
    WHERE content_id = p_content_id AND group_id = p_group_id
  ) THEN
    RAISE EXCEPTION 'LESSON_NOT_IN_GROUP';
  END IF;

  INSERT INTO public.manual_lesson_unlocks (
    tenant_id, student_id, content_id, group_id, unlocked_by, reason
  ) VALUES (
    v_teacher_tenant, p_student_id, p_content_id, p_group_id, v_teacher_id,
    NULLIF(TRIM(COALESCE(p_reason, '')), '')
  )
  ON CONFLICT (student_id, content_id, group_id)
  DO UPDATE SET
    unlocked_by = v_teacher_id,
    reason      = NULLIF(TRIM(COALESCE(p_reason, '')), ''),
    created_at  = now();

  -- Audit log (best-effort)
  BEGIN
    INSERT INTO public.activity_events (
      tenant_id, user_id, event_type, content_id, group_id, metadata
    ) VALUES (
      v_teacher_tenant, v_teacher_id, 'manual_lesson_unlock',
      p_content_id, p_group_id,
      jsonb_build_object(
        'student_id', p_student_id,
        'reason', p_reason,
        'unlocked_by', v_teacher_id
      )
    );
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  RETURN jsonb_build_object(
    'status', 'unlocked',
    'student_id', p_student_id,
    'content_id', p_content_id,
    'group_id', p_group_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.manual_unlock_lesson(uuid, uuid, uuid, text) TO authenticated;

-- ============================================================
-- 7. RPC: get_group_course_progress
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_group_course_progress(
  p_group_id   uuid,
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
  v_result         jsonb;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT tenant_id, role INTO v_caller_tenant, v_caller_role
  FROM public.users
  WHERE id = v_caller_id AND status = 'active';

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
    v_target_student := p_student_id; -- قد يكون NULL
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
  ELSE
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  SELECT jsonb_agg(lesson_row ORDER BY (lesson_row->>'sort_order')::int ASC)
  INTO v_result
  FROM (
    SELECT jsonb_build_object(
      'content_group_id',              cg.id,
      'content_id',                    c.id,
      'title',                         c.title,
      'description',                   c.description,
      'sort_order',                    cg.sort_order,
      'content_type',                  c.type,
      -- PDF الخاص بالمجموعة
      'pdf_file_id',                   cg.file_id,
      'pdf_file_name',                 f.file_name,
      'pdf_storage_path',              f.storage_path,
      -- الاختبار
      'lesson_exam_id',                cg.associated_exam_id,
      'lesson_exam_title',             e.title,
      'lesson_exam_passing_score',     COALESCE(cg.passing_score_override, e.passing_score, g.default_passing_score, 60),
      'prerequisite_exam_id',          cg.prerequisite_exam_id,
      -- تقدم الطالب
      'video_progress_seconds',        vp.progress_seconds,
      'video_furthest_seconds',        vp.furthest_position_seconds,
      'video_duration_seconds',        vp.duration_seconds,
      'video_percentage',              vp.percentage,
      'video_completed',               COALESCE(vp.completed, false),
      -- نتيجة الاختبار
      'exam_best_score', CASE WHEN v_target_student IS NOT NULL THEN (
        SELECT MAX(ea.score)
        FROM public.exam_attempts ea
        WHERE ea.exam_id = cg.associated_exam_id
          AND ea.student_id = v_target_student
          AND ea.status = 'completed'
      ) ELSE null END,
      'exam_passed', CASE WHEN v_target_student IS NOT NULL THEN (
        SELECT EXISTS (
          SELECT 1 FROM public.exam_attempts ea
          WHERE ea.exam_id = cg.associated_exam_id
            AND ea.student_id = v_target_student
            AND ea.status = 'completed'
            AND ea.score >= COALESCE(cg.passing_score_override, e.passing_score, g.default_passing_score, 60)
        )
      ) ELSE false END,
      -- فتح يدوي
      'is_manually_unlocked', CASE WHEN v_target_student IS NOT NULL THEN (
        SELECT EXISTS (
          SELECT 1 FROM public.manual_lesson_unlocks mlu
          WHERE mlu.student_id = v_target_student
            AND mlu.content_id = c.id
            AND mlu.group_id = p_group_id
        )
      ) ELSE false END
    ) AS lesson_row
    FROM public.content_groups cg
    JOIN public.content c ON c.id = cg.content_id AND c.status = 'published'
    LEFT JOIN public.files f   ON f.id = cg.file_id
    LEFT JOIN public.exams e   ON e.id = cg.associated_exam_id
    LEFT JOIN public.groups g  ON g.id = p_group_id
    LEFT JOIN public.video_progress vp ON (
      v_target_student IS NOT NULL
      AND vp.student_id = v_target_student
      AND EXISTS (
        SELECT 1 FROM public.videos vid
        WHERE vid.content_id = c.id AND vid.id = vp.video_id
      )
    )
    WHERE cg.group_id = p_group_id
      AND cg.tenant_id = v_caller_tenant
  ) sub;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_group_course_progress(uuid, uuid) TO authenticated;
