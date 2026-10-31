-- Migration 0105: WhatsApp Studio Custom Templates, Dynamic Tiers & Recipient Targeting
-- Adds dispatch_config JSONB column and updates enqueue_exam_result_whatsapp to honor custom templates.

-- 1. Add dispatch_config column to whatsapp_auth_sessions
ALTER TABLE public.whatsapp_auth_sessions 
ADD COLUMN IF NOT EXISTS dispatch_config JSONB DEFAULT '{
  "recipient_target": "parent_only",
  "dispatch_timing": "instant",
  "header_template": "أهلاً بحضرتك يا فندم 🌸\nحبينا نطمن حضرتك على نتيجة اختبار نجلك الطالب/ {student_name} ({group_name}):",
  "body_template": "📝 الاختبار: {exam_title}\n🎯 الدرجة: {score} من {max_score} ({percentage}%)\n\n{evaluation_text}",
  "footer_template": "نسأل الله له دوام التوفيق والتميز، ومع حضرتك في أي وقت لأي استفسار 🌸\n{teacher_name}",
  "tier_excellent_text": "🌟 أداء ممتاز ومستوى استثنائي مشرف، نسأل الله له دوام التوفيق والتفوق!",
  "tier_good_text": "👏 مستوى جيد جداً واجتهاد واضح، مستمرون في المتابعة للوصول للدرجة النهائية.",
  "tier_pass_text": "👍 أداء لا بأس به، تم اجتياز الاختبار ونعمل سوياً على تعزيز النقاط التي تحتاج مراجعة.",
  "tier_needs_improvement_text": "💡 الدرجة تحتاج مزيداً من الاهتمام والمراجعة الدقيقة لأسئلة الامتحان، وتم توجيه الطالب لمراجعة الأخطاء."
}'::jsonb;

