-- ==============================================================================
-- Migration 0092: Self-Healing Exam Versions, Auto-Sync Triggers, & Exam Separation
-- ==============================================================================
-- 1. Repair any existing published exams where exam_versions status remained 'draft'
-- 2. Add automatic sync triggers between content, content_groups, and exam_versions
-- 3. Upgrade start_exam & get_exam_details with resilient self-healing version discovery
-- 4. Separate General Exams vs Lecture Exams in get_student_exams RPC
-- ==============================================================================

-- 1. Immediate Data Repair for All Published Exams
UPDATE public.exam_versions ev
SET status = 'published', published_at = COALESCE(ev.published_at, now())
FROM public.exams e
JOIN public.content c ON c.id = e.content_id
WHERE ev.exam_id = e.id
  AND c.status = 'published'
  AND ev.status != 'published';

-- Also repair any exams linked to published lectures via content_groups
UPDATE public.exam_versions ev
SET status = 'published', published_at = COALESCE(ev.published_at, now())
WHERE ev.status != 'published'
  AND ev.exam_id IN (
    SELECT cg.associated_exam_id FROM public.content_groups cg WHERE cg.is_published = true AND cg.associated_exam_id IS NOT NULL
    UNION
    SELECT cg.prerequisite_exam_id FROM public.content_groups cg WHERE cg.is_published = true AND cg.prerequisite_exam_id IS NOT NULL
  );

UPDATE public.content c
SET status = 'published', published_at = COALESCE(c.published_at, now())
FROM public.exams e
WHERE c.id = e.content_id
  AND c.status != 'published'
  AND e.id IN (
    SELECT cg.associated_exam_id FROM public.content_groups cg WHERE cg.is_published = true AND cg.associated_exam_id IS NOT NULL
    UNION
    SELECT cg.prerequisite_exam_id FROM public.content_groups cg WHERE cg.is_published = true AND cg.prerequisite_exam_id IS NOT NULL
  );

-- 2. Auto-Sync Trigger: Keep exam_versions status in sync when content is published
CREATE OR REPLACE FUNCTION public.sync_exam_version_status_on_publish()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.type = 'exam' AND NEW.status = 'published' AND (OLD.status IS DISTINCT FROM NEW.status) THEN
    UPDATE public.exam_versions
    SET status = 'published', published_at = COALESCE(published_at, now())
    WHERE exam_id = (SELECT id FROM public.exams WHERE content_id = NEW.id)
      AND status != 'published';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_exam_version_status ON public.content;
CREATE TRIGGER trg_sync_exam_version_status
AFTER UPDATE OF status ON public.content
FOR EACH ROW
EXECUTE FUNCTION public.sync_exam_version_status_on_publish();

-- Auto-Sync Trigger: When an exam is linked to a published lecture, ensure it is published
CREATE OR REPLACE FUNCTION public.sync_lecture_exam_version_on_link()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.is_published = true THEN
    IF NEW.associated_exam_id IS NOT NULL THEN
      UPDATE public.exam_versions
      SET status = 'published', published_at = COALESCE(published_at, now())
      WHERE exam_id = NEW.associated_exam_id AND status != 'published';

      UPDATE public.content c
      SET status = 'published', published_at = COALESCE(c.published_at, now())
      FROM public.exams e
      WHERE e.id = NEW.associated_exam_id AND c.id = e.content_id AND c.status != 'published';
    END IF;

    IF NEW.prerequisite_exam_id IS NOT NULL THEN
      UPDATE public.exam_versions
      SET status = 'published', published_at = COALESCE(published_at, now())
      WHERE exam_id = NEW.prerequisite_exam_id AND status != 'published';

      UPDATE public.content c
      SET status = 'published', published_at = COALESCE(c.published_at, now())
      FROM public.exams e
      WHERE e.id = NEW.prerequisite_exam_id AND c.id = e.content_id AND c.status != 'published';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_lecture_exam_link ON public.content_groups;
CREATE TRIGGER trg_sync_lecture_exam_link
AFTER INSERT OR UPDATE OF is_published, associated_exam_id, prerequisite_exam_id ON public.content_groups
FOR EACH ROW
EXECUTE FUNCTION public.sync_lecture_exam_version_on_link();

