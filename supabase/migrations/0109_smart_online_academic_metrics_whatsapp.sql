-- Migration 0109: Smart Online Academic Metrics for WhatsApp Exam Results
-- Adds automated computation of online platform study time, lecture video completion,
-- exam progress, and cumulative grade average, with dynamic tag interpolation.

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
  v_teacher_name TEXT := 'إدارة الأكاديمية';
  v_parent_phone TEXT;
  v_student_phone TEXT;
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
  v_target_type TEXT := 'parent_only';

  -- Smart Online Metrics Variables
  v_video_seconds BIGINT := 0;
  v_exam_seconds BIGINT := 0;
  v_total_seconds BIGINT := 0;
  v_hours INTEGER := 0;
  v_minutes INTEGER := 0;
  v_study_time_text TEXT := 'أقل من دقيقة';

  v_lectures_total INTEGER := 0;
  v_lectures_completed INTEGER := 0;
  v_lectures_pct INTEGER := 0;
  v_lectures_progress_text TEXT := '0%';

  v_exams_total INTEGER := 0;
  v_exams_completed INTEGER := 0;
  v_exams_pct INTEGER := 0;
  v_exams_progress_text TEXT := '0%';

  v_cumulative_avg NUMERIC(5,2) := 0;
  v_cumulative_avg_text TEXT := '0%';
  v_default_body TEXT;
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

  -- 2. Strictly check if this tenant has an active, connected WhatsApp session
  -- STRICT MULTI-TENANCY ISOLATION: NEVER fall back to another tenant's session!
  SELECT * INTO v_session
  FROM public.whatsapp_auth_sessions
  WHERE tenant_id = v_attempt.tenant_id
    AND status = 'connected'
  ORDER BY updated_at DESC
  LIMIT 1;

  -- If no session is connected or auto_dispatch is disabled for THIS tenant, exit immediately
  IF v_session.id IS NULL OR v_session.auto_dispatch_enabled IS FALSE THEN
    RETURN NULL;
  END IF;

  -- Sandbox Guard: Staging / Demo tenant (11111111-1111-1111-1111-111111111111) must never leak
  IF v_attempt.tenant_id = '11111111-1111-1111-1111-111111111111' THEN
    IF v_session.tenant_id <> '11111111-1111-1111-1111-111111111111' THEN
      RETURN NULL;
    END IF;
  END IF;

  v_config := COALESCE(v_session.dispatch_config, '{}'::jsonb);
  v_target_type := COALESCE(v_config->>'recipient_target', 'parent_only');

  -- 3. Dynamically fetch the real teacher's name for THIS tenant only
  SELECT COALESCE(NULLIF(trim(full_name), ''), 'إدارة الأكاديمية')
  INTO v_teacher_name
  FROM public.users
  WHERE tenant_id = v_attempt.tenant_id AND role = 'teacher'
  ORDER BY created_at ASC
  LIMIT 1;

  IF v_teacher_name IS NULL OR length(v_teacher_name) = 0 THEN
    v_teacher_name := 'إدارة الأكاديمية';
  END IF;

  -- 4. Fetch Student Info (Must belong to the same tenant)
  SELECT u.id, u.full_name, u.phone, u.parent_phone, u.tenant_id
  INTO v_student
  FROM public.users u
  WHERE u.id = v_attempt.student_id AND u.tenant_id = v_attempt.tenant_id;

  IF v_student.id IS NULL THEN
    RETURN NULL;
  END IF;

  -- 5. Resolve Primary Group Name
  SELECT g.name INTO v_group_name
  FROM public.group_members gm
  JOIN public.groups g ON g.id = gm.group_id
  WHERE gm.student_id = v_student.id AND g.tenant_id = v_attempt.tenant_id
  LIMIT 1;

  -- 6. Scores and Evaluation Text
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

  -- =========================================================================
  -- 7. SMART ONLINE METRICS CALCULATION (Online-First)
  -- =========================================================================

  -- A. Study & Interaction Time (Video watch progress + Exam attempt durations)
  SELECT COALESCE(SUM(vp.progress_seconds), 0)
  INTO v_video_seconds
  FROM public.video_progress vp
  JOIN public.videos v ON v.id = vp.video_id
  JOIN public.content c ON c.id = v.content_id
  WHERE vp.student_id = v_student.id
    AND c.tenant_id = v_attempt.tenant_id;

  SELECT COALESCE(SUM(EXTRACT(EPOCH FROM (COALESCE(ea.submitted_at, now()) - ea.started_at))), 0)::BIGINT
  INTO v_exam_seconds
  FROM public.exam_attempts ea
  JOIN public.exams e ON e.id = ea.exam_id
  WHERE ea.student_id = v_student.id
    AND e.tenant_id = v_attempt.tenant_id
    AND ea.started_at IS NOT NULL;

  v_total_seconds := v_video_seconds + v_exam_seconds;
  v_hours := (v_total_seconds / 3600)::INTEGER;
  v_minutes := ((v_total_seconds % 3600) / 60)::INTEGER;

  IF v_hours > 0 AND v_minutes > 0 THEN
    v_study_time_text := v_hours::TEXT || ' ساعة و ' || v_minutes::TEXT || ' دقيقة';
  ELSIF v_hours > 0 THEN
    v_study_time_text := v_hours::TEXT || ' ساعة';
  ELSIF v_minutes > 0 THEN
    v_study_time_text := v_minutes::TEXT || ' دقيقة';
  ELSE
    v_study_time_text := 'أقل من دقيقة';
  END IF;

  -- B. Lectures Progress (Completed videos out of published videos in student's groups)
  SELECT COUNT(DISTINCT v.id)
  INTO v_lectures_total
  FROM public.videos v
  JOIN public.content c ON c.id = v.content_id
  WHERE c.tenant_id = v_attempt.tenant_id
    AND c.status = 'published'
    AND c.group_id IN (
      SELECT gm.group_id FROM public.group_members gm WHERE gm.student_id = v_student.id
    );

  SELECT COUNT(DISTINCT vp.video_id)
  INTO v_lectures_completed
  FROM public.video_progress vp
  JOIN public.videos v ON v.id = vp.video_id
  JOIN public.content c ON c.id = v.content_id
  WHERE vp.student_id = v_student.id
    AND c.tenant_id = v_attempt.tenant_id
    AND c.status = 'published'
    AND (vp.completed IS TRUE OR vp.percentage >= 80)
    AND c.group_id IN (
      SELECT gm.group_id FROM public.group_members gm WHERE gm.student_id = v_student.id
    );

  IF v_lectures_total > 0 THEN
    v_lectures_pct := ROUND((v_lectures_completed::NUMERIC / v_lectures_total::NUMERIC) * 100);
    v_lectures_progress_text := 'تمت مشاهدة ' || v_lectures_completed::TEXT || ' من ' || v_lectures_total::TEXT || ' محاضرة (' || v_lectures_pct::TEXT || '%)';
  ELSE
    v_lectures_progress_text := 'تمت مشاهدة ' || v_lectures_completed::TEXT || ' محاضرة';
  END IF;

  -- C. Exam Completion Progress (Submitted attempts out of published exams in student's groups)
  SELECT COUNT(DISTINCT e.id)
  INTO v_exams_total
  FROM public.exams e
  JOIN public.content c ON c.id = e.content_id
  WHERE c.tenant_id = v_attempt.tenant_id
    AND c.status = 'published'
    AND c.group_id IN (
      SELECT gm.group_id FROM public.group_members gm WHERE gm.student_id = v_student.id
    );

  SELECT COUNT(DISTINCT ea.exam_id)
  INTO v_exams_completed
  FROM public.exam_attempts ea
  JOIN public.exams e ON e.id = ea.exam_id
  WHERE ea.student_id = v_student.id
    AND e.tenant_id = v_attempt.tenant_id
    AND ea.status = 'submitted';

  IF v_exams_total > 0 THEN
    v_exams_pct := ROUND((v_exams_completed::NUMERIC / v_exams_total::NUMERIC) * 100);
    v_exams_progress_text := 'تم أداء ' || v_exams_completed::TEXT || ' من ' || v_exams_total::TEXT || ' اختبار (' || v_exams_pct::TEXT || '%)';
  ELSE
    v_exams_progress_text := 'تم أداء ' || v_exams_completed::TEXT || ' اختبار';
  END IF;

  -- D. Cumulative Exam Average
  SELECT COALESCE(ROUND(AVG(ea.percentage)::NUMERIC, 1), 0)
  INTO v_cumulative_avg
  FROM public.exam_attempts ea
  JOIN public.exams e ON e.id = ea.exam_id
  WHERE ea.student_id = v_student.id
    AND e.tenant_id = v_attempt.tenant_id
    AND ea.status = 'submitted'
    AND ea.percentage IS NOT NULL;

  v_cumulative_avg_text := v_cumulative_avg::TEXT || '%';

  -- =========================================================================
  -- 8. DYNAMIC TEMPLATE INTERPOLATION
  -- =========================================================================
  v_default_body := '📝 الاختبار: {exam_title}' || chr(10) ||
    '🎯 الدرجة: {score} من {max_score} ({percentage}%)' || chr(10) || chr(10) ||
    '{evaluation_text}' || chr(10) || chr(10) ||
    '━━━━━━━━━━━━━━━━━━━━' || chr(10) ||
    '📊 متابعة المنصة الأكاديمية:' || chr(10) ||
    '⏱️ وقت المذاكرة والتفاعل: {study_time}' || chr(10) ||
    '🎬 إنجاز المحاضرات: {lectures_progress}' || chr(10) ||
    '📑 إنجاز الاختبارات: {exams_progress}' || chr(10) ||
    '📈 المعدل التراكمي: {cumulative_avg}' || chr(10) ||
    '━━━━━━━━━━━━━━━━━━━━';

  v_header := COALESCE(v_config->>'header_template', 'أهلاً بحضرتك يا فندم 🌸\nحبينا نطمن حضرتك على نتيجة اختبار نجلك الطالب/ {student_name} ({group_name}):');
  
  -- If body template has legacy short version or is not set, use the smart academic snapshot
  IF v_config->>'body_template' IS NULL OR 
     v_config->>'body_template' = '📝 الاختبار: {exam_title}\n🎯 الدرجة: {score} من {max_score} ({percentage}%)\n\n{evaluation_text}' THEN
    v_body := v_default_body;
  ELSE
    v_body := v_config->>'body_template';
  END IF;

  v_footer := COALESCE(v_config->>'footer_template', 'نسأل الله له دوام التوفيق والتميز، ومع حضرتك في أي وقت لأي استفسار 🌸\n{teacher_name}');

  v_message := v_header || chr(10) || chr(10) || v_body || chr(10) || chr(10) || v_footer;

  -- Variable substitution (Core variables)
  v_message := replace(v_message, '{student_name}', v_student.full_name);
  v_message := replace(v_message, '{exam_title}', v_attempt.exam_title);
  v_message := replace(v_message, '{score}', v_score_int::text);
  v_message := replace(v_message, '{max_score}', v_max_score_int::text);
  v_message := replace(v_message, '{percentage}', v_pct::text);
  v_message := replace(v_message, '{group_name}', COALESCE(v_group_name, 'العامة'));
  v_message := replace(v_message, '{teacher_name}', v_teacher_name);
  v_message := replace(v_message, '{evaluation_text}', v_eval_text);

  -- Smart Online Metric substitutions
  v_message := replace(v_message, '{study_time}', v_study_time_text);
  v_message := replace(v_message, '{lectures_progress}', v_lectures_progress_text);
  v_message := replace(v_message, '{exams_progress}', v_exams_progress_text);
  v_message := replace(v_message, '{cumulative_avg}', v_cumulative_avg_text);

  -- 9. Resolve Recipient Phone Numbers
  v_parent_phone := public.clean_whatsapp_phone(v_student.parent_phone);
  v_student_phone := public.clean_whatsapp_phone(v_student.phone);

  -- 10. Insert into Outbox Queue strictly bound to v_attempt.tenant_id
  IF v_target_type = 'both' THEN
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
        jsonb_build_object(
          'group_name', v_group_name,
          'target', 'parent',
          'study_time', v_study_time_text,
          'lectures_progress', v_lectures_progress_text,
          'exams_progress', v_exams_progress_text,
          'cumulative_avg', v_cumulative_avg_text
        )
      ) RETURNING id INTO v_queue_id;
    END IF;

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
        jsonb_build_object(
          'group_name', v_group_name,
          'target', 'student',
          'study_time', v_study_time_text,
          'lectures_progress', v_lectures_progress_text,
          'exams_progress', v_exams_progress_text,
          'cumulative_avg', v_cumulative_avg_text
        )
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
        jsonb_build_object(
          'group_name', v_group_name,
          'target', 'student',
          'study_time', v_study_time_text,
          'lectures_progress', v_lectures_progress_text,
          'exams_progress', v_exams_progress_text,
          'cumulative_avg', v_cumulative_avg_text
        )
      ) RETURNING id INTO v_queue_id;
    END IF;

  ELSE -- Default: parent_only
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
        jsonb_build_object(
          'group_name', v_group_name,
          'target', 'parent',
          'study_time', v_study_time_text,
          'lectures_progress', v_lectures_progress_text,
          'exams_progress', v_exams_progress_text,
          'cumulative_avg', v_cumulative_avg_text
        )
      ) RETURNING id INTO v_queue_id;
    END IF;
  END IF;

  RETURN v_queue_id;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'enqueue_exam_result_whatsapp failed for attempt %: %', p_attempt_id, SQLERRM;
    RETURN NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION public.enqueue_exam_result_whatsapp(UUID) TO authenticated, service_role;
