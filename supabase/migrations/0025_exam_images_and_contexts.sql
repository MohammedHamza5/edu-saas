-- ============================================================================
-- 0025_exam_images_and_contexts.sql
-- Add image support (Cloudflare R2/storage) and shared contexts to exam questions
-- ============================================================================

-- 1. Create exam_contexts table for shared passages/diagrams
CREATE TABLE IF NOT EXISTS public.exam_contexts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exam_version_id UUID NOT NULL REFERENCES public.exam_versions(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES public.tenants(id),
    title TEXT,
    context_text TEXT,
    image_url TEXT,
    image_meta JSONB NOT NULL DEFAULT '{"alignment": "center", "width_percent": 80, "enable_zoom": true}'::jsonb,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS on exam_contexts
ALTER TABLE public.exam_contexts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "exam_contexts_teacher_manage" ON public.exam_contexts
    FOR ALL USING (
        public.has_role('teacher') AND tenant_id = public.my_tenant_id()
    ) WITH CHECK (
        public.has_role('teacher') AND tenant_id = public.my_tenant_id()
    );

CREATE POLICY "exam_contexts_student_read" ON public.exam_contexts
    FOR SELECT USING (
        public.has_role('student') AND EXISTS (
            SELECT 1 FROM public.exam_versions ev
            JOIN public.exams e ON e.id = ev.exam_id
            JOIN public.content c ON c.id = e.content_id
            JOIN public.group_members gm ON gm.group_id = c.group_id
            WHERE ev.id = exam_contexts.exam_version_id
              AND ev.status = 'published'
              AND gm.student_id = auth.uid()
              AND gm.status = 'active'
        )
    );

-- 2. Add columns to exam_questions
ALTER TABLE public.exam_questions 
    ADD COLUMN IF NOT EXISTS image_url TEXT NULL,
    ADD COLUMN IF NOT EXISTS image_meta JSONB NULL DEFAULT '{"alignment": "center", "width_percent": 75, "enable_zoom": true}'::jsonb,
    ADD COLUMN IF NOT EXISTS context_id UUID NULL REFERENCES public.exam_contexts(id) ON DELETE SET NULL;

-- 3. Add columns to question_options
ALTER TABLE public.question_options
    ADD COLUMN IF NOT EXISTS image_url TEXT NULL,
    ADD COLUMN IF NOT EXISTS image_meta JSONB NULL DEFAULT '{"alignment": "center", "width_percent": 100}'::jsonb;

-- 4. Create Indexes
CREATE INDEX IF NOT EXISTS idx_exam_questions_context ON public.exam_questions(context_id);
CREATE INDEX IF NOT EXISTS idx_exam_contexts_version ON public.exam_contexts(exam_version_id);
CREATE INDEX IF NOT EXISTS idx_exam_contexts_tenant ON public.exam_contexts(tenant_id);

-- 5. Update start_exam RPC to return images and display metadata safely
CREATE OR REPLACE FUNCTION public.start_exam(p_exam_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id uuid := auth.uid();
  v_tenant_id uuid;
  v_exam record;
  v_version record;
  v_active_attempt record;
  v_attempt_id uuid;
  v_questions jsonb;
  v_contexts jsonb;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be authenticated';
  END IF;

  -- استخراج tenant_id للطالب والتحقق من نشاط حسابه
  SELECT tenant_id INTO v_tenant_id FROM public.users WHERE id = v_student_id AND status = 'active';
  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Active student profile required';
  END IF;

  -- فحص بيانات الامتحان والمحتوى التابع له
  SELECT e.*, c.group_id, c.status AS content_status INTO v_exam
  FROM public.exams e
  JOIN public.content c ON c.id = e.content_id
  WHERE e.id = p_exam_id AND e.tenant_id = v_tenant_id;

  IF v_exam.id IS NULL THEN
    RAISE EXCEPTION 'EXAM_NOT_FOUND: Exam does not exist';
  END IF;

  IF v_exam.content_status != 'published' THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Exam is not published';
  END IF;

  -- فحص نافذة الوقت (start_at / end_at) إن وُجدت
  IF v_exam.start_at IS NOT NULL AND now() < v_exam.start_at THEN
    RAISE EXCEPTION 'EXAM_NOT_STARTED: Exam start time is in the future';
  END IF;

  IF v_exam.end_at IS NOT NULL AND now() > v_exam.end_at THEN
    RAISE EXCEPTION 'EXAM_EXPIRED: Exam window has passed';
  END IF;

  -- فحص عضوية الطالب في المجموعة وسياسة المحتوى السابق
  IF NOT EXISTS (
    SELECT 1 FROM public.group_members gm
    WHERE gm.student_id = v_student_id
      AND gm.group_id = v_exam.group_id
      AND gm.status = 'active'
  ) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Student is not an active member of this group';
  END IF;

  -- فحص إذا كانت هناك محاولة قيد التنفيذ بالفعل (استئناف آمن)
  SELECT * INTO v_active_attempt
  FROM public.exam_attempts
  WHERE exam_id = p_exam_id AND student_id = v_student_id AND status = 'in_progress';

  IF v_active_attempt.id IS NOT NULL THEN
    -- فحص انتهاء الوقت للمحاولة الحالية
    IF (v_active_attempt.started_at + (v_exam.duration_minutes || ' minutes')::interval) < now() THEN
      UPDATE public.exam_attempts
      SET status = 'expired'
      WHERE id = v_active_attempt.id;
    ELSE
      -- المحاولة لا تزال نشطة وصالحة: إرجاع نفس المحاولة والأسئلة لاستئنافها
      v_attempt_id := v_active_attempt.id;
      SELECT * INTO v_version FROM public.exam_versions WHERE id = v_active_attempt.exam_version_id;
    END IF;
  END IF;

  -- إذا لم تكن هناك محاولة نشطة صالحة: نتحقق من قيود إعادة المحاولة وننشئ محاولة جديدة
  IF v_attempt_id IS NULL THEN
    -- فحص إن كان الطالب قد سلّم محاولات سابقة ولا يُسمح بالإعادة
    IF NOT v_exam.allow_retake AND EXISTS (
      SELECT 1 FROM public.exam_attempts
      WHERE exam_id = p_exam_id AND student_id = v_student_id AND status IN ('submitted', 'expired')
    ) THEN
      RAISE EXCEPTION 'ATTEMPTS_LIMIT_REACHED: Retake is not allowed for this exam';
    END IF;

    -- جلب النسخة المنشورة الحديثة المجمدة (Snapshot)
    SELECT * INTO v_version
    FROM public.exam_versions
    WHERE exam_id = p_exam_id AND status = 'published'
    ORDER BY version_number DESC
    LIMIT 1;

    IF v_version.id IS NULL THEN
      RAISE EXCEPTION 'EXAM_NOT_FOUND: No published version available for this exam';
    END IF;

    -- إنشاء المحاولة بـ started_at خادمي حصرياً
    INSERT INTO public.exam_attempts (
      exam_id,
      exam_version_id,
      student_id,
      started_at,
      status
    ) VALUES (
      p_exam_id,
      v_version.id,
      v_student_id,
      now(),
      'in_progress'
    ) RETURNING id INTO v_attempt_id;

    -- تسجيل نشاط exam_started
    INSERT INTO public.activity_events (
      tenant_id,
      user_id,
      group_id,
      content_id,
      event_type,
      metadata
    ) VALUES (
      v_tenant_id,
      v_student_id,
      v_exam.group_id,
      v_exam.content_id,
      'exam_started',
      jsonb_build_object('attempt_id', v_attempt_id, 'version_id', v_version.id)
    );
  END IF;

  -- بناء قائمة السياقات المشتركة التابعة لهذه النسخة
  SELECT COALESCE(jsonb_agg(ctx_item), '[]'::jsonb) INTO v_contexts
  FROM (
    SELECT
      ec.id,
      ec.title,
      ec.context_text,
      ec.image_url,
      ec.image_meta,
      ec.sort_order
    FROM public.exam_contexts ec
    WHERE ec.exam_version_id = v_version.id
    ORDER BY ec.sort_order
  ) ctx_item;

  -- بناء قائمة الأسئلة والخيارات الآمنة مع روابط الصور وميتاداتا العرض
  SELECT COALESCE(jsonb_agg(q_item), '[]'::jsonb) INTO v_questions
  FROM (
    SELECT
      eq.id,
      eq.question_text,
      eq.question_type,
      eq.points,
      eq.sort_order,
      eq.image_url,
      eq.image_meta,
      eq.context_id,
      (
        SELECT COALESCE(jsonb_agg(
          jsonb_build_object(
            'id', qo.id,
            'option_text', qo.option_text,
            'sort_order', qo.sort_order,
            'image_url', qo.image_url,
            'image_meta', qo.image_meta
          ) ORDER BY qo.sort_order
        ), '[]'::jsonb)
        FROM public.question_options qo
        WHERE qo.question_id = eq.id
      ) AS options
    FROM public.exam_questions eq
    WHERE eq.exam_version_id = v_version.id
    ORDER BY CASE WHEN v_exam.shuffle_questions THEN random() ELSE eq.sort_order END
  ) q_item;

  RETURN jsonb_build_object(
    'attempt_id', v_attempt_id,
    'exam_version_id', v_version.id,
    'started_at', COALESCE(v_active_attempt.started_at, now()),
    'duration_minutes', v_exam.duration_minutes,
    'show_result', v_exam.show_result,
    'contexts', v_contexts,
    'questions', v_questions
  );
END;
$$;