-- 3. Upgrade start_exam with Self-Healing Version Selection
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

    -- 1. Try to fetch the latest published version
    SELECT * INTO v_version
    FROM public.exam_versions
    WHERE exam_id = p_exam_id AND status = 'published'
    ORDER BY version_number DESC
    LIMIT 1;

    -- 2. Self-Healing Fallback: If exam is published but version remained draft, promote latest version
    IF v_version.id IS NULL THEN
      SELECT * INTO v_version
      FROM public.exam_versions
      WHERE exam_id = p_exam_id
      ORDER BY version_number DESC
      LIMIT 1;

      IF v_version.id IS NOT NULL THEN
        UPDATE public.exam_versions
        SET status = 'published', published_at = COALESCE(published_at, now())
        WHERE id = v_version.id;
      ELSE
        RAISE EXCEPTION 'EXAM_NOT_FOUND: No published version available for this exam';
      END IF;
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

-- 4. Upgrade get_exam_details with Resilient Version Discovery
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
    RAISE EXCEPTION 'NOT_AUTHORIZED: User profile not found';
  END IF;

  v_is_teacher := (v_caller_role = 'teacher');

  SELECT * INTO v_exam FROM public.exams WHERE id = p_exam_id AND tenant_id = v_caller_tenant;
  IF v_exam.id IS NULL THEN
    RAISE EXCEPTION 'EXAM_NOT_FOUND: Exam does not exist in your tenant';
  END IF;

  SELECT * INTO v_content FROM public.content WHERE id = v_exam.content_id;

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

    -- Self-healing version fallback for published exams
    IF v_version.id IS NULL AND v_content.status = 'published' THEN
      SELECT * INTO v_version FROM public.exam_versions
      WHERE exam_id = p_exam_id ORDER BY version_number DESC LIMIT 1;

      IF v_version.id IS NOT NULL THEN
        UPDATE public.exam_versions
        SET status = 'published', published_at = COALESCE(published_at, now())
        WHERE id = v_version.id;
      END IF;
    END IF;
  END IF;

  IF v_version.id IS NOT NULL THEN
    SELECT COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', ec.id, 'exam_version_id', ec.exam_version_id, 'title', ec.title,
        'context_text', ec.context_text, 'image_url', ec.image_url,
        'image_meta', ec.image_meta, 'sort_order', ec.sort_order
      ) ORDER BY ec.sort_order
    ), '[]'::jsonb) INTO v_contexts
    FROM public.exam_contexts ec WHERE ec.exam_version_id = v_version.id;

    SELECT COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', q.id, 'exam_version_id', q.exam_version_id,
        'question_text', q.question_text, 'question_type', q.question_type,
        'points', q.points, 'sort_order', q.sort_order,
        'image_url', q.image_url, 'image_meta', q.image_meta,
        'context_id', q.context_id,
        'options', (
          SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
              'id', qo.id, 'question_id', qo.question_id,
              'option_text', qo.option_text, 'sort_order', qo.sort_order,
              'image_url', qo.image_url, 'image_meta', qo.image_meta,
              'is_correct', CASE WHEN v_is_teacher THEN qo.is_correct ELSE null END
            ) ORDER BY qo.sort_order
          ), '[]'::jsonb)
          FROM public.question_options qo WHERE qo.question_id = q.id
        )
      ) ORDER BY q.sort_order
    ), '[]'::jsonb) INTO v_questions
    FROM public.exam_questions q WHERE q.exam_version_id = v_version.id;
  END IF;

  IF NOT v_is_teacher THEN
    SELECT jsonb_build_object(
      'id', ea.id, 'status', ea.status, 'score', ea.score,
      'percentage', ea.percentage, 'started_at', ea.started_at,
      'submitted_at', ea.submitted_at
    ) INTO v_latest_attempt
    FROM public.exam_attempts ea
    WHERE ea.exam_id = p_exam_id AND ea.student_id = v_caller_id
    ORDER BY ea.started_at DESC LIMIT 1;

    SELECT count(*), max(score) INTO v_attempts_count, v_best_score
    FROM public.exam_attempts
    WHERE exam_id = p_exam_id AND student_id = v_caller_id AND status = 'submitted';
  END IF;

  RETURN jsonb_build_object(
    'id', v_exam.id,
    'content_id', v_content.id,
    'title', v_content.title,
    'description', v_content.description,
    'group_id', v_content.group_id,
    'group_name', v_group_name,
    'status', v_content.status,
    'duration_minutes', v_exam.duration_minutes,
    'max_score', v_exam.max_score,
    'passing_score', v_exam.passing_score,
    'shuffle_questions', v_exam.shuffle_questions,
    'show_result', v_exam.show_result,
    'allow_retake', v_exam.allow_retake,
    'start_at', v_exam.start_at,
    'end_at', v_exam.end_at,
    'folder_id', v_exam.folder_id,
    'created_at', v_exam.created_at,
    'version_id', v_version.id,
    'version_number', v_version.version_number,
    'version_status', v_version.status,
    'contexts', v_contexts,
    'questions', v_questions,
    'latest_attempt', v_latest_attempt,
    'attempts_count', v_attempts_count,
    'best_score', v_best_score
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_exam_details(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_exam_details(uuid) TO authenticated;

-- 5. Separate General Exams vs Lecture Exams in get_student_exams
-- Excludes exams that are bound as lecture prerequisites or lecture quizzes so they only appear in the lecture
CREATE OR REPLACE FUNCTION public.get_student_exams(
    p_page int DEFAULT 0,
    p_page_size int DEFAULT 15
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id uuid;
    v_tenant_id uuid;
    v_user_role text;
    v_result jsonb;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: authentication required';
    END IF;

    SELECT role, tenant_id INTO v_user_role, v_tenant_id
    FROM public.users
    WHERE id = v_user_id;

    IF v_tenant_id IS NULL OR (v_user_role != 'student' AND v_user_role != 'teacher') THEN
        RAISE EXCEPTION 'Unauthorized: user is not a student in an active tenant';
    END IF;

    WITH student_groups AS (
        SELECT 
            gm.group_id,
            gm.joined_at,
            g.previous_content_access,
            g.name AS group_name
        FROM public.group_members gm
        JOIN public.groups g ON g.id = gm.group_id
        WHERE gm.student_id = v_user_id
          AND gm.status = 'active'
          AND g.tenant_id = v_tenant_id
    ),
    accessible_exams AS (
        -- 1) Group-assigned General exams ONLY (excludes lecture-bound exams)
        SELECT DISTINCT
            e.id,
            e.content_id,
            e.tenant_id,
            e.duration_minutes,
            e.max_score,
            e.passing_score,
            e.shuffle_questions,
            e.show_result,
            e.allow_retake,
            e.start_at,
            e.end_at,
            e.created_at,
            e.updated_at,
            e.folder_id,
            c.title AS exam_title,
            c.group_id AS content_group_id,
            c.description AS content_description,
            c.status AS content_status,
            sg.group_name
        FROM public.exams e
        JOIN public.content c ON c.id = e.content_id
        JOIN student_groups sg ON sg.group_id = c.group_id
        WHERE e.tenant_id = v_tenant_id
          AND c.status = 'published'
          AND (
            c.published_at IS NULL 
            OR sg.joined_at <= c.published_at 
            OR sg.previous_content_access = 'allow'
          )
          -- Exclude exams that are strictly lecture quizzes or prerequisites
          AND NOT EXISTS (
            SELECT 1 FROM public.content_groups cg
            WHERE (cg.associated_exam_id = e.id OR cg.prerequisite_exam_id = e.id)
          )
          AND NOT EXISTS (
            SELECT 1 FROM public.lesson_exams le
            WHERE le.exam_id = e.id
          )
          AND NOT EXISTS (
            SELECT 1 FROM public.content c2
            WHERE (c2.associated_exam_id = e.id OR c2.prerequisite_exam_id = e.id)
          )
        UNION
        -- 2) Tenant-wide General exams (group_id IS NULL)
        SELECT DISTINCT
            e.id,
            e.content_id,
            e.tenant_id,
            e.duration_minutes,
            e.max_score,
            e.passing_score,
            e.shuffle_questions,
            e.show_result,
            e.allow_retake,
            e.start_at,
            e.end_at,
            e.created_at,
            e.updated_at,
            e.folder_id,
            c.title AS exam_title,
            c.group_id AS content_group_id,
            c.description AS content_description,
            c.status AS content_status,
            'All Groups' AS group_name
        FROM public.exams e
        JOIN public.content c ON c.id = e.content_id
        WHERE e.tenant_id = v_tenant_id
          AND c.group_id IS NULL
          AND c.status = 'published'
          AND EXISTS (SELECT 1 FROM student_groups)
          AND NOT EXISTS (
            SELECT 1 FROM public.content_groups cg
            WHERE (cg.associated_exam_id = e.id OR cg.prerequisite_exam_id = e.id)
          )
          AND NOT EXISTS (
            SELECT 1 FROM public.lesson_exams le
            WHERE le.exam_id = e.id
          )
          AND NOT EXISTS (
            SELECT 1 FROM public.content c2
            WHERE (c2.associated_exam_id = e.id OR c2.prerequisite_exam_id = e.id)
          )
    ),
    paged_exams AS (
        SELECT *
        FROM accessible_exams
        ORDER BY created_at DESC
        LIMIT p_page_size
        OFFSET (p_page * p_page_size)
    ),
    exam_stats AS (
        SELECT 
            pe.id AS exam_id,
            COALESCE((
                SELECT count(*)::int
                FROM public.exam_questions eq
                WHERE eq.exam_version_id = (
                    SELECT ev.id
                    FROM public.exam_versions ev
                    WHERE ev.exam_id = pe.id
                    ORDER BY ev.version_number DESC
                    LIMIT 1
                )
            ), 0) AS questions_count
        FROM paged_exams pe
    ),
    student_attempts_data AS (
        SELECT DISTINCT ON (ea.exam_id)
            ea.exam_id,
            ea.id AS attempt_id,
            ea.status AS attempt_status,
            ea.score,
            ea.percentage,
            ea.started_at,
            ea.submitted_at,
            ea.created_at,
            COALESCE((
                SELECT count(DISTINCT sa.question_id)::int
                FROM public.student_answers sa
                WHERE sa.attempt_id = ea.id
            ), 0) AS answered_questions_count
        FROM public.exam_attempts ea
        WHERE ea.student_id = v_user_id
          AND ea.exam_id IN (SELECT id FROM paged_exams)
        ORDER BY ea.exam_id, ea.created_at DESC
    )
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', pe.id,
                'content_id', pe.content_id,
                'group_id', pe.content_group_id,
                'group_name', pe.group_name,
                'title', pe.exam_title,
                'description', pe.content_description,
                'status', pe.content_status,
                'duration_minutes', pe.duration_minutes,
                'max_score', pe.max_score,
                'passing_score', pe.passing_score,
                'shuffle_questions', pe.shuffle_questions,
                'show_result', pe.show_result,
                'allow_retake', pe.allow_retake,
                'start_at', pe.start_at,
                'end_at', pe.end_at,
                'folder_id', pe.folder_id,
                'created_at', pe.created_at,
                'updated_at', pe.updated_at,
                'questions_count', COALESCE(es.questions_count, 0),
                'attempts_count', CASE WHEN sad.attempt_id IS NOT NULL THEN 1 ELSE 0 END,
                'has_active_attempt', CASE WHEN sad.attempt_status = 'in_progress' THEN true ELSE false END,
                'has_passed', CASE WHEN sad.score IS NOT NULL AND pe.passing_score IS NOT NULL AND sad.score >= pe.passing_score THEN true ELSE false END,
                'student_score', sad.score,
                'student_percentage', sad.percentage,
                'latest_attempt_id', sad.attempt_id,
                'latest_attempt_status', sad.attempt_status,
                'answered_questions_count', COALESCE(sad.answered_questions_count, 0)
            )
            ORDER BY pe.created_at DESC
        ),
        '[]'::jsonb
    ) INTO v_result
    FROM paged_exams pe
    LEFT JOIN exam_stats es ON es.exam_id = pe.id
    LEFT JOIN student_attempts_data sad ON sad.exam_id = pe.id;

    RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_student_exams(int, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_student_exams(int, int) TO authenticated;
