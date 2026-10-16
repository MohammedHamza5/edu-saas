-- Migration: 0089_allow_general_and_attached_exams_start.sql
-- Description: Authorize students to take/view exams that are general (tenant-wide)
-- or attached to lectures in any group the student actively belongs to.

-- 1. start_exam
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
  v_started_at timestamptz;
  v_questions jsonb;
  v_contexts jsonb;
  v_is_lecture_exam boolean;
  v_is_late boolean := false;
  v_has_passed boolean := false;
  v_remaining_seconds integer := 0;
  v_event_group_id uuid;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be authenticated';
  END IF;

  SELECT tenant_id INTO v_tenant_id FROM public.users WHERE id = v_student_id AND status = 'active';
  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Active student profile required';
  END IF;

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

  -- فحص هل الامتحان تابع لمحاضرة (واجب أو اختبار اجتياز للدخول للمحاضرة التالية أو مدته 0)
  v_is_lecture_exam :=
    (v_exam.duration_minutes IS NULL OR v_exam.duration_minutes <= 0)
    OR EXISTS (
      SELECT 1 FROM public.lesson_exams le WHERE le.exam_id = p_exam_id
    )
    OR EXISTS (
      SELECT 1 FROM public.content_groups cg
      WHERE cg.associated_exam_id = p_exam_id OR cg.prerequisite_exam_id = p_exam_id
    )
    OR EXISTS (
      SELECT 1 FROM public.content c2
      WHERE c2.associated_exam_id = p_exam_id OR c2.prerequisite_exam_id = p_exam_id
    );

  IF NOT v_is_lecture_exam THEN
    IF v_exam.start_at IS NOT NULL AND now() < v_exam.start_at THEN
      RAISE EXCEPTION 'EXAM_NOT_STARTED: Exam start time is in the future';
    END IF;
    -- الدخول بعد end_at مسموح للامتحانات العامة (متأخر)
    v_is_late := v_exam.end_at IS NOT NULL AND now() > v_exam.end_at;
  END IF;

  -- التحقق من صلاحية الطالب:
  -- 1) إذا كان الامتحان مرتبطاً بمجموعة محددة والطالب عضو نشط فيها
  -- 2) أو إذا كان الامتحان مرتبطاً بمحاضرة في أي مجموعة يكون الطالب عضواً نشطاً فيها
  -- 3) أو إذا كان الامتحان عاماً على مستوى المنصة (v_exam.group_id IS NULL) والطالب عضو نشط في أي مجموعة تابعة لنفس المستأجر
  IF NOT EXISTS (
    SELECT 1 FROM public.group_members gm
    WHERE gm.student_id = v_student_id
      AND gm.status = 'active'
      AND (
        (v_exam.group_id IS NOT NULL AND gm.group_id = v_exam.group_id)
        OR EXISTS (
          SELECT 1 FROM public.content_groups cg
          WHERE (cg.associated_exam_id = p_exam_id OR cg.prerequisite_exam_id = p_exam_id)
            AND cg.group_id = gm.group_id
        )
        OR EXISTS (
          SELECT 1 FROM public.lesson_exams le
          WHERE le.exam_id = p_exam_id
            AND le.group_id = gm.group_id
        )
        OR (
          v_exam.group_id IS NULL
          AND EXISTS (
            SELECT 1 FROM public.groups g
            WHERE g.id = gm.group_id AND g.tenant_id = v_tenant_id
          )
        )
      )
  ) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Student is not an active member of this group';
  END IF;

  -- فحص ما إذا كان الطالب قد اجتاز هذا الامتحان مسبقاً بدرجة النجاح
  SELECT EXISTS (
    SELECT 1 FROM public.exam_attempts
    WHERE exam_id = p_exam_id
      AND student_id = v_student_id
      AND status = 'submitted'
      AND (v_exam.passing_score IS NULL OR score >= v_exam.passing_score)
  ) INTO v_has_passed;

  -- فحص أي محاولة قيد التنفيذ
  SELECT * INTO v_active_attempt
  FROM public.exam_attempts
  WHERE exam_id = p_exam_id AND student_id = v_student_id AND status = 'in_progress';

  IF v_active_attempt.id IS NOT NULL THEN
    -- لا تنتهي محاولات امتحانات المحاضرات نهائياً، أما الامتحانات العامة فتفحص التوقيت
    IF NOT v_is_lecture_exam AND v_exam.duration_minutes > 0
       AND (v_active_attempt.started_at + (v_exam.duration_minutes || ' minutes')::interval) < now() THEN
      UPDATE public.exam_attempts
      SET status = 'expired'
      WHERE id = v_active_attempt.id;
    ELSE
      v_attempt_id := v_active_attempt.id;
      v_started_at := v_active_attempt.started_at;
      SELECT * INTO v_version FROM public.exam_versions WHERE id = v_active_attempt.exam_version_id;
    END IF;
  END IF;

  -- إذا لم تكن هناك محاولة نشطة صالحة: نتحقق من إمكانية بدء محاولة جديدة
  IF v_attempt_id IS NULL THEN
    IF v_is_lecture_exam THEN
      -- امتحان محاضرة: إذا كان الطالب قد اجتازه بالفعل ولا يُسمح بالإعادة، نمنعه
      IF v_has_passed AND NOT v_exam.allow_retake THEN
        RAISE EXCEPTION 'ATTEMPTS_LIMIT_REACHED: You have already passed this lecture exam';
      END IF;
      -- إذا لم يجتزْه الطالب بعد أو مسموح بالإعادة، يُسمح له ببدء محاولة جديدة
    ELSE
      -- امتحان عام: القيود العادية
      IF NOT v_exam.allow_retake AND EXISTS (
        SELECT 1 FROM public.exam_attempts
        WHERE exam_id = p_exam_id AND student_id = v_student_id AND status IN ('submitted', 'expired')
      ) THEN
        RAISE EXCEPTION 'ATTEMPTS_LIMIT_REACHED: Retake is not allowed for this exam';
      END IF;
    END IF;

    SELECT * INTO v_version
    FROM public.exam_versions
    WHERE exam_id = p_exam_id AND status = 'published'
    ORDER BY version_number DESC
    LIMIT 1;

    IF v_version.id IS NULL THEN
      RAISE EXCEPTION 'EXAM_NOT_FOUND: No published version available for this exam';
    END IF;

    v_started_at := now();

    INSERT INTO public.exam_attempts (exam_id, exam_version_id, student_id, started_at, status)
    VALUES (p_exam_id, v_version.id, v_student_id, v_started_at, 'in_progress')
    RETURNING id INTO v_attempt_id;

    -- تحديد المجموعة المناسبة لحدث النشاط
    v_event_group_id := COALESCE(
      v_exam.group_id,
      (
        SELECT cg.group_id FROM public.content_groups cg
        WHERE cg.associated_exam_id = p_exam_id
          AND cg.group_id IN (SELECT gm.group_id FROM public.group_members gm WHERE gm.student_id = v_student_id AND gm.status = 'active')
        LIMIT 1
      ),
      (
        SELECT gm.group_id FROM public.group_members gm
        WHERE gm.student_id = v_student_id AND gm.status = 'active'
        LIMIT 1
      )
    );

    INSERT INTO public.activity_events (tenant_id, user_id, group_id, content_id, event_type, metadata)
    VALUES (
      v_tenant_id, v_student_id, v_event_group_id, v_exam.content_id, 'exam_started',
      jsonb_build_object('attempt_id', v_attempt_id, 'version_id', v_version.id)
    );
  END IF;

  SELECT COALESCE(jsonb_agg(ctx_item), '[]'::jsonb) INTO v_contexts
  FROM (
    SELECT ec.id, ec.title, ec.context_text, ec.image_url, ec.image_meta, ec.sort_order
    FROM public.exam_contexts ec
    WHERE ec.exam_version_id = v_version.id
    ORDER BY ec.sort_order
  ) ctx_item;

  -- ⚡ Deterministic seed for shuffled questions per attempt_id
  IF v_exam.shuffle_questions THEN
    PERFORM setseed((abs(hashtext(v_attempt_id::text)) % 2147483647)::double precision / 2147483647.0);
  END IF;

  SELECT COALESCE(jsonb_agg(q_item), '[]'::jsonb) INTO v_questions
  FROM (
    SELECT
      eq.id, eq.question_text, eq.question_type, eq.points, eq.sort_order,
      eq.image_url, eq.image_meta, eq.context_id,
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

  IF NOT v_is_lecture_exam AND COALESCE(v_exam.duration_minutes, 0) > 0 THEN
    v_remaining_seconds := GREATEST(
      1,
      (v_exam.duration_minutes * 60) - FLOOR(EXTRACT(EPOCH FROM (now() - v_started_at)))::integer
    );
  ELSE
    v_remaining_seconds := 0;
  END IF;

  RETURN jsonb_build_object(
    'attempt_id', v_attempt_id,
    'exam_version_id', v_version.id,
    'started_at', COALESCE(v_started_at, now()),
    'duration_minutes', CASE WHEN v_is_lecture_exam THEN 0 ELSE COALESCE(v_exam.duration_minutes, 0) END,
    'remaining_seconds', v_remaining_seconds,
    'server_now', now(),
    'show_result', v_exam.show_result,
    'is_late', v_is_late,
    'contexts', v_contexts,
    'questions', v_questions
  );
END;
$$;

REVOKE ALL ON FUNCTION public.start_exam(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_exam(uuid) TO authenticated;

-- 2. get_exam_details
CREATE OR REPLACE FUNCTION public.get_exam_details(p_exam_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id      uuid := auth.uid();
  v_caller_tenant  uuid;
  v_caller_role    text;
  v_exam           record;
  v_content        record;
  v_group_name     text;
  v_version        record;
  v_questions      jsonb := '[]'::jsonb;
  v_contexts       jsonb := '[]'::jsonb;
  v_latest_attempt jsonb := null;
  v_attempts_count integer := 0;
  v_best_score     integer := null;
  v_is_teacher     boolean := false;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be authenticated';
  END IF;

  SELECT tenant_id, role INTO v_caller_tenant, v_caller_role
  FROM public.users WHERE id = v_caller_id AND status IN ('active', 'pending');

  IF v_caller_tenant IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Active user profile required';
  END IF;

  v_is_teacher := (v_caller_role = 'teacher');

  SELECT * INTO v_exam FROM public.exams WHERE id = p_exam_id;
  IF v_exam.id IS NULL THEN
    RAISE EXCEPTION 'EXAM_NOT_FOUND: Exam does not exist';
  END IF;

  SELECT * INTO v_content FROM public.content WHERE id = v_exam.content_id;

  IF v_exam.tenant_id != v_caller_tenant THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Tenant mismatch';
  END IF;

  IF NOT v_is_teacher THEN
    IF v_content.status != 'published' THEN
      RAISE EXCEPTION 'NOT_AUTHORIZED: Exam is not published';
    END IF;

    IF v_caller_role = 'student' THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.group_members gm
        WHERE gm.student_id = v_caller_id AND gm.status = 'active'
          AND (
            (v_content.group_id IS NOT NULL AND gm.group_id = v_content.group_id)
            OR EXISTS (
              SELECT 1 FROM public.content_groups cg
              WHERE (cg.content_id = v_content.id OR cg.associated_exam_id = p_exam_id OR cg.prerequisite_exam_id = p_exam_id)
                AND cg.group_id = gm.group_id
            )
            OR EXISTS (
              SELECT 1 FROM public.lesson_exams le
              WHERE le.exam_id = p_exam_id
                AND le.group_id = gm.group_id
            )
            OR (
              v_content.group_id IS NULL
              AND EXISTS (
                SELECT 1 FROM public.groups g
                WHERE g.id = gm.group_id AND g.tenant_id = v_caller_tenant
              )
            )
          )
      ) THEN
        RAISE EXCEPTION 'NOT_AUTHORIZED: Student is not an active member of this group';
      END IF;
    ELSIF v_caller_role = 'parent' THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.group_members gm
        JOIN public.parent_students ps ON ps.student_id = gm.student_id
        WHERE ps.parent_id = v_caller_id AND gm.status = 'active'
          AND (
            (v_content.group_id IS NOT NULL AND gm.group_id = v_content.group_id)
            OR EXISTS (
              SELECT 1 FROM public.content_groups cg
              WHERE (cg.content_id = v_content.id OR cg.associated_exam_id = p_exam_id OR cg.prerequisite_exam_id = p_exam_id)
                AND cg.group_id = gm.group_id
            )
            OR EXISTS (
              SELECT 1 FROM public.lesson_exams le
              WHERE le.exam_id = p_exam_id
                AND le.group_id = gm.group_id
            )
            OR (
              v_content.group_id IS NULL
              AND EXISTS (
                SELECT 1 FROM public.groups g
                WHERE g.id = gm.group_id AND g.tenant_id = v_caller_tenant
              )
            )
          )
      ) THEN
        RAISE EXCEPTION 'NOT_AUTHORIZED: Parent is not linked to an active student in this group';
      END IF;
    ELSE
      RAISE EXCEPTION 'NOT_AUTHORIZED';
    END IF;
  END IF;

  IF v_content.group_id IS NOT NULL THEN
    SELECT name INTO v_group_name FROM public.groups WHERE id = v_content.group_id;
  END IF;

  IF v_is_teacher THEN
    SELECT * INTO v_version FROM public.exam_versions
    WHERE exam_id = p_exam_id ORDER BY version_number DESC LIMIT 1;
  ELSE
    SELECT * INTO v_version FROM public.exam_versions
    WHERE exam_id = p_exam_id AND status = 'published' ORDER BY version_number DESC LIMIT 1;
  END IF;

  IF v_version.id IS NOT NULL THEN
    SELECT COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', ec.id, 'exam_version_id', ec.exam_version_id, 'title', ec.title,
        'context_text', ec.context_text, 'image_url', ec.image_url,
        'image_meta', ec.image_meta, 'sort_order', ec.sort_order
      ) ORDER BY ec.sort_order, ec.created_at
    ), '[]'::jsonb)
    INTO v_contexts
    FROM public.exam_contexts ec WHERE ec.exam_version_id = v_version.id;

    SELECT COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', eq.id, 'exam_version_id', eq.exam_version_id,
        'question_text', eq.question_text, 'question_type', eq.question_type,
        'points', eq.points, 'sort_order', eq.sort_order,
        'image_url', eq.image_url, 'image_meta', eq.image_meta,
        'context_id', eq.context_id,
        'options', (
          SELECT COALESCE(jsonb_agg(
            CASE WHEN v_is_teacher THEN
              jsonb_build_object('id', qo.id, 'question_id', qo.question_id,
                'option_text', qo.option_text, 'sort_order', qo.sort_order,
                'is_correct', qo.is_correct, 'image_url', qo.image_url,
                'image_meta', qo.image_meta)
            ELSE
              -- SECURITY: never expose is_correct to students/parents
              jsonb_build_object('id', qo.id, 'question_id', qo.question_id,
                'option_text', qo.option_text, 'sort_order', qo.sort_order,
                'image_url', qo.image_url, 'image_meta', qo.image_meta)
            END ORDER BY qo.sort_order, qo.id
          ), '[]'::jsonb)
          FROM public.question_options qo WHERE qo.question_id = eq.id
        )
      ) ORDER BY eq.sort_order, eq.id
    ), '[]'::jsonb)
    INTO v_questions
    FROM public.exam_questions eq WHERE eq.exam_version_id = v_version.id;
  END IF;

  IF v_caller_role = 'student' THEN
    SELECT count(*), max(score) INTO v_attempts_count, v_best_score
    FROM public.exam_attempts WHERE exam_id = p_exam_id AND student_id = v_caller_id;

    SELECT to_jsonb(a.*) INTO v_latest_attempt
    FROM (
      SELECT id, exam_id, student_id, exam_version_id, started_at, submitted_at,
             score, percentage, status
      FROM public.exam_attempts
      WHERE exam_id = p_exam_id AND student_id = v_caller_id
      ORDER BY started_at DESC LIMIT 1
    ) a;
  END IF;

  RETURN jsonb_build_object(
    'id', v_exam.id, 'content_id', v_exam.content_id, 'tenant_id', v_exam.tenant_id,
    'title', COALESCE(v_content.title, ''), 'description', v_content.description,
    'group_id', v_content.group_id, 'group_name', v_group_name,
    'duration_minutes', v_exam.duration_minutes, 'max_score', v_exam.max_score,
    'passing_score', v_exam.passing_score, 'shuffle_questions', v_exam.shuffle_questions,
    'show_result', v_exam.show_result, 'allow_retake', v_exam.allow_retake,
    'start_at', v_exam.start_at, 'end_at', v_exam.end_at,
    'created_at', v_exam.created_at, 'updated_at', v_exam.updated_at,
    'content', jsonb_build_object(
      'id', v_content.id, 'title', v_content.title, 'description', v_content.description,
      'group_id', v_content.group_id, 'status', v_content.status,
      'groups', jsonb_build_object('name', v_group_name)),
    'active_version', CASE WHEN v_version.id IS NOT NULL THEN
      jsonb_build_object(
        'id', v_version.id, 'exam_id', v_version.exam_id,
        'version_number', v_version.version_number, 'status', v_version.status,
        'created_at', v_version.created_at, 'published_at', v_version.published_at,
        'exam_contexts', v_contexts, 'exam_questions', v_questions)
      ELSE null END,
    'attempts_count', v_attempts_count,
    'my_latest_attempt', v_latest_attempt,
    'my_best_score', v_best_score
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_exam_details(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_exam_details(uuid) TO authenticated;
