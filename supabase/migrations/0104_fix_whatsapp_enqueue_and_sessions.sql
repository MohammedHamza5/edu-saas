-- Migration 0104: Fix WhatsApp Enqueue Columns, Session Tenant Mapping & Backfill Recent Attempt
-- Corrects record field access, joins exams/content safely, and links session_default to tenant.

-- 1. Ensure whatsapp_auth_sessions has correct tenant_id for session_default
UPDATE public.whatsapp_auth_sessions
SET tenant_id = '11111111-1111-1111-1111-111111111111'
WHERE id = 'session_default' AND tenant_id IS NULL;

-- 2. Correct and Robust enqueue_exam_result_whatsapp Function
CREATE OR REPLACE FUNCTION public.enqueue_exam_result_whatsapp(p_attempt_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_attempt RECORD;
  v_student RECORD;
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
  -- 1. Fetch Attempt with Exam and Content Info safely
  SELECT 
    ea.id,
    ea.exam_id,
    ea.student_id,
    ea.score,
    ea.percentage,
    ea.status,
    e.tenant_id,
    COALESCE(NULLIF(trim(e.title), ''), NULLIF(trim(c.title), ''), 'الاختبار الأكاديمي') AS exam_title,
    COALESCE(e.max_score, 100) AS exam_max_score
  INTO v_attempt
  FROM public.exam_attempts ea
  JOIN public.exams e ON e.id = ea.exam_id
  LEFT JOIN public.content c ON c.id = e.content_id
  WHERE ea.id = p_attempt_id;

  IF v_attempt.id IS NULL THEN
    RETURN NULL;
  END IF;

  -- Prevent duplicate entries for the same attempt (Idempotency)
  SELECT id INTO v_queue_id
  FROM public.whatsapp_outbox_queue
  WHERE attempt_id = p_attempt_id
  LIMIT 1;

  IF v_queue_id IS NOT NULL THEN
    RETURN v_queue_id;
  END IF;

  -- 2. Check if Auto-Dispatch is enabled for this tenant or default session
  SELECT auto_dispatch_enabled INTO v_is_auto_enabled
  FROM public.whatsapp_auth_sessions
  WHERE tenant_id = v_attempt.tenant_id OR id = 'session_default'
  ORDER BY 
    CASE WHEN status = 'connected' THEN 1 ELSE 2 END,
    updated_at DESC
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
    RETURN NULL;
  END IF;

  -- 4. Resolve Group Name
  SELECT g.name INTO v_group_name
  FROM public.group_members gm
  JOIN public.groups g ON g.id = gm.group_id
  WHERE gm.student_id = v_student.id AND g.tenant_id = v_attempt.tenant_id
  LIMIT 1;

  -- 5. Scores and Evaluation Text
  v_score_int := ROUND(COALESCE(v_attempt.score, 0));
  v_max_score_int := ROUND(COALESCE(v_attempt.exam_max_score, 100));
  
  IF v_attempt.percentage IS NOT NULL THEN
    v_pct := ROUND(v_attempt.percentage::numeric, 1);
  ELSIF v_max_score_int > 0 THEN
    v_pct := ROUND((v_score_int::numeric / v_max_score_int::numeric) * 100, 1);
  ELSE
    v_pct := 0;
  END IF;

  IF v_pct >= 90 THEN
    v_eval_text := '🌟 أداء ممتاز ومستوى استثنائي مشرف، نسأل الله له دوام التوفيق والتفوق!';
  ELSIF v_pct >= 75 THEN
    v_eval_text := '👏 مستوى جيد جداً واجتهاد واضح، مستمرون في المتابعة للوصول للدرجة النهائية.';
  ELSIF v_pct >= 60 THEN
    v_eval_text := '👍 أداء لا بأس به، تم اجتياز الاختبار ونعمل سوياً على تعزيز النقاط التي تحتاج مراجعة.';
  ELSE
    v_eval_text := '💡 الدرجة تحتاج مزيداً من الاهتمام والمراجعة الدقيقة لأسئلة الامتحان، وتم توجيه الطالب لمراجعة الأخطاء.';
  END IF;

  -- 6. Build Conversational WhatsApp Message
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
    v_attempt.tenant_id,
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

-- 3. Update get_whatsapp_gateway_status to check both tenant and session_default
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

  -- Get Session (prioritize connected session, check tenant or default)
  SELECT * INTO v_session
  FROM public.whatsapp_auth_sessions
  WHERE tenant_id = v_user_tenant_id OR id = 'session_default'
  ORDER BY 
    CASE WHEN status = 'connected' THEN 1 WHEN status = 'qr_ready' THEN 2 ELSE 3 END,
    updated_at DESC
  LIMIT 1;

  -- Get Queue metrics
  SELECT COUNT(*) INTO v_pending_count
  FROM public.whatsapp_outbox_queue
  WHERE (tenant_id = v_user_tenant_id OR v_user_tenant_id IS NULL)
    AND status IN ('pending', 'processing');

  SELECT COUNT(*) INTO v_sent_today_count
  FROM public.whatsapp_outbox_queue
  WHERE (tenant_id = v_user_tenant_id OR v_user_tenant_id IS NULL)
    AND status = 'sent'
    AND sent_at >= date_trunc('day', now());

  SELECT COUNT(*) INTO v_failed_count
  FROM public.whatsapp_outbox_queue
  WHERE (tenant_id = v_user_tenant_id OR v_user_tenant_id IS NULL)
    AND status IN ('failed', 'dead_letter');

  RETURN jsonb_build_object(
    'status', COALESCE(v_session.status, 'disconnected'),
    'connected_phone', v_session.connected_phone,
    'connected_name', v_session.connected_name,
    'qr_code', v_session.qr_code,
    'auto_dispatch_enabled', COALESCE(v_session.auto_dispatch_enabled, true),
    'last_heartbeat_at', v_session.last_heartbeat_at,
    'pending_count', v_pending_count,
    'sent_today_count', v_sent_today_count,
    'failed_count', v_failed_count
  );
END;
$$;

-- 4. Re-grant permissions
GRANT EXECUTE ON FUNCTION public.enqueue_exam_result_whatsapp(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_whatsapp_gateway_status() TO authenticated, service_role;

-- 5. Backfill the user's latest test attempt directly into the queue right now!
SELECT public.enqueue_exam_result_whatsapp('9338f42c-88ab-4ed4-9c7d-417325387700');

-- 6. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
