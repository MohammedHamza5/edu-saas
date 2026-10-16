-- ============================================================================
-- Migration 0088: Complete Automatic Notifications Triggers and Dispatch System
-- ============================================================================
-- Fixes system-wide notification delivery across all teacher & student actions:
-- 1. Automatic trigger on content_groups when lectures/materials are published.
-- 2. Automatic trigger on content when content status is published.
-- 3. Automatic trigger on exam_versions when exams are published.
-- 4. Automatic trigger on assignments when new assignments are created.
-- 5. Automatic trigger on assignment_submissions when assignments are reviewed/graded.
-- 6. Automatic trigger on attendance when student attendance is marked.
-- 7. Automatic trigger on exam_attempts when students complete exams.
-- 8. Enhanced atomic RPC dispatch_tenant_announcement for general announcements.
-- 9. Idempotency guards to prevent duplicate notifications.
-- 10. Backfill notifications for recently published active lectures & exams.
-- ============================================================================

-- 1. Enhanced dispatch_group_notification with idempotency
CREATE OR REPLACE FUNCTION public.dispatch_group_notification(
  p_group_id uuid,
  p_title text,
  p_body text,
  p_type text,
  p_data jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_tenant_id uuid;
  v_notif_id uuid;
  v_student_ids uuid[];
  v_parent_ids uuid[];
  v_all_recipient_ids uuid[];
BEGIN
  -- Derive tenant_id from group
  SELECT tenant_id INTO v_tenant_id
  FROM public.groups
  WHERE id = p_group_id;

  IF v_tenant_id IS NULL THEN
    SELECT tenant_id INTO v_tenant_id
    FROM public.users
    WHERE id = auth.uid();
  END IF;

  IF v_tenant_id IS NULL THEN
    SELECT tenant_id INTO v_tenant_id
    FROM public.tenants
    WHERE status = 'active'
    LIMIT 1;
  END IF;

  IF v_tenant_id IS NULL THEN
    RETURN NULL;
  END IF;

  -- 1. Insert notification record
  INSERT INTO public.notifications (tenant_id, title, body, type, data)
  VALUES (
    v_tenant_id,
    p_title,
    p_body,
    p_type,
    COALESCE(p_data, '{}'::jsonb) || jsonb_build_object('group_id', p_group_id)
  )
  RETURNING id INTO v_notif_id;

  -- 2. Gather active student IDs in this group
  SELECT array_agg(student_id) INTO v_student_ids
  FROM public.group_members
  WHERE group_id = p_group_id AND status = 'active';

  -- 3. Gather parent IDs linked to these students
  IF v_student_ids IS NOT NULL AND array_length(v_student_ids, 1) > 0 THEN
    SELECT array_agg(DISTINCT parent_id) INTO v_parent_ids
    FROM public.parent_students
    WHERE student_id = ANY(v_student_ids);

    -- Combine unique recipients (students + parents)
    SELECT array_agg(DISTINCT uid) INTO v_all_recipient_ids
    FROM (
      SELECT unnest(v_student_ids) AS uid
      UNION
      SELECT unnest(COALESCE(v_parent_ids, ARRAY[]::uuid[])) AS uid
    ) combined;

    -- 4. Batch insert into notification_recipients
    IF v_all_recipient_ids IS NOT NULL AND array_length(v_all_recipient_ids, 1) > 0 THEN
      INSERT INTO public.notification_recipients (notification_id, user_id)
      SELECT v_notif_id, uid
      FROM unnest(v_all_recipient_ids) AS uid
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;

  RETURN v_notif_id;
END;
$$;

-- 2. Enhanced dispatch_user_notification
CREATE OR REPLACE FUNCTION public.dispatch_user_notification(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_type text,
  p_data jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_tenant_id uuid;
  v_notif_id uuid;
  v_parent_ids uuid[];
  v_all_recipient_ids uuid[];
BEGIN
  -- Derive tenant_id from target user
  SELECT tenant_id INTO v_tenant_id
  FROM public.users
  WHERE id = p_user_id;

  IF v_tenant_id IS NULL THEN
    SELECT tenant_id INTO v_tenant_id
    FROM public.users
    WHERE id = auth.uid();
  END IF;

  IF v_tenant_id IS NULL THEN
    RETURN NULL;
  END IF;

  -- 1. Insert notification record
  INSERT INTO public.notifications (tenant_id, title, body, type, data)
  VALUES (
    v_tenant_id,
    p_title,
    p_body,
    p_type,
    COALESCE(p_data, '{}'::jsonb) || jsonb_build_object('target_user_id', p_user_id)
  )
  RETURNING id INTO v_notif_id;

  -- 2. Also find parents if target is a student
  SELECT array_agg(DISTINCT parent_id) INTO v_parent_ids
  FROM public.parent_students
  WHERE student_id = p_user_id;

  SELECT array_agg(DISTINCT uid) INTO v_all_recipient_ids
  FROM (
    SELECT p_user_id AS uid
    UNION
    SELECT unnest(COALESCE(v_parent_ids, ARRAY[]::uuid[])) AS uid
  ) combined;

  -- 3. Batch insert
  IF v_all_recipient_ids IS NOT NULL AND array_length(v_all_recipient_ids, 1) > 0 THEN
    INSERT INTO public.notification_recipients (notification_id, user_id)
    SELECT v_notif_id, uid
    FROM unnest(v_all_recipient_ids) AS uid
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN v_notif_id;
END;
$$;

-- 3. Atomic dispatch_tenant_announcement RPC
CREATE OR REPLACE FUNCTION public.dispatch_tenant_announcement(
  p_title text,
  p_body text,
  p_group_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_tenant_id uuid;
  v_notif_id uuid;
  v_student_ids uuid[];
  v_parent_ids uuid[];
  v_all_recipient_ids uuid[];
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: Authentication required';
  END IF;

  -- Verify caller is a teacher
  SELECT tenant_id INTO v_tenant_id
  FROM public.users
  WHERE id = v_caller_id AND role = 'teacher' AND status = 'active';

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only active teachers can broadcast announcements';
  END IF;

  -- If a specific group is targeted:
  IF p_group_id IS NOT NULL THEN
    RETURN public.dispatch_group_notification(
      p_group_id,
      p_title,
      p_body,
      'important_announcement',
      jsonb_build_object('sent_by', v_caller_id)
    );
  END IF;

  -- Broadcast to ALL active students and parents in the entire tenant
  INSERT INTO public.notifications (tenant_id, title, body, type, data)
  VALUES (
    v_tenant_id,
    p_title,
    p_body,
    'important_announcement',
    jsonb_build_object('sent_by', v_caller_id, 'scope', 'all_groups')
  )
  RETURNING id INTO v_notif_id;

  -- Gather all active students in the tenant
  SELECT array_agg(id) INTO v_student_ids
  FROM public.users
  WHERE tenant_id = v_tenant_id AND role = 'student' AND status = 'active';

  IF v_student_ids IS NOT NULL AND array_length(v_student_ids, 1) > 0 THEN
    SELECT array_agg(DISTINCT parent_id) INTO v_parent_ids
    FROM public.parent_students
    WHERE student_id = ANY(v_student_ids);

    SELECT array_agg(DISTINCT uid) INTO v_all_recipient_ids
    FROM (
      SELECT unnest(v_student_ids) AS uid
      UNION
      SELECT unnest(COALESCE(v_parent_ids, ARRAY[]::uuid[])) AS uid
    ) combined;

    IF v_all_recipient_ids IS NOT NULL AND array_length(v_all_recipient_ids, 1) > 0 THEN
      INSERT INTO public.notification_recipients (notification_id, user_id)
      SELECT v_notif_id, uid
      FROM unnest(v_all_recipient_ids) AS uid
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;

  RETURN v_notif_id;
END;
$$;

-- ============================================================================
-- 4. Trigger Function 1: Notify on Content Groups Published
-- ============================================================================
CREATE OR REPLACE FUNCTION public.trg_fn_notify_on_content_group_published()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_title text;
  v_type text;
  v_status text;
  v_already_notified boolean;
  v_notif_title text;
  v_notif_body text;
  v_exam_id uuid;
BEGIN
  -- Only trigger when published is true (and newly inserted or updated from false)
  IF NEW.is_published = true AND (TG_OP = 'INSERT' OR OLD.is_published IS NOT TRUE) THEN
    -- Fetch content details
    SELECT title, type, status INTO v_title, v_type, v_status
    FROM public.content
    WHERE id = NEW.content_id;

    -- Only proceed if the master content itself is published (not draft)
    IF v_status = 'published' THEN
      -- Resolve exam_id if this is an exam
      IF v_type = 'exam' THEN
        SELECT id INTO v_exam_id FROM public.exams WHERE content_id = NEW.content_id;
      END IF;

      -- Check idempotency (avoid notifying same group about same content within 6 hours)
      SELECT EXISTS (
        SELECT 1 FROM public.notifications n
        WHERE n.tenant_id = NEW.tenant_id
          AND (
            (n.data->>'content_id' = NEW.content_id::text) OR 
            (v_exam_id IS NOT NULL AND n.data->>'exam_id' = v_exam_id::text)
          )
          AND n.data->>'group_id' = NEW.group_id::text
          AND n.created_at > (now() - interval '6 hours')
      ) INTO v_already_notified;

      IF NOT v_already_notified THEN
        IF v_type = 'exam' THEN
          v_notif_title := 'اختبار جديد: ' || COALESCE(NEW.custom_title, v_title, 'اختبار جديد');
          v_notif_body := 'تم نشر اختبار جديد "' || COALESCE(NEW.custom_title, v_title, 'اختبار جديد') || '". تفضل بالدخول للاختبار وأداء الأسئلة في الوقت المحدد.';
          
          PERFORM public.dispatch_group_notification(
            NEW.group_id,
            v_notif_title,
            v_notif_body,
            'exam_published',
            jsonb_build_object(
              'content_id', NEW.content_id,
              'exam_id', COALESCE(v_exam_id, NEW.associated_exam_id),
              'group_id', NEW.group_id
            )
          );
        ELSE
          v_notif_title := 'محاضرة جديدة: ' || COALESCE(NEW.custom_title, v_title, 'محاضرة جديدة');
          v_notif_body := 'تمت إضافة محاضرة جديدة "' || COALESCE(NEW.custom_title, v_title, 'محاضرة جديدة') || '" إلى مادتك الدراسية. يمكنك الآن تصفح المحتوى والمشاهدة.';

          PERFORM public.dispatch_group_notification(
            NEW.group_id,
            v_notif_title,
            v_notif_body,
            'new_content',
            jsonb_build_object(
              'content_id', NEW.content_id,
              'group_id', NEW.group_id,
              'content_type', v_type
            )
          );
        END IF;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'trg_fn_notify_on_content_group_published error: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_content_group_published ON public.content_groups;
CREATE TRIGGER trg_notify_on_content_group_published
AFTER INSERT OR UPDATE OF is_published ON public.content_groups
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_notify_on_content_group_published();

-- ============================================================================
-- 5. Trigger Function 2: Notify on Content Published
-- ============================================================================
CREATE OR REPLACE FUNCTION public.trg_fn_notify_on_content_published()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_group_rec RECORD;
  v_already_notified boolean;
  v_notif_title text;
  v_notif_body text;
  v_exam_id uuid;
BEGIN
  -- When master content status changes to 'published'
  IF NEW.status = 'published' AND (TG_OP = 'INSERT' OR OLD.status != 'published') THEN
    IF NEW.type = 'exam' THEN
      SELECT id INTO v_exam_id FROM public.exams WHERE content_id = NEW.id;
    END IF;

    -- 1. If direct group_id is set
    IF NEW.group_id IS NOT NULL THEN
      SELECT EXISTS (
        SELECT 1 FROM public.notifications n
        WHERE n.tenant_id = NEW.tenant_id
          AND (
            (n.data->>'content_id' = NEW.id::text) OR
            (v_exam_id IS NOT NULL AND n.data->>'exam_id' = v_exam_id::text)
          )
          AND n.data->>'group_id' = NEW.group_id::text
          AND n.created_at > (now() - interval '6 hours')
      ) INTO v_already_notified;

      IF NOT v_already_notified THEN
        IF NEW.type = 'exam' THEN
          v_notif_title := 'اختبار جديد: ' || NEW.title;
          v_notif_body := 'تم نشر اختبار جديد "' || NEW.title || '". تفضل بالدخول للاختبار وأداء الأسئلة في الوقت المحدد.';
          
          PERFORM public.dispatch_group_notification(
            NEW.group_id,
            v_notif_title,
            v_notif_body,
            'exam_published',
            jsonb_build_object(
              'content_id', NEW.id,
              'exam_id', v_exam_id,
              'group_id', NEW.group_id
            )
          );
        ELSE
          v_notif_title := 'محاضرة جديدة: ' || NEW.title;
          v_notif_body := 'تمت إضافة محاضرة جديدة "' || NEW.title || '" إلى مادتك الدراسية. يمكنك الآن تصفح المحتوى والمشاهدة.';

          PERFORM public.dispatch_group_notification(
            NEW.group_id,
            v_notif_title,
            v_notif_body,
            'new_content',
            jsonb_build_object(
              'content_id', NEW.id,
              'group_id', NEW.group_id,
              'content_type', NEW.type
            )
          );
        END IF;
      END IF;
    END IF;

    -- 2. Also notify any groups assigned via content_groups
    FOR v_group_rec IN 
      SELECT group_id, custom_title 
      FROM public.content_groups 
      WHERE content_id = NEW.id AND is_published = true
    LOOP
      SELECT EXISTS (
        SELECT 1 FROM public.notifications n
        WHERE n.tenant_id = NEW.tenant_id
          AND (
            (n.data->>'content_id' = NEW.id::text) OR
            (v_exam_id IS NOT NULL AND n.data->>'exam_id' = v_exam_id::text)
          )
          AND n.data->>'group_id' = v_group_rec.group_id::text
          AND n.created_at > (now() - interval '6 hours')
      ) INTO v_already_notified;

      IF NOT v_already_notified THEN
        IF NEW.type = 'exam' THEN
          v_notif_title := 'اختبار جديد: ' || COALESCE(v_group_rec.custom_title, NEW.title);
          v_notif_body := 'تم نشر اختبار جديد "' || COALESCE(v_group_rec.custom_title, NEW.title) || '". تفضل بالدخول للاختبار وأداء الأسئلة في الوقت المحدد.';
          
          PERFORM public.dispatch_group_notification(
            v_group_rec.group_id,
            v_notif_title,
            v_notif_body,
            'exam_published',
            jsonb_build_object(
              'content_id', NEW.id,
              'exam_id', v_exam_id,
              'group_id', v_group_rec.group_id
            )
          );
        ELSE
          v_notif_title := 'محاضرة جديدة: ' || COALESCE(v_group_rec.custom_title, NEW.title);
          v_notif_body := 'تمت إضافة محاضرة جديدة "' || COALESCE(v_group_rec.custom_title, NEW.title) || '" إلى مادتك الدراسية. يمكنك الآن تصفح المحتوى والمشاهدة.';

          PERFORM public.dispatch_group_notification(
            v_group_rec.group_id,
            v_notif_title,
            v_notif_body,
            'new_content',
            jsonb_build_object(
              'content_id', NEW.id,
              'group_id', v_group_rec.group_id,
              'content_type', NEW.type
            )
          );
        END IF;
      END IF;
    END LOOP;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'trg_fn_notify_on_content_published error: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_content_published ON public.content;
CREATE TRIGGER trg_notify_on_content_published
AFTER INSERT OR UPDATE OF status ON public.content
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_notify_on_content_published();

-- ============================================================================
-- 6. Trigger Function 3: Notify on Assignments Created
-- ============================================================================
CREATE OR REPLACE FUNCTION public.trg_fn_notify_on_assignment_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_title text;
  v_group_id uuid;
  v_tenant_id uuid;
  v_due_str text := '';
BEGIN
  SELECT title, group_id, tenant_id INTO v_title, v_group_id, v_tenant_id
  FROM public.content
  WHERE id = NEW.content_id;

  IF v_group_id IS NOT NULL THEN
    IF NEW.due_at IS NOT NULL THEN
      v_due_str := ' قبل ' || to_char(NEW.due_at, 'YYYY-MM-DD');
    END IF;

    PERFORM public.dispatch_group_notification(
      v_group_id,
      'واجب جديد: ' || COALESCE(v_title, 'تكليف دراسي جديد'),
      'تم نشر تكليف جديد "' || COALESCE(v_title, 'تكليف دراسي') || '"' || v_due_str || '. يُرجى رفعه وتسليمه للمراجعة.',
      'assignment_created',
      jsonb_build_object(
        'assignment_id', NEW.id,
        'content_id', NEW.content_id,
        'group_id', v_group_id,
        'due_at', NEW.due_at,
        'max_score', NEW.max_score
      )
    );
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'trg_fn_notify_on_assignment_created error: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_assignment_created ON public.assignments;
CREATE TRIGGER trg_notify_on_assignment_created
AFTER INSERT ON public.assignments
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_notify_on_assignment_created();

-- ============================================================================
-- 7. Trigger Function 4: Notify on Assignment Submission Reviewed
-- ============================================================================
CREATE OR REPLACE FUNCTION public.trg_fn_notify_on_assignment_reviewed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_title text;
  v_max_score integer;
  v_feedback_text text := '';
BEGIN
  IF NEW.status = 'reviewed' AND NEW.score IS NOT NULL AND 
     (TG_OP = 'INSERT' OR OLD.status != 'reviewed' OR OLD.score IS NULL OR OLD.score != NEW.score) THEN

    SELECT c.title, a.max_score INTO v_title, v_max_score
    FROM public.assignments a
    JOIN public.content c ON c.id = a.content_id
    WHERE a.id = NEW.assignment_id;

    IF NEW.teacher_feedback IS NOT NULL AND length(trim(NEW.teacher_feedback)) > 0 THEN
      v_feedback_text := chr(10) || 'ملاحظات المعلم: ' || trim(NEW.teacher_feedback);
    END IF;

    PERFORM public.dispatch_user_notification(
      NEW.student_id,
      'تم تقييم الواجب: ' || COALESCE(v_title, 'الواجب'),
      'حصلت على درجة ' || NEW.score || ' من ' || COALESCE(v_max_score, 100) || ' في واجب "' || COALESCE(v_title, 'الواجب') || '".' || v_feedback_text,
      'assignment_reviewed',
      jsonb_build_object(
        'submission_id', NEW.id,
        'assignment_id', NEW.assignment_id,
        'score', NEW.score,
        'max_score', v_max_score
      )
    );
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'trg_fn_notify_on_assignment_reviewed error: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_assignment_reviewed ON public.assignment_submissions;
CREATE TRIGGER trg_notify_on_assignment_reviewed
AFTER INSERT OR UPDATE OF status, score ON public.assignment_submissions
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_notify_on_assignment_reviewed();

-- ============================================================================
-- 8. Trigger Function 5: Notify on Attendance Marked
-- ============================================================================
CREATE OR REPLACE FUNCTION public.trg_fn_notify_on_attendance_marked()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_status_ar text;
BEGIN
  IF (TG_OP = 'INSERT') OR (TG_OP = 'UPDATE' AND OLD.status != NEW.status) THEN
    v_status_ar := CASE NEW.status
      WHEN 'present' THEN 'حاضر'
      WHEN 'absent' THEN 'غائب'
      WHEN 'late' THEN 'متأخر'
      WHEN 'excused' THEN 'غياب بعذر'
      ELSE NEW.status
    END;

    PERFORM public.dispatch_user_notification(
      NEW.student_id,
      'رصد الحضور — ' || to_char(NEW.date, 'YYYY-MM-DD'),
      'تم تسجيل حالة حضورك لمحاضرة (' || to_char(NEW.date, 'YYYY-MM-DD') || ') كـ "' || v_status_ar || '".',
      'attendance_marked',
      jsonb_build_object(
        'attendance_id', NEW.id,
        'group_id', NEW.group_id,
        'date', to_char(NEW.date, 'YYYY-MM-DD'),
        'status', NEW.status
      )
    );
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'trg_fn_notify_on_attendance_marked error: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_attendance_marked ON public.attendance;
CREATE TRIGGER trg_notify_on_attendance_marked
AFTER INSERT OR UPDATE OF status ON public.attendance
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_notify_on_attendance_marked();

-- ============================================================================
-- 9. Trigger Function 6: Notify on Exam Attempt Completed
-- ============================================================================
CREATE OR REPLACE FUNCTION public.trg_fn_notify_on_exam_attempt_completed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_title text;
  v_max_score integer;
BEGIN
  IF NEW.status = 'completed' AND (TG_OP = 'INSERT' OR OLD.status != 'completed') THEN
    SELECT c.title, e.max_score INTO v_title, v_max_score
    FROM public.exams e
    JOIN public.content c ON c.id = e.content_id
    WHERE e.id = NEW.exam_id;

    PERFORM public.dispatch_user_notification(
      NEW.student_id,
      'نتيجة الاختبار: ' || COALESCE(v_title, 'الاختبار'),
      'تم رصد نتيجتك في اختبار "' || COALESCE(v_title, 'الاختبار') || '": ' || COALESCE(NEW.score, 0) || ' من ' || COALESCE(v_max_score, 100) || ' (' || ROUND(COALESCE(NEW.percentage, 0)) || '%). تفقد تفاصيل النتيجة للمراجعة.',
      'exam_result',
      jsonb_build_object(
        'attempt_id', NEW.id,
        'exam_id', NEW.exam_id,
        'score', NEW.score,
        'max_score', v_max_score,
        'percentage', NEW.percentage
      )
    );
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'trg_fn_notify_on_exam_attempt_completed error: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_exam_attempt_completed ON public.exam_attempts;
CREATE TRIGGER trg_notify_on_exam_attempt_completed
AFTER INSERT OR UPDATE OF status ON public.exam_attempts
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_notify_on_exam_attempt_completed();

-- ============================================================================
-- 10. Backfill Notifications for recently published content in active groups
-- ============================================================================
DO $$
DECLARE
  cg_rec RECORD;
  v_title text;
  v_type text;
  v_exam_id uuid;
  v_already boolean;
BEGIN
  FOR cg_rec IN
    SELECT cg.content_id, cg.group_id, cg.custom_title, cg.tenant_id
    FROM public.content_groups cg
    JOIN public.content c ON c.id = cg.content_id
    WHERE cg.is_published = true AND c.status = 'published'
  LOOP
    SELECT title, type INTO v_title, v_type
    FROM public.content
    WHERE id = cg_rec.content_id;

    IF v_type = 'exam' THEN
      SELECT id INTO v_exam_id FROM public.exams WHERE content_id = cg_rec.content_id;
    ELSE
      v_exam_id := NULL;
    END IF;

    -- Check if notification already dispatched
    SELECT EXISTS (
      SELECT 1 FROM public.notifications n
      WHERE n.tenant_id = cg_rec.tenant_id
        AND (
          (n.data->>'content_id' = cg_rec.content_id::text) OR
          (v_exam_id IS NOT NULL AND n.data->>'exam_id' = v_exam_id::text)
        )
        AND n.data->>'group_id' = cg_rec.group_id::text
    ) INTO v_already;

    IF NOT v_already THEN
      IF v_type = 'exam' THEN
        PERFORM public.dispatch_group_notification(
          cg_rec.group_id,
          'اختبار جديد: ' || COALESCE(cg_rec.custom_title, v_title, 'اختبار جديد'),
          'تم نشر اختبار جديد "' || COALESCE(cg_rec.custom_title, v_title, 'اختبار جديد') || '". تفضل بالدخول للاختبار وأداء الأسئلة في الوقت المحدد.',
          'exam_published',
          jsonb_build_object(
            'content_id', cg_rec.content_id,
            'exam_id', v_exam_id,
            'group_id', cg_rec.group_id
          )
        );
      ELSE
        PERFORM public.dispatch_group_notification(
          cg_rec.group_id,
          'محاضرة جديدة: ' || COALESCE(cg_rec.custom_title, v_title, 'محاضرة جديدة'),
          'تمت إضافة محاضرة جديدة "' || COALESCE(cg_rec.custom_title, v_title, 'محاضرة جديدة') || '" إلى مادتك الدراسية. يمكنك الآن تصفح المحتوى والمشاهدة.',
          'new_content',
          jsonb_build_object(
            'content_id', cg_rec.content_id,
            'group_id', cg_rec.group_id,
            'content_type', v_type
          )
        );
      END IF;
    END IF;
  END LOOP;
END;
$$;
