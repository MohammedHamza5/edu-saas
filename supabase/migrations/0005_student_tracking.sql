-- ============================================================================
-- 0005_student_tracking.sql — Smart Student Engagement & Activity Tracking
-- يتضمن:
-- 1. جدول student_daily_engagement لتتبع الجلسات والوقت النشط والخمول يومياً
-- 2. توسيع video_progress بحقول actual_watch_seconds و is_skipped لكشف التخطي السريع
-- 3. دالة RPC آمنة: record_student_heartbeat لتسجيل نبضات الحضور والتفاعل
-- 4. دالة RPC آمنة: record_activity_event لتسجيل أحداث Whitelist وتحديث last_activity_at
-- 5. تحديث دالة get_student_360 لتوفير التحليلات الشاملة والـ Timeline دفعة واحدة
-- ============================================================================

-- ---------- 1) جدول student_daily_engagement ----------

CREATE TABLE IF NOT EXISTS public.student_daily_engagement (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  student_id      UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  date            DATE NOT NULL DEFAULT current_date,
  active_seconds  INTEGER NOT NULL DEFAULT 0,
  idle_seconds    INTEGER NOT NULL DEFAULT 0,
  session_count   INTEGER NOT NULL DEFAULT 1,
  first_seen_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT student_daily_engagement_unique UNIQUE (student_id, date)
);

CREATE INDEX IF NOT EXISTS idx_student_daily_engagement_student_date 
  ON public.student_daily_engagement(student_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_student_daily_engagement_tenant 
  ON public.student_daily_engagement(tenant_id, date DESC);

ALTER TABLE public.student_daily_engagement ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'student_daily_engagement' AND policyname = 'sde_teacher_read'
  ) THEN
    CREATE POLICY sde_teacher_read ON public.student_daily_engagement FOR SELECT TO authenticated
      USING (public.has_role('teacher') AND public.tenant_is_active() AND tenant_id = public.my_tenant_id());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'student_daily_engagement' AND policyname = 'sde_student_read'
  ) THEN
    CREATE POLICY sde_student_read ON public.student_daily_engagement FOR SELECT TO authenticated
      USING (student_id = auth.uid() AND public.tenant_is_active());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'student_daily_engagement' AND policyname = 'sde_parent_read'
  ) THEN
    CREATE POLICY sde_parent_read ON public.student_daily_engagement FOR SELECT TO authenticated
      USING (public.has_role('parent') AND public.tenant_is_active() AND EXISTS (
        SELECT 1 FROM public.parent_students ps WHERE ps.parent_id = auth.uid() AND ps.student_id = student_daily_engagement.student_id
      ));
  END IF;
END $$;

-- ---------- 2) توسيع video_progress بحقول النزاهة ----------

ALTER TABLE public.video_progress 
  ADD COLUMN IF NOT EXISTS actual_watch_seconds INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_skipped BOOLEAN NOT NULL DEFAULT false;

-- ---------- 3) RPC: record_student_heartbeat ----------

