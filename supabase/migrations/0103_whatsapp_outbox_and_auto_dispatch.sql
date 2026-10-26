-- Migration 0103: Automated Self-Hosted WhatsApp Gateway Architecture
-- Adds Transactional Outbox Queue, Multi-Device Session Storage, and Automatic Exam Result Enqueueing.

-- 1. Create WhatsApp Auth Sessions Table (Stateless Multi-Device Baileys State)
CREATE TABLE IF NOT EXISTS public.whatsapp_auth_sessions (
  id TEXT PRIMARY KEY,
  tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
  creds JSONB DEFAULT '{}'::jsonb,
  keys JSONB DEFAULT '{}'::jsonb,
  status TEXT NOT NULL DEFAULT 'disconnected' CHECK (status IN ('disconnected', 'qr_ready', 'connecting', 'connected')),
  qr_code TEXT,
  connected_phone TEXT,
  connected_name TEXT,
  auto_dispatch_enabled BOOLEAN NOT NULL DEFAULT true,
  last_heartbeat_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for session tenant lookup
CREATE INDEX IF NOT EXISTS idx_whatsapp_auth_sessions_tenant ON public.whatsapp_auth_sessions(tenant_id);

-- 2. Create WhatsApp Outbox Queue Table (Transactional Outbox Pattern)
CREATE TABLE IF NOT EXISTS public.whatsapp_outbox_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  attempt_id UUID REFERENCES public.exam_attempts(id) ON DELETE CASCADE,
  exam_id UUID REFERENCES public.exams(id) ON DELETE CASCADE,
  recipient_phone TEXT NOT NULL,
  recipient_name TEXT,
  student_name TEXT NOT NULL,
  exam_title TEXT NOT NULL,
  score NUMERIC(8,2),
  max_score NUMERIC(8,2),
  percentage NUMERIC(5,2),
  message_body TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'sent', 'failed', 'dead_letter', 'cancelled')),
  retry_count INTEGER NOT NULL DEFAULT 0,
  max_retries INTEGER NOT NULL DEFAULT 3,
  scheduled_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  sent_at TIMESTAMPTZ,
  error_message TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Performance & Worker Indexes
CREATE INDEX IF NOT EXISTS idx_whatsapp_outbox_worker 
  ON public.whatsapp_outbox_queue(status, scheduled_at) 
  WHERE status IN ('pending', 'failed');