-- 2. RPC to save dispatch configuration
CREATE OR REPLACE FUNCTION public.save_whatsapp_dispatch_config(p_config JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_tenant_id UUID;
  v_session_id TEXT;
BEGIN
  -- Derive tenant_id of authenticated teacher
  SELECT tenant_id INTO v_user_tenant_id FROM public.users WHERE id = auth.uid();
  IF v_user_tenant_id IS NULL THEN
    SELECT id INTO v_user_tenant_id FROM public.tenants LIMIT 1;
  END IF;

  -- Locate active session
  SELECT id INTO v_session_id
  FROM public.whatsapp_auth_sessions
  WHERE tenant_id = v_user_tenant_id OR id = 'session_default'
  ORDER BY 
    CASE WHEN status = 'connected' THEN 1 WHEN status = 'qr_ready' THEN 2 ELSE 3 END,
    updated_at DESC
  LIMIT 1;

  IF v_session_id IS NULL THEN
    v_session_id := 'session_default';
  END IF;

  -- Upsert configuration
  UPDATE public.whatsapp_auth_sessions
  SET 
    dispatch_config = p_config,
    updated_at = now()
  WHERE id = v_session_id;

  RETURN p_config;
END;
$$;

-- 3. Enhance enqueue_exam_result_whatsapp to dynamically inject custom templates
CREATE OR REPLACE FUNCTION public.enqueue_exam_result_whatsapp(p_attempt_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_attempt RECORD;
  v_student RECORD;
  v_session RECORD;
  v_config JSONB;
  v_group_name TEXT := '';
  v_teacher_name TEXT := 'د. أنطونيوس أشرف';
  v_parent_phone TEXT;
  v_student_phone TEXT;
  v_target_phone TEXT;
  v_clean_phone TEXT;
  v_message TEXT;
  v_header TEXT;
  v_body TEXT;
  v_footer TEXT;
  v_eval_text TEXT;
  v_pct NUMERIC(5,2);
  v_score_int INTEGER;
  v_max_score_int INTEGER;
  v_queue_id UUID;
  v_is_auto_enabled BOOLEAN := true;
  v_target_type TEXT := 'parent_only';
BEGIN
  -- 1. Fetch Attempt with Exam and Content Info
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

  -- 2. Fetch Session & Config
  SELECT * INTO v_session
  FROM public.whatsapp_auth_sessions
  WHERE tenant_id = v_attempt.tenant_id OR id = 'session_default'
  ORDER BY 
    CASE WHEN status = 'connected' THEN 1 ELSE 2 END,
    updated_at DESC
  LIMIT 1;

  IF v_session.auto_dispatch_enabled IS FALSE THEN
    RETURN NULL;
  END IF;

  v_config := COALESCE(v_session.dispatch_config, '{}'::jsonb);
  v_target_type := COALESCE(v_config->>'recipient_target', 'parent_only');

  -- 3. Fetch Student & Parent Phone
  SELECT u.id, u.full_name, u.phone, u.parent_phone, u.tenant_id
  INTO v_student
  FROM public.users u
  WHERE u.id = v_attempt.student_id;

  IF v_student.id IS NULL THEN
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

  -- Tier texts with smart fallbacks
  IF v_pct >= 90 THEN
    v_eval_text := COALESCE(v_config->>'tier_excellent_text', '🌟 أداء ممتاز ومستوى استثنائي مشرف، نسأل الله له دوام التوفيق والتفوق!');
  ELSIF v_pct >= 75 THEN
    v_eval_text := COALESCE(v_config->>'tier_good_text', '👏 مستوى جيد جداً واجتهاد واضح، مستمرون في المتابعة للوصول للدرجة النهائية.');
  ELSIF v_pct >= 60 THEN
    v_eval_text := COALESCE(v_config->>'tier_pass_text', '👍 أداء لا بأس به، تم اجتياز الاختبار ونعمل سوياً على تعزيز النقاط التي تحتاج مراجعة.');
  ELSE
    v_eval_text := COALESCE(v_config->>'tier_needs_improvement_text', '💡 الدرجة تحتاج مزيداً من الاهتمام والمراجعة الدقيقة لأسئلة الامتحان، وتم توجيه الطالب لمراجعة الأخطاء.');
  END IF;

  -- 6. Dynamic Template Interpolation
  v_header := COALESCE(v_config->>'header_template', 'أهلاً بحضرتك يا فندم 🌸\nحبينا نطمن حضرتك على نتيجة اختبار نجلك الطالب/ {student_name} ({group_name}):');
  v_body := COALESCE(v_config->>'body_template', '📝 الاختبار: {exam_title}\n🎯 الدرجة: {score} من {max_score} ({percentage}%)\n\n{evaluation_text}');
  v_footer := COALESCE(v_config->>'footer_template', 'نسأل الله له دوام التوفيق والتميز، ومع حضرتك في أي وقت لأي استفسار 🌸\n{teacher_name}');

  v_message := v_header || chr(10) || chr(10) || v_body || chr(10) || chr(10) || v_footer;

  -- Variable substitution
  v_message := replace(v_message, '{student_name}', v_student.full_name);
  v_message := replace(v_message, '{exam_title}', v_attempt.exam_title);
  v_message := replace(v_message, '{score}', v_score_int::text);
  v_message := replace(v_message, '{max_score}', v_max_score_int::text);
  v_message := replace(v_message, '{percentage}', v_pct::text);
  v_message := replace(v_message, '{group_name}', COALESCE(v_group_name, 'العامة'));
  v_message := replace(v_message, '{teacher_name}', v_teacher_name);
  v_message := replace(v_message, '{evaluation_text}', v_eval_text);

  -- 7. Resolve Recipient Phone Numbers
  v_parent_phone := public.clean_whatsapp_phone(v_student.parent_phone);
  v_student_phone := public.clean_whatsapp_phone(v_student.phone);

  -- 8. Insert into Outbox Queue according to target policy
  IF v_target_type = 'both' THEN
    -- Parent dispatch
    IF v_parent_phone IS NOT NULL AND length(v_parent_phone) >= 8 THEN
      INSERT INTO public.whatsapp_outbox_queue (
        tenant_id, student_id, attempt_id, exam_id, recipient_phone,
        recipient_name, student_name, exam_title, score, max_score,
        percentage, message_body, status, metadata
      ) VALUES (
        v_attempt.tenant_id, v_student.id, p_attempt_id, v_attempt.exam_id,
        v_parent_phone, v_student.full_name || ' (ولي الأمر)', v_student.full_name,
        v_attempt.exam_title, v_score_int, v_max_score_int, v_pct,
        v_message, 'pending',
        jsonb_build_object('group_name', v_group_name, 'target', 'parent')
      ) RETURNING id INTO v_queue_id;
    END IF;

    -- Student dispatch
    IF v_student_phone IS NOT NULL AND length(v_student_phone) >= 8 AND v_student_phone <> COALESCE(v_parent_phone, '') THEN
      INSERT INTO public.whatsapp_outbox_queue (
        tenant_id, student_id, attempt_id, exam_id, recipient_phone,
        recipient_name, student_name, exam_title, score, max_score,
        percentage, message_body, status, metadata
      ) VALUES (
        v_attempt.tenant_id, v_student.id, p_attempt_id, v_attempt.exam_id,
        v_student_phone, v_student.full_name || ' (الطالب)', v_student.full_name,
        v_attempt.exam_title, v_score_int, v_max_score_int, v_pct,
        v_message, 'pending',
        jsonb_build_object('group_name', v_group_name, 'target', 'student')
      );
    END IF;

  ELSIF v_target_type = 'student_only' THEN
    v_clean_phone := COALESCE(v_student_phone, v_parent_phone);
    IF v_clean_phone IS NOT NULL AND length(v_clean_phone) >= 8 THEN
      INSERT INTO public.whatsapp_outbox_queue (
        tenant_id, student_id, attempt_id, exam_id, recipient_phone,
        recipient_name, student_name, exam_title, score, max_score,
        percentage, message_body, status, metadata
      ) VALUES (
        v_attempt.tenant_id, v_student.id, p_attempt_id, v_attempt.exam_id,
        v_clean_phone, v_student.full_name || ' (الطالب)', v_student.full_name,
        v_attempt.exam_title, v_score_int, v_max_score_int, v_pct,
        v_message, 'pending',
        jsonb_build_object('group_name', v_group_name, 'target', 'student')
      ) RETURNING id INTO v_queue_id;
    END IF;

  ELSE -- Default: 'parent_only'
    v_clean_phone := COALESCE(v_parent_phone, v_student_phone);
    IF v_clean_phone IS NOT NULL AND length(v_clean_phone) >= 8 THEN
      INSERT INTO public.whatsapp_outbox_queue (
        tenant_id, student_id, attempt_id, exam_id, recipient_phone,
        recipient_name, student_name, exam_title, score, max_score,
        percentage, message_body, status, metadata
      ) VALUES (
        v_attempt.tenant_id, v_student.id, p_attempt_id, v_attempt.exam_id,
        v_clean_phone, v_student.full_name || ' (ولي الأمر)', v_student.full_name,
        v_attempt.exam_title, v_score_int, v_max_score_int, v_pct,
        v_message, 'pending',
        jsonb_build_object('group_name', v_group_name, 'target', 'parent')
      ) RETURNING id INTO v_queue_id;
    END IF;
  END IF;

  RETURN v_queue_id;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'enqueue_exam_result_whatsapp failed for attempt %: %', p_attempt_id, SQLERRM;
  RETURN NULL;
END;
$$;

-- 4. Permissions & Reload
GRANT EXECUTE ON FUNCTION public.save_whatsapp_dispatch_config(JSONB) TO authenticated, service_role;
NOTIFY pgrst, 'reload schema';
