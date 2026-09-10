-- ============================================================================
-- 0002_performance_rpcs.sql — Performance Optimization: RPC Functions
-- المشكلة: N+1 queries في getStudent360 (6 رحلات HTTP) وN UPDATE في reorderContentItems
-- الحل: تحويل العمليات المتعددة إلى استدعاء RPC واحد
-- ============================================================================

-- ---------- 1) get_student_360 — يحل مشكلة 6 استعلامات متتالية ----------
-- يُستدعى من: StudentsRemoteDataSource.getStudent360()
-- الأمان: SECURITY DEFINER — يُطبّق RLS policy الخاصة بـ caller تلقائياً
-- الإدخال: p_student_id (UUID الطالب المطلوب)
-- الإخراج: JSON object بكل البيانات الإحصائية في رحلة واحدة

CREATE OR REPLACE FUNCTION public.get_student_360(p_student_id UUID)
RETURNS JSON
LANGUAGE plpgsql
STABLE  -- يخبر PostgreSQL أن الدالة لا تعدّل البيانات (تحسين Planner)
SECURITY INVOKER  -- يطبّق RLS بناءً على المستدعي (أكثر أماناً من DEFINER هنا)
AS $$
DECLARE
  v_result JSON;
BEGIN
  SELECT json_build_object(
    -- 1. بيانات المجموعات (مع اسم وmستوى كل مجموعة)
    'groups', (
      SELECT COALESCE(
        json_agg(
          json_build_object(
            'group_id', gm.group_id,
            'joined_at', gm.joined_at,
            'groups', json_build_object(
              'name', g.name,
              'level', g.level
            )
          )
        ),
        '[]'::json
      )
      FROM public.group_members gm
      JOIN public.groups g ON g.id = gm.group_id
      WHERE gm.student_id = p_student_id
        AND gm.status = 'active'
    ),

    -- 2. آخر نشاط للطالب
    'last_activity_at', (
      SELECT last_activity_at
      FROM public.users
      WHERE id = p_student_id
    ),

    -- 3. إحصائيات الحضور
    'attendance_total', (
      SELECT COUNT(*)
      FROM public.attendance
      WHERE student_id = p_student_id
    ),
    'attendance_present', (
      SELECT COUNT(*)
      FROM public.attendance
      WHERE student_id = p_student_id AND status = 'present'
    ),

    -- 4. إحصائيات الواجبات
    'submissions_total', (
      SELECT COUNT(*)
      FROM public.assignment_submissions
      WHERE student_id = p_student_id
    ),
    'submissions_reviewed', (
      SELECT COUNT(*)
      FROM public.assignment_submissions
      WHERE student_id = p_student_id AND status = 'reviewed'
    ),

    -- 5. متوسط درجات الامتحانات
    'exam_avg_percentage', (
      SELECT COALESCE(AVG(percentage), 0)
      FROM public.exam_attempts
      WHERE student_id = p_student_id AND status = 'submitted'
    ),

    -- 6. متوسط نسبة مشاهدة الفيديو
    'video_avg_percentage', (
      SELECT COALESCE(AVG(percentage), 0)
      FROM public.video_progress
      WHERE student_id = p_student_id
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- Grant للـ authenticated users (RLS مطبق عبر SECURITY INVOKER)
GRANT EXECUTE ON FUNCTION public.get_student_360(UUID) TO authenticated;

-- ---------- 2) reorder_content_items — يحل مشكلة N UPDATE في loop ----------
-- يُستدعى من: ContentRemoteDataSource.reorderContentItems()
-- الإدخال: مصفوفة UUID بالترتيب الجديد
-- الإخراج: لا شيء (void)

CREATE OR REPLACE FUNCTION public.reorder_content_items(
  p_ids UUID[]
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_now TIMESTAMPTZ := NOW();
BEGIN
  -- UPDATE batch في transaction واحدة بدلاً من N رحلات HTTP
  FOR i IN 1..array_length(p_ids, 1) LOOP
    UPDATE public.content
    SET
      sort_order = i - 1,
      updated_at = v_now
    WHERE id = p_ids[i];
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.reorder_content_items(UUID[]) TO authenticated;

-- ---------- 3) إضافة index مساعد لتحسين استعلامات get_student_360 ----------
-- هذه الفهارس ستسرّع الاستعلامات الفرعية داخل الـ RPC

-- فهرس على attendance(student_id, status) — يسرّع حساب الحضور
CREATE INDEX IF NOT EXISTS idx_attendance_student_status
  ON public.attendance(student_id, status);

-- فهرس على assignment_submissions(student_id, status) — يسرّع حساب الواجبات
CREATE INDEX IF NOT EXISTS idx_submissions_student_status
  ON public.assignment_submissions(student_id, status);

-- فهرس على exam_attempts(student_id, status) — يسرّع حساب الامتحانات
CREATE INDEX IF NOT EXISTS idx_exam_attempts_student_status
  ON public.exam_attempts(student_id, status);

-- فهرس على video_progress(student_id) — يسرّع حساب الفيديو
CREATE INDEX IF NOT EXISTS idx_video_progress_student
  ON public.video_progress(student_id);

-- فهرس على group_members(student_id, status) — يسرّع عضوية الطالب
CREATE INDEX IF NOT EXISTS idx_group_members_student_status
  ON public.group_members(student_id, status);