CREATE INDEX IF NOT EXISTS idx_whatsapp_outbox_tenant_student 
  ON public.whatsapp_outbox_queue(tenant_id, student_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_whatsapp_outbox_attempt 
  ON public.whatsapp_outbox_queue(attempt_id);

-- 3. Helper Function: Clean & Standardize Phone Number
CREATE OR REPLACE FUNCTION public.clean_whatsapp_phone(p_raw_phone TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_phone TEXT;
  v_digits TEXT;
BEGIN
  IF p_raw_phone IS NULL OR trim(p_raw_phone) = '' THEN
    RETURN NULL;
  END IF;

  v_phone := trim(p_raw_phone);

  -- Convert Arabic-Indic digits to Western
  v_phone := replace(v_phone, '٠', '0');
  v_phone := replace(v_phone, '١', '1');
  v_phone := replace(v_phone, '٢', '2');
  v_phone := replace(v_phone, '٣', '3');
  v_phone := replace(v_phone, '٤', '4');
  v_phone := replace(v_phone, '٥', '5');
  v_phone := replace(v_phone, '٦', '6');
  v_phone := replace(v_phone, '٧', '7');
  v_phone := replace(v_phone, '٨', '8');
  v_phone := replace(v_phone, '٩', '9');

  -- Strip all non-digit characters
  v_digits := regexp_replace(v_phone, '\D', '', 'g');

  IF length(v_digits) = 0 THEN
    RETURN NULL;
  END IF;

  -- Strip leading international 00
  IF v_digits LIKE '00%' THEN
    v_digits := substring(v_digits FROM 3);
  END IF;

  -- Egyptian 11-digit mobile (01xxxxxxxxx -> 201xxxxxxxxx)
  IF length(v_digits) = 11 AND v_digits LIKE '01%' THEN
    RETURN '20' || substring(v_digits FROM 2);
  END IF;

  -- Egyptian 10-digit without leading 0 (1xxxxxxxxx -> 201xxxxxxxxx)
  IF length(v_digits) = 10 AND v_digits LIKE '1%' THEN
    RETURN '20' || v_digits;
  END IF;

  -- Saudi 10-digit mobile (05xxxxxxxx -> 9665xxxxxxxx)
  IF length(v_digits) = 10 AND v_digits LIKE '05%' THEN
    RETURN '966' || substring(v_digits FROM 2);
  END IF;

  -- Kuwait 8-digit mobile (starts with 5, 6, 9)
  IF length(v_digits) = 8 AND (v_digits LIKE '5%' OR v_digits LIKE '6%' OR v_digits LIKE '9%') THEN
    RETURN '965' || v_digits;
  END IF;

  -- Kuwait 9-digit with leading 0 (0[569]xxxxxxx -> 965[569]xxxxxxx)
  IF length(v_digits) = 9 AND v_digits LIKE '0%' AND (substring(v_digits FROM 2 FOR 1) IN ('5', '6', '9')) THEN
    RETURN '965' || substring(v_digits FROM 2);
  END IF;

  RETURN v_digits;
END;
$$;

-- 4. Core Domain Function: Enqueue Exam Result WhatsApp Message
CREATE OR REPLACE FUNCTION public.enqueue_exam_result_whatsapp(p_attempt_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_attempt RECORD;
  v_student RECORD;
  v_exam RECORD;
  v_group_name TEXT := '';
  v_teacher_name TEXT := 'د. أنطونيوس أشرف';
  v_target_phone TEXT;
  v_clean_phone TEXT;
  v_message TEXT;
  v_pct NUMERIC(5,2);
  v_score_int INTEGER;
  v_max_score_int INTEGER;
  v_eval_text TEXT;
  v_queue_id UUID;
  v_is_auto_enabled BOOLEAN := true;
BEGIN
  -- 1. Fetch Attempt
  SELECT ea.*, e.title as exam_title, e.max_score as exam_max_score, e.content_id, e.tenant_id as exam_tenant_id
  INTO v_attempt
  FROM public.exam_attempts ea
  JOIN public.exams e ON e.id = ea.exam_id
  WHERE ea.id = p_attempt_id;

  IF v_attempt.id IS NULL THEN
    RETURN NULL;
  END IF;

  -- Check if already queued to prevent duplicate entries (Idempotency)
  SELECT id INTO v_queue_id
  FROM public.whatsapp_outbox_queue
  WHERE attempt_id = p_attempt_id
  LIMIT 1;

  IF v_queue_id IS NOT NULL THEN
    RETURN v_queue_id;
  END IF;

  -- 2. Check if Auto-Dispatch is enabled for this tenant
  SELECT auto_dispatch_enabled INTO v_is_auto_enabled
  FROM public.whatsapp_auth_sessions
  WHERE tenant_id = v_attempt.tenant_id
  LIMIT 1;

  IF v_is_auto_enabled IS FALSE THEN
    RETURN NULL;
  END IF;

  -- 3. Fetch Student & Parent Phone
  SELECT u.id, u.full_name, u.phone, u.parent_phone, u.tenant_id
  INTO v_student
  FROM public.users u
  WHERE u.id = v_attempt.student_id;

  IF v_student.id IS NULL THEN
    RETURN NULL;
  END IF;

  -- Resolve recipient phone: prefer parent_phone, fallback to student phone
  v_target_phone := COALESCE(NULLIF(trim(v_student.parent_phone), ''), NULLIF(trim(v_student.phone), ''));
  v_clean_phone := public.clean_whatsapp_phone(v_target_phone);

  IF v_clean_phone IS NULL OR length(v_clean_phone) < 8 THEN
    -- No valid phone number, record skipped in queue for audit visibility
    RETURN NULL;
  END IF;

  -- 4. Resolve Group Name
  SELECT g.name INTO v_group_name
  FROM public.group_members gm
  JOIN public.groups g ON g.id = gm.group_id
  WHERE gm.student_id = v_student.id AND g.tenant_id = v_student.tenant_id
  LIMIT 1;

  -- 5. Scores and Evaluation Text
  v_score_int := ROUND(COALESCE(v_attempt.score, 0));
  v_max_score_int := ROUND(COALESCE(v_attempt.max_score, v_attempt.exam_max_score, 100));
  v_pct := ROUND(COALESCE(v_attempt.percentage, CASE WHEN v_max_score_int > 0 THEN (v_score_int::numeric / v_max_score_int) * 100 ELSE 0 END), 1);

  IF v_pct >= 90 THEN
    v_eval_text := '🌟 أداء ممتاز ومستوى استثنائي مشرف، نسأل الله له دوام التوفيق والتفوق!';
  ELSIF v_pct >= 75 THEN
    v_eval_text := '👏 مستوى جيد جداً واجتهاد واضح، مستمرون في المتابعة للوصول للدرجة النهائية.';
  ELSIF v_pct >= 60 THEN
    v_eval_text := '👍 أداء لا بأس به، تم اجتياز الاختبار ونعمل سوياً على تعزيز النقاط التي تحتاج مراجعة.';
  ELSE
    v_eval_text := '💡 الدرجة تحتاج مزيداً من الاهتمام والمراجعة الدقيقة لأسئلة الامتحان، وتم توجيه الطالب لمراجعة الأخطاء.';
  END IF;

  -- 6. Build Personalized, Conversational Message (Anti-Ban natural structure)
  v_message := 'أهلاً بحضرتك يا فندم 🌸' || chr(10) ||
    'حبينا نطمن حضرتك على نتيجة اختبار نجلك الطالب/ ' || v_student.full_name ||
    CASE WHEN length(v_group_name) > 0 THEN ' (' || v_group_name || ')' ELSE '' END || ':' || chr(10) || chr(10) ||
    '📝 الاختبار: ' || v_attempt.exam_title || chr(10) ||
    '🎯 الدرجة: ' || v_score_int || ' من ' || v_max_score_int || ' (' || v_pct || '%)' || chr(10) || chr(10) ||
    v_eval_text || chr(10) || chr(10) ||
    'نسأل الله له دوام التوفيق والتميز، ومع حضرتك في أي وقت لأي استفسار 🌸' || chr(10) ||
    v_teacher_name;

  -- 7. Insert into Outbox Queue
  INSERT INTO public.whatsapp_outbox_queue (
    tenant_id,
    student_id,
    attempt_id,
    exam_id,
    recipient_phone,
    recipient_name,
    student_name,
    exam_title,
    score,
    max_score,
    percentage,
    message_body,
    status,
    metadata
  ) VALUES (
    v_student.tenant_id,
    v_student.id,
    p_attempt_id,
    v_attempt.exam_id,
    v_clean_phone,
    v_student.full_name || ' (ولي الأمر)',
    v_student.full_name,
    v_attempt.exam_title,
    v_score_int,
    v_max_score_int,
    v_pct,
    v_message,
    'pending',
    jsonb_build_object(
      'group_name', v_group_name,
      'source', 'automatic_exam_submission'
    )
  )
  RETURNING id INTO v_queue_id;

  RETURN v_queue_id;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'enqueue_exam_result_whatsapp failed for attempt %: %', p_attempt_id, SQLERRM;
  RETURN NULL;
END;
$$;

-- 5. Trigger on Exam Attempts: Automatically Enqueue when Attempt is Submitted
CREATE OR REPLACE FUNCTION public.trg_fn_auto_enqueue_whatsapp_on_exam_submitted()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF (NEW.status = 'submitted' OR NEW.status = 'completed') 
     AND (TG_OP = 'INSERT' OR (OLD.status IS DISTINCT FROM NEW.status)) THEN
    PERFORM public.enqueue_exam_result_whatsapp(NEW.id);
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'trg_fn_auto_enqueue_whatsapp_on_exam_submitted error: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_enqueue_whatsapp ON public.exam_attempts;
CREATE TRIGGER trg_auto_enqueue_whatsapp
AFTER INSERT OR UPDATE OF status ON public.exam_attempts
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_auto_enqueue_whatsapp_on_exam_submitted();

-- 6. Worker RPC: Fetch Next Batch of WhatsApp Messages (with FOR UPDATE SKIP LOCKED)
CREATE OR REPLACE FUNCTION public.fetch_next_whatsapp_queue_batch(p_batch_size INTEGER DEFAULT 5)
RETURNS TABLE (
  id UUID,
  tenant_id UUID,
  recipient_phone TEXT,
  student_name TEXT,
  exam_title TEXT,
  message_body TEXT,
  retry_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN QUERY
  WITH next_batch AS (
    SELECT q.id
    FROM public.whatsapp_outbox_queue q
    WHERE q.status IN ('pending', 'failed')
      AND q.scheduled_at <= now()
      AND q.retry_count < q.max_retries
    ORDER BY q.created_at ASC
    LIMIT p_batch_size
    FOR UPDATE SKIP LOCKED
  )
  UPDATE public.whatsapp_outbox_queue uq
  SET
    status = 'processing',
    updated_at = now()
  FROM next_batch nb
  WHERE uq.id = nb.id
  RETURNING 
    uq.id,
    uq.tenant_id,
    uq.recipient_phone,
    uq.student_name,
    uq.exam_title,
    uq.message_body,
    uq.retry_count;
END;
$$;

-- 7. Worker RPC: Update Message Status After Send or Failure
CREATE OR REPLACE FUNCTION public.update_whatsapp_queue_status(
  p_id UUID,
  p_status TEXT,
  p_error TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_current_retries INTEGER;
  v_max_retries INTEGER;
BEGIN
  IF p_status = 'sent' THEN
    UPDATE public.whatsapp_outbox_queue
    SET
      status = 'sent',
      sent_at = now(),
      error_message = NULL,
      updated_at = now()
    WHERE id = p_id;
  ELSIF p_status = 'failed' THEN
    SELECT retry_count, max_retries INTO v_current_retries, v_max_retries
    FROM public.whatsapp_outbox_queue
    WHERE id = p_id;

    IF v_current_retries + 1 >= v_max_retries THEN
      UPDATE public.whatsapp_outbox_queue
      SET
        status = 'dead_letter',
        retry_count = retry_count + 1,
        error_message = p_error,
        updated_at = now()
      WHERE id = p_id;
    ELSE
      UPDATE public.whatsapp_outbox_queue
      SET
        status = 'failed',
        retry_count = retry_count + 1,
        scheduled_at = now() + ((retry_count + 1) * interval '30 seconds'),
        error_message = p_error,
        updated_at = now()
      WHERE id = p_id;
    END IF;
  ELSE
    UPDATE public.whatsapp_outbox_queue
    SET
      status = p_status,
      error_message = p_error,
      updated_at = now()
    WHERE id = p_id;
  END IF;
END;
$$;

-- 8. Teacher RPC: Get WhatsApp Gateway Status & Queue Metrics
CREATE OR REPLACE FUNCTION public.get_whatsapp_gateway_status()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_tenant_id UUID;
  v_session RECORD;
  v_pending_count INTEGER := 0;
  v_sent_today_count INTEGER := 0;
  v_failed_count INTEGER := 0;
BEGIN
  -- Derive tenant_id of authenticated teacher
  SELECT tenant_id INTO v_user_tenant_id
  FROM public.users
  WHERE id = auth.uid();

  IF v_user_tenant_id IS NULL THEN
    SELECT id INTO v_user_tenant_id FROM public.tenants LIMIT 1;
  END IF;

  -- Get Session
  SELECT * INTO v_session
  FROM public.whatsapp_auth_sessions
  WHERE tenant_id = v_user_tenant_id
  LIMIT 1;

  -- Get Queue metrics
  SELECT COUNT(*) INTO v_pending_count
  FROM public.whatsapp_outbox_queue
  WHERE tenant_id = v_user_tenant_id AND status IN ('pending', 'processing');

  SELECT COUNT(*) INTO v_sent_today_count
  FROM public.whatsapp_outbox_queue
  WHERE tenant_id = v_user_tenant_id AND status = 'sent' AND created_at >= current_date;

  SELECT COUNT(*) INTO v_failed_count
  FROM public.whatsapp_outbox_queue
  WHERE tenant_id = v_user_tenant_id AND status IN ('failed', 'dead_letter');

  RETURN jsonb_build_object(
    'status', COALESCE(v_session.status, 'disconnected'),
    'connected_phone', v_session.connected_phone,
    'connected_name', v_session.connected_name,
    'qr_code', CASE WHEN v_session.status = 'qr_ready' THEN v_session.qr_code ELSE NULL END,
    'auto_dispatch_enabled', COALESCE(v_session.auto_dispatch_enabled, true),
    'last_heartbeat_at', v_session.last_heartbeat_at,
    'pending_count', v_pending_count,
    'sent_today_count', v_sent_today_count,
    'failed_count', v_failed_count
  );
END;
$$;

-- 9. Teacher RPC: Toggle Auto-Dispatch On/Off
CREATE OR REPLACE FUNCTION public.set_whatsapp_auto_dispatch(p_enabled BOOLEAN)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_tenant_id UUID;
BEGIN
  SELECT tenant_id INTO v_user_tenant_id
  FROM public.users
  WHERE id = auth.uid();

  IF v_user_tenant_id IS NULL THEN
    SELECT id INTO v_user_tenant_id FROM public.tenants LIMIT 1;
  END IF;

  INSERT INTO public.whatsapp_auth_sessions (id, tenant_id, auto_dispatch_enabled, status)
  VALUES ('session_' || v_user_tenant_id, v_user_tenant_id, p_enabled, 'disconnected')
  ON CONFLICT (id) DO UPDATE
  SET 
    auto_dispatch_enabled = p_enabled,
    updated_at = now();

  RETURN p_enabled;
END;
$$;

-- 10. Enable Row Level Security (RLS)
ALTER TABLE public.whatsapp_auth_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_outbox_queue ENABLE ROW LEVEL SECURITY;

-- Teachers can view queue & sessions of their tenant
DROP POLICY IF EXISTS "whatsapp_outbox_teacher_read" ON public.whatsapp_outbox_queue;
CREATE POLICY "whatsapp_outbox_teacher_read" ON public.whatsapp_outbox_queue
FOR SELECT TO authenticated
USING (
  tenant_id = (SELECT tenant_id FROM public.users WHERE id = auth.uid())
);

DROP POLICY IF EXISTS "whatsapp_sessions_teacher_read" ON public.whatsapp_auth_sessions;
CREATE POLICY "whatsapp_sessions_teacher_read" ON public.whatsapp_auth_sessions
FOR SELECT TO authenticated
USING (
  tenant_id = (SELECT tenant_id FROM public.users WHERE id = auth.uid())
);

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION public.get_whatsapp_gateway_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_whatsapp_auto_dispatch(BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.clean_whatsapp_phone(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.enqueue_exam_result_whatsapp(UUID) TO authenticated;

-- Notify PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';