CREATE OR REPLACE FUNCTION public.record_student_heartbeat(
  p_active_seconds INTEGER,
  p_idle_seconds INTEGER DEFAULT 0,
  p_current_route TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_tenant_id UUID;
  v_today DATE := current_date;
  v_rec RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT tenant_id INTO v_tenant_id
  FROM public.users
  WHERE id = v_user_id AND status = 'active';

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  -- 1. تحديث users.last_activity_at
  UPDATE public.users
  SET last_activity_at = now()
  WHERE id = v_user_id;

  -- 2. دمج/تحديث سجل الحضور اليومي
  INSERT INTO public.student_daily_engagement (
    tenant_id,
    student_id,
    date,
    active_seconds,
    idle_seconds,
    first_seen_at,
    last_seen_at
  ) VALUES (
    v_tenant_id,
    v_user_id,
    v_today,
    GREATEST(0, COALESCE(p_active_seconds, 0)),
    GREATEST(0, COALESCE(p_idle_seconds, 0)),
    now(),
    now()
  )
  ON CONFLICT (student_id, date)
  DO UPDATE SET
    active_seconds = public.student_daily_engagement.active_seconds + GREATEST(0, COALESCE(p_active_seconds, 0)),
    idle_seconds = public.student_daily_engagement.idle_seconds + GREATEST(0, COALESCE(p_idle_seconds, 0)),
    last_seen_at = now();

  SELECT active_seconds, idle_seconds, first_seen_at, last_seen_at
  INTO v_rec
  FROM public.student_daily_engagement
  WHERE student_id = v_user_id AND date = v_today;

  RETURN json_build_object(
    'status', 'ok',
    'date', v_today,
    'total_active_seconds', v_rec.active_seconds,
    'total_idle_seconds', v_rec.idle_seconds,
    'last_seen_at', v_rec.last_seen_at
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_student_heartbeat(INTEGER, INTEGER, TEXT) TO authenticated;

-- ---------- 4) RPC: record_activity_event ----------

CREATE OR REPLACE FUNCTION public.record_activity_event(
  p_event_type TEXT,
  p_content_id UUID DEFAULT NULL,
  p_group_id UUID DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_tenant_id UUID;
  v_event_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  IF p_event_type NOT IN (
    'login', 'content_opened', 'video_started', 'video_completed',
    'assignment_submitted', 'exam_started', 'exam_submitted'
  ) THEN
    RAISE EXCEPTION 'VALIDATION_ERROR: Invalid event_type %', p_event_type;
  END IF;

  SELECT tenant_id INTO v_tenant_id
  FROM public.users
  WHERE id = v_user_id AND status = 'active';

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  -- تحديث users.last_activity_at
  UPDATE public.users
  SET last_activity_at = now()
  WHERE id = v_user_id;

  INSERT INTO public.activity_events (
    tenant_id,
    user_id,
    group_id,
    content_id,
    event_type,
    metadata,
    created_at
  ) VALUES (
    v_tenant_id,
    v_user_id,
    p_group_id,
    p_content_id,
    p_event_type,
    COALESCE(p_metadata, '{}'::jsonb),
    now()
  ) RETURNING id INTO v_event_id;

  RETURN v_event_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_activity_event(TEXT, UUID, UUID, JSONB) TO authenticated;

-- ---------- 5) تحديث get_student_360 لجلب التحليلات الشاملة دفعة واحدة ----------

CREATE OR REPLACE FUNCTION public.get_student_360(p_student_id UUID)
RETURNS JSON
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_result JSON;
  v_today DATE := current_date;
BEGIN
  SELECT json_build_object(
    -- 1. المجموعات
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

    -- 5. متوسط الامتحانات
    'exam_avg_percentage', (
      SELECT COALESCE(AVG(percentage), 0)
      FROM public.exam_attempts
      WHERE student_id = p_student_id AND status = 'submitted'
    ),

    -- 6. متوسط مشاهدة الفيديو
    'video_avg_percentage', (
      SELECT COALESCE(AVG(percentage), 0)
      FROM public.video_progress
      WHERE student_id = p_student_id
    ),

    -- 7. إحصائيات الحضور والتفاعل الذكي اليوم (Smart Engagement)
    'today_active_seconds', (
      SELECT COALESCE(active_seconds, 0)
      FROM public.student_daily_engagement
      WHERE student_id = p_student_id AND date = v_today
    ),
    'today_idle_seconds', (
      SELECT COALESCE(idle_seconds, 0)
      FROM public.student_daily_engagement
      WHERE student_id = p_student_id AND date = v_today
    ),
    'first_seen_today', (
      SELECT first_seen_at
      FROM public.student_daily_engagement
      WHERE student_id = p_student_id AND date = v_today
    ),
    'last_seen_today', (
      SELECT last_seen_at
      FROM public.student_daily_engagement
      WHERE student_id = p_student_id AND date = v_today
    ),

    -- 8. إجمالي آخر 7 أيام
    'total_active_seconds_7d', (
      SELECT COALESCE(SUM(active_seconds), 0)
      FROM public.student_daily_engagement
      WHERE student_id = p_student_id AND date >= v_today - 7
    ),
    'total_idle_seconds_7d', (
      SELECT COALESCE(SUM(idle_seconds), 0)
      FROM public.student_daily_engagement
      WHERE student_id = p_student_id AND date >= v_today - 7
    ),

    -- 9. آخر الأحداث الزمنية (Activity Feed / Timeline - آخر 15 حدث)
    'recent_activities', (
      SELECT COALESCE(
        json_agg(
          json_build_object(
            'id', ae.id,
            'event_type', ae.event_type,
            'created_at', ae.created_at,
            'content_id', ae.content_id,
            'content_title', c.title,
            'group_name', g.name,
            'metadata', ae.metadata
          ) ORDER BY ae.created_at DESC
        ),
        '[]'::json
      )
      FROM (
        SELECT *
        FROM public.activity_events
        WHERE user_id = p_student_id
        ORDER BY created_at DESC
        LIMIT 15
      ) ae
      LEFT JOIN public.content c ON c.id = ae.content_id
      LEFT JOIN public.groups g ON g.id = ae.group_id
    ),

    -- 10. تفاصيل الفيديوهات ونزاهة المشاهدة (Video Insights)
    'video_insights', (
      SELECT COALESCE(
        json_agg(
          json_build_object(
            'video_id', vp.video_id,
            'video_title', COALESCE(c.title, 'فيديو تعليمي'),
            'duration_seconds', vp.duration_seconds,
            'progress_seconds', vp.progress_seconds,
            'actual_watch_seconds', vp.actual_watch_seconds,
            'percentage', vp.percentage,
            'completed', vp.completed,
            'is_skipped', vp.is_skipped,
            'last_watched_at', vp.last_watched_at
          ) ORDER BY vp.last_watched_at DESC
        ),
        '[]'::json
      )
      FROM public.video_progress vp
      LEFT JOIN public.videos v ON v.id = vp.video_id
      LEFT JOIN public.content c ON c.id = v.content_id
      WHERE vp.student_id = p_student_id
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_student_360(UUID) TO authenticated;
