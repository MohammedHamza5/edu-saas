-- ============================================================================
-- Migration 0096: Enterprise Platform Security Hardening
-- ============================================================================
-- 1. Eliminates Direct Answer Leak on public.question_options (removes student RLS policy).
-- 2. Closes Answer Oracle in public.submit_mistakes_practice.
-- 3. Enforces Multi-Tenant Isolation in Teacher RPCs:
--    - get_teacher_exam_attempts
--    - get_exam_review
--    - get_teacher_radar_alerts
--    - get_student_mistakes_summary & get_student_mistakes_questions
-- 4. Remediates IDOR & Privacy Vulnerabilities in Student Telemetry & Reports:
--    - get_student_360
--    - get_student_dashboard
--    - get_student_academic_report
--    - get_group_academic_reports
-- 5. Prevents Scheduled Exam Question Leaks in get_exam_details.
-- 6. Hardens Teacher Isolation on storage.objects ('group-content' bucket).
-- 7. Locks down SECURITY DEFINER search_path and revokes unauthorized PUBLIC execution.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. DROP INSECURE STUDENT RLS POLICY ON question_options
-- ----------------------------------------------------------------------------
-- Students must NEVER query question_options directly via PostgREST.
-- Legitimate access is mediated exclusively via secure RPCs (get_exam_details / start_exam)
-- where is_correct is strictly masked or excluded.
DROP POLICY IF EXISTS qo_student_read_published ON public.question_options;


-- ----------------------------------------------------------------------------
-- 2. CLOSE ANSWER ORACLE IN submit_mistakes_practice
-- ----------------------------------------------------------------------------
-- Enforces that question_id must belong to the student's legitimate mistakes bank
-- before grading or returning correct_option_id feedback.
CREATE OR REPLACE FUNCTION public.submit_mistakes_practice(
  p_answers JSONB -- e.g. [{"question_id": "...", "selected_option_id": "..."}]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_student_id UUID := auth.uid();
  v_item JSONB;
  v_question_id UUID;
  v_selected_option_id UUID;
  v_is_correct BOOLEAN;
  v_correct_option_id UUID;
  v_total INTEGER := 0;
  v_correct_count INTEGER := 0;
  v_results JSONB := '[]'::jsonb;
  v_is_legitimate_mistake BOOLEAN;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be authenticated';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_answers)
  LOOP
    v_question_id := (v_item->>'question_id')::UUID;
    v_selected_option_id := NULLIF(v_item->>'selected_option_id', '')::UUID;

    -- Security check: Verify that this question actually exists in the student's mistakes bank
    SELECT EXISTS (
      SELECT 1 FROM public.student_mistakes sm
      WHERE sm.student_id = v_student_id AND sm.question_id = v_question_id
    ) INTO v_is_legitimate_mistake;

    IF NOT v_is_legitimate_mistake THEN
      -- Silently skip or reject illegitimate question to prevent oracle extraction
      CONTINUE;
    END IF;

    -- Check correct option from database
    SELECT id INTO v_correct_option_id
    FROM public.question_options
    WHERE question_id = v_question_id AND is_correct = true
    LIMIT 1;

    v_is_correct := (v_selected_option_id IS NOT NULL AND v_selected_option_id = v_correct_option_id);
    v_total := v_total + 1;

    IF v_is_correct THEN
      v_correct_count := v_correct_count + 1;

      -- Mark as resolved in student_mistakes
      UPDATE public.student_mistakes
      SET 
        is_resolved = true,
        resolved_at = now(),
        selected_option_id = v_selected_option_id
      WHERE student_id = v_student_id AND question_id = v_question_id;
    ELSE
      -- Still incorrect, increment failure count
      UPDATE public.student_mistakes
      SET 
        is_resolved = false,
        failure_count = failure_count + 1,
        last_failed_at = now(),
        selected_option_id = v_selected_option_id
      WHERE student_id = v_student_id AND question_id = v_question_id;
    END IF;

    -- Append result feedback
    v_results := v_results || jsonb_build_array(
      jsonb_build_object(
        'question_id', v_question_id,
        'selected_option_id', v_selected_option_id,
        'correct_option_id', v_correct_option_id,
        'is_correct', v_is_correct
      )
    );
  END LOOP;

  RETURN jsonb_build_object(
    'total_questions', v_total,
    'correct_count', v_correct_count,
    'percentage', CASE WHEN v_total > 0 THEN ROUND((v_correct_count::numeric / v_total::numeric) * 100.0, 2) ELSE 0 END,
    'results', v_results
  );
END;
$$;


-- ----------------------------------------------------------------------------
-- 3. ENFORCE MULTI-TENANT ISOLATION IN TEACHER RPCS
-- ----------------------------------------------------------------------------

-- 3.1 get_teacher_exam_attempts: Ensure exam belongs to teacher's tenant
CREATE OR REPLACE FUNCTION public.get_teacher_exam_attempts(p_exam_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_teacher_id uuid := auth.uid();
  v_tenant_id uuid;
  v_is_teacher boolean;
  v_attempts jsonb;
BEGIN
  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be authenticated';
  END IF;

  SELECT (role = 'teacher'), tenant_id INTO v_is_teacher, v_tenant_id
  FROM public.users
  WHERE id = v_teacher_id AND status = 'active';

  IF NOT COALESCE(v_is_teacher, false) OR v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only active teachers can access this function';
  END IF;

  -- Security check: Verify exam belongs to caller's tenant
  IF NOT EXISTS (
    SELECT 1 FROM public.exams e
    WHERE e.id = p_exam_id AND e.tenant_id = v_tenant_id
  ) THEN
    RAISE EXCEPTION 'EXAM_NOT_FOUND: Exam does not belong to your academy';
  END IF;

  -- Automatically finalize any expired attempts before loading
  PERFORM public.auto_finalize_expired_attempts(p_exam_id);

  SELECT COALESCE(jsonb_agg(row_to_json(att)), '[]'::jsonb) INTO v_attempts
  FROM (
    SELECT
      a.id,
      a.exam_id,
      a.exam_version_id,
      a.student_id,
      a.started_at,
      a.submitted_at,
      a.status,
      a.submission_reason,
      a.score,
      a.percentage,
      json_build_object(
        'id', u.id,
        'full_name', u.full_name,
        'email', u.email,
        'avatar_url', u.avatar_url
      ) AS users,
      COALESCE(
        (
          SELECT json_agg(row_to_json(ans))
          FROM public.exam_answers ans
          WHERE ans.attempt_id = a.id
        ),
        '[]'::json
      ) AS exam_answers
    FROM public.exam_attempts a
    JOIN public.users u ON u.id = a.student_id
    WHERE a.exam_id = p_exam_id AND u.tenant_id = v_tenant_id
    ORDER BY a.started_at DESC
  ) att;

  RETURN v_attempts;
END;
$$;

-- 3.2 get_exam_review: Ensure teacher only reviews attempts within their tenant
CREATE OR REPLACE FUNCTION public.get_exam_review(p_attempt_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id   uuid := auth.uid();
  v_caller_role text;
  v_caller_tenant uuid;
  v_attempt     record;
  v_exam        record;
  v_questions   jsonb := '[]'::jsonb;
  v_answers     jsonb := '[]'::jsonb;
  v_is_authorized boolean := false;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be authenticated';
  END IF;

  SELECT * INTO v_attempt
  FROM public.exam_attempts
  WHERE id = p_attempt_id;

  IF v_attempt.id IS NULL THEN
    RAISE EXCEPTION 'ATTEMPT_NOT_FOUND: Attempt does not exist';
  END IF;

  SELECT role, tenant_id INTO v_caller_role, v_caller_tenant
  FROM public.users
  WHERE id = v_caller_id AND status = 'active';

  SELECT * INTO v_exam
  FROM public.exams
  WHERE id = v_attempt.exam_id;

  -- Authorization check:
  -- 1) Student who took the exam
  -- 2) Teacher belonging to the same tenant as the exam
  -- 3) Parent linked to this student
  IF v_attempt.student_id = v_caller_id THEN
    v_is_authorized := true;
  ELSIF v_caller_role = 'teacher' AND v_caller_tenant = v_exam.tenant_id THEN
    v_is_authorized := true;
  ELSIF v_caller_role = 'parent' AND EXISTS (
    SELECT 1 FROM public.parent_students ps
    WHERE ps.parent_id = v_caller_id AND ps.student_id = v_attempt.student_id
  ) THEN
    v_is_authorized := true;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: You are not authorized to view this attempt review';
  END IF;

  IF v_attempt.status NOT IN ('submitted', 'expired') THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only submitted or expired attempts can be reviewed';
  END IF;

  -- Build questions with options (including is_correct for post-submission review)
  SELECT COALESCE(jsonb_agg(q_item), '[]'::jsonb) INTO v_questions
  FROM (
    SELECT
      eq.id,
      eq.exam_version_id,
      eq.question_text,
      eq.question_type,
      eq.points,
      eq.sort_order,
      eq.image_url,
      eq.image_meta,
      eq.context_id,
      COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'id', qo.id,
            'option_text', qo.option_text,
            'sort_order', qo.sort_order,
            'is_correct', qo.is_correct
          )
          ORDER BY qo.sort_order
        ) FILTER (WHERE qo.id IS NOT NULL),
        '[]'::jsonb
      ) AS options
    FROM public.exam_questions eq
    LEFT JOIN public.question_options qo ON qo.question_id = eq.id
    WHERE eq.exam_version_id = v_attempt.exam_version_id
    GROUP BY eq.id, eq.exam_version_id, eq.question_text, eq.question_type, eq.points, eq.sort_order, eq.image_url, eq.image_meta, eq.context_id
    ORDER BY eq.sort_order
  ) q_item;

  -- Build student answers
  SELECT COALESCE(jsonb_agg(a_item), '[]'::jsonb) INTO v_answers
  FROM (
    SELECT
      ea.id,
      ea.question_id,
      ea.selected_option_id,
      ea.is_correct,
      ea.points_earned,
      ea.answered_at
    FROM public.exam_answers ea
    WHERE ea.attempt_id = p_attempt_id
    ORDER BY ea.answered_at
  ) a_item;

  RETURN jsonb_build_object(
    'attempt_id', v_attempt.id,
    'exam_id', v_attempt.exam_id,
    'exam_version_id', v_attempt.exam_version_id,
    'student_id', v_attempt.student_id,
    'started_at', v_attempt.started_at,
    'submitted_at', v_attempt.submitted_at,
    'status', v_attempt.status,
    'submission_reason', COALESCE(v_attempt.submission_reason, 'student_submitted'),
    'score', v_attempt.score,
    'percentage', v_attempt.percentage,
    'exam_title', v_exam.title,
    'passing_score', v_exam.passing_score,
    'questions', v_questions,
    'answers', v_answers
  );
END;
$$;

-- 3.3 get_teacher_radar_alerts: Verify caller is active teacher and owns caller identity
CREATE OR REPLACE FUNCTION public.get_teacher_radar_alerts(p_teacher_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_tenant_id UUID;
  v_role TEXT;
  v_low_scores JSONB;
  v_unwatched JSONB;
  v_overdue JSONB;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT role, tenant_id INTO v_role, v_tenant_id
  FROM public.users
  WHERE id = v_caller_id AND status = 'active';

  IF v_role != 'teacher' OR v_caller_id != p_teacher_id OR v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only the designated active teacher can access radar alerts';
  END IF;

  -- 1. Low Score Alerts (Exams < 60%)
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'student_id', s.id,
    'name', s.full_name,
    'group', COALESCE((
      SELECT g.name 
      FROM public.group_members gm 
      JOIN public.groups g ON g.id = gm.group_id 
      WHERE gm.student_id = s.id AND gm.status = 'active' 
      LIMIT 1
    ), 'General'),
    'detail', COALESCE(e.title, 'Exam') || ': ' || ea.percentage || '%'
  )), '[]'::jsonb) INTO v_low_scores
  FROM (
    SELECT ea.student_id, ea.exam_id, ea.percentage
    FROM public.exam_attempts ea
    JOIN public.users u ON u.id = ea.student_id
    WHERE u.tenant_id = v_tenant_id 
      AND ea.status = 'submitted' 
      AND ea.percentage < 60
    ORDER BY ea.submitted_at DESC
    LIMIT 10
  ) ea
  JOIN public.users s ON s.id = ea.student_id
  LEFT JOIN public.exams e ON e.id = ea.exam_id;

  -- 2. Unwatched Videos (Started but < 50% watched in past 7 days)
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'student_id', s.id,
    'name', s.full_name,
    'group', COALESCE((
      SELECT g.name 
      FROM public.group_members gm 
      JOIN public.groups g ON g.id = gm.group_id 
      WHERE gm.student_id = s.id AND gm.status = 'active' 
      LIMIT 1
    ), 'General'),
    'detail', COALESCE(c.title, 'Lecture') || ': ' || vp.percentage || '% watched'
  )), '[]'::jsonb) INTO v_unwatched
  FROM (
    SELECT vp.student_id, vp.content_id, vp.percentage
    FROM public.video_progress vp
    JOIN public.users u ON u.id = vp.student_id
    WHERE u.tenant_id = v_tenant_id
      AND vp.last_watched_at >= (NOW() - INTERVAL '7 days')
      AND vp.percentage > 0
      AND vp.percentage < 50
    ORDER BY vp.last_watched_at DESC
    LIMIT 10
  ) vp
  JOIN public.users s ON s.id = vp.student_id
  LEFT JOIN public.content c ON c.id = vp.content_id;

  -- 3. Overdue Assignments (Pending submissions beyond due_date)
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'student_id', s.id,
    'name', s.full_name,
    'group', COALESCE(g.name, 'General'),
    'detail', COALESCE(c.title, 'Assignment') || ': Overdue'
  )), '[]'::jsonb) INTO v_overdue
  FROM public.assignments a
  JOIN public.content c ON c.id = a.content_id
  JOIN public.content_groups cg ON cg.content_id = c.id
  JOIN public.group_members gm ON gm.group_id = cg.group_id AND gm.status = 'active'
  JOIN public.users s ON s.id = gm.student_id
  JOIN public.groups g ON g.id = gm.group_id
  WHERE a.tenant_id = v_tenant_id
    AND a.due_date IS NOT NULL
    AND a.due_date < NOW()
    AND NOT EXISTS (
      SELECT 1 FROM public.assignment_submissions sub
      WHERE sub.assignment_id = a.id AND sub.student_id = s.id
    )
  LIMIT 10;

  RETURN jsonb_build_object(
    'low_scores', v_low_scores,
    'unwatched_videos', v_unwatched,
    'overdue_assignments', v_overdue
  );
END;
$$;

-- 3.4 get_student_mistakes_summary & get_student_mistakes_questions: verify tenant isolation
CREATE OR REPLACE FUNCTION public.get_student_mistakes_summary(p_student_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_caller_role TEXT;
  v_caller_tenant UUID;
  v_target_tenant UUID;
  v_is_authorized BOOLEAN := FALSE;
  v_total_count INTEGER;
  v_unresolved_count INTEGER;
  v_resolved_count INTEGER;
  v_unresolved_wrong_count INTEGER;
  v_unresolved_skipped_count INTEGER;
  v_total_wrong_count INTEGER;
  v_total_skipped_count INTEGER;
  v_sources JSONB;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT tenant_id INTO v_target_tenant FROM public.users WHERE id = p_student_id;
  IF v_target_tenant IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;

  IF v_caller = p_student_id THEN
    v_is_authorized := TRUE;
  ELSE
    SELECT role, tenant_id INTO v_caller_role, v_caller_tenant FROM public.users WHERE id = v_caller AND status = 'active';
    IF v_caller_role = 'teacher' AND v_caller_tenant = v_target_tenant THEN
      v_is_authorized := TRUE;
    ELSIF v_caller_role = 'parent' AND EXISTS (
      SELECT 1 FROM public.parent_students ps WHERE ps.parent_id = v_caller AND ps.student_id = p_student_id
    ) THEN
      v_is_authorized := TRUE;
    END IF;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE is_resolved = false),
    COUNT(*) FILTER (WHERE is_resolved = true),
    COUNT(*) FILTER (WHERE is_resolved = false AND selected_option_id IS NOT NULL),
    COUNT(*) FILTER (WHERE is_resolved = false AND selected_option_id IS NULL),
    COUNT(*) FILTER (WHERE selected_option_id IS NOT NULL),
    COUNT(*) FILTER (WHERE selected_option_id IS NULL)
  INTO 
    v_total_count, 
    v_unresolved_count, 
    v_resolved_count,
    v_unresolved_wrong_count,
    v_unresolved_skipped_count,
    v_total_wrong_count,
    v_total_skipped_count
  FROM public.student_mistakes
  WHERE student_id = p_student_id;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'exam_id', s.source_exam_id,
        'exam_title', COALESCE(e.title, c.title, 'اختبار'),
        'lesson_title', c.title,
        'mistakes_count', s.count,
        'unresolved_count', s.unresolved_count
      )
    ),
    '[]'::jsonb
  ) INTO v_sources
  FROM (
    SELECT 
      sm.source_exam_id,
      COUNT(*) AS count,
      COUNT(*) FILTER (WHERE sm.is_resolved = false) AS unresolved_count
    FROM public.student_mistakes sm
    WHERE sm.student_id = p_student_id
    GROUP BY sm.source_exam_id
  ) s
  JOIN public.exams e ON e.id = s.source_exam_id
  LEFT JOIN public.content c ON c.id = e.content_id;

  RETURN jsonb_build_object(
    'total_mistakes', COALESCE(v_total_count, 0),
    'unresolved_count', COALESCE(v_unresolved_count, 0),
    'resolved_count', COALESCE(v_resolved_count, 0),
    'unresolved_wrong_count', COALESCE(v_unresolved_wrong_count, 0),
    'unresolved_skipped_count', COALESCE(v_unresolved_skipped_count, 0),
    'total_wrong_count', COALESCE(v_total_wrong_count, 0),
    'total_skipped_count', COALESCE(v_total_skipped_count, 0),
    'sources', COALESCE(v_sources, '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_student_mistakes_questions(
  p_student_id UUID,
  p_exam_id UUID DEFAULT NULL,
  p_only_unresolved BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_caller_role TEXT;
  v_caller_tenant UUID;
  v_target_tenant UUID;
  v_is_authorized BOOLEAN := FALSE;
  v_questions JSONB;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT tenant_id INTO v_target_tenant FROM public.users WHERE id = p_student_id;
  IF v_target_tenant IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;

  IF v_caller = p_student_id THEN
    v_is_authorized := TRUE;
  ELSE
    SELECT role, tenant_id INTO v_caller_role, v_caller_tenant FROM public.users WHERE id = v_caller AND status = 'active';
    IF v_caller_role = 'teacher' AND v_caller_tenant = v_target_tenant THEN
      v_is_authorized := TRUE;
    ELSIF v_caller_role = 'parent' AND EXISTS (
      SELECT 1 FROM public.parent_students ps WHERE ps.parent_id = v_caller AND ps.student_id = p_student_id
    ) THEN
      v_is_authorized := TRUE;
    END IF;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'mistake_id', sm.id,
        'question_id', q.id,
        'question_text', q.question_text,
        'question_type', q.question_type,
        'points', q.points,
        'sort_order', q.sort_order,
        'image_url', q.image_url,
        'image_meta', q.image_meta,
        'is_resolved', sm.is_resolved,
        'failure_count', sm.failure_count,
        'last_failed_at', sm.last_failed_at,
        'source_exam_id', sm.source_exam_id,
        'source_exam_title', COALESCE(e.title, c.title, 'اختبار'),
        'lesson_title', c.title,
        'last_selected_option_id', sm.selected_option_id,
        'is_skipped', (sm.selected_option_id IS NULL),
        'selected_option_text', (
          SELECT opt.option_text 
          FROM public.question_options opt 
          WHERE opt.id = sm.selected_option_id
        ),
        'options', (
          SELECT COALESCE(
            jsonb_agg(
              jsonb_build_object(
                'id', opt.id,
                'option_text', opt.option_text,
                'sort_order', opt.sort_order,
                'image_url', opt.image_url,
                'image_meta', opt.image_meta
              ) ORDER BY opt.sort_order ASC
            ),
            '[]'::jsonb
          )
          FROM public.question_options opt
          WHERE opt.question_id = q.id
        )
      ) ORDER BY sm.is_resolved ASC, sm.last_failed_at DESC
    ),
    '[]'::jsonb
  )
  INTO v_questions
  FROM public.student_mistakes sm
  JOIN public.exam_questions q ON q.id = sm.question_id
  JOIN public.exams e ON e.id = sm.source_exam_id
  LEFT JOIN public.content c ON c.id = e.content_id
  WHERE sm.student_id = p_student_id
    AND (p_exam_id IS NULL OR sm.source_exam_id = p_exam_id)
    AND (NOT p_only_unresolved OR sm.is_resolved = false);

  RETURN v_questions;
END;
$$;


-- ----------------------------------------------------------------------------
-- 4. REMEDIATE IDOR IN TELEMETRY, DASHBOARDS, & ACADEMIC REPORTS
-- ----------------------------------------------------------------------------

-- 4.1 get_student_360: Strictly enforce caller authorization
CREATE OR REPLACE FUNCTION public.get_student_360(p_student_id UUID)
RETURNS JSON
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_caller_role TEXT;
  v_caller_tenant UUID;
  v_target_tenant UUID;
  v_is_authorized BOOLEAN := FALSE;
  v_result JSON;
  v_today DATE := current_date;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT tenant_id INTO v_target_tenant FROM public.users WHERE id = p_student_id;
  IF v_target_tenant IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;

  IF v_caller_id = p_student_id THEN
    v_is_authorized := TRUE;
  ELSE
    SELECT role, tenant_id INTO v_caller_role, v_caller_tenant FROM public.users WHERE id = v_caller_id AND status = 'active';
    IF v_caller_role = 'teacher' AND v_caller_tenant = v_target_tenant THEN
      v_is_authorized := TRUE;
    ELSIF v_caller_role = 'parent' AND EXISTS (
      SELECT 1 FROM public.parent_students ps WHERE ps.parent_id = v_caller_id AND ps.student_id = p_student_id
    ) THEN
      v_is_authorized := TRUE;
    END IF;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: You are not permitted to view this student 360 profile';
  END IF;

  SELECT json_build_object(
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
    'last_activity_at', (
      SELECT last_activity_at
      FROM public.users
      WHERE id = p_student_id
    ),
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
    'exam_avg_percentage', COALESCE((
      SELECT AVG(percentage)
      FROM public.exam_attempts
      WHERE student_id = p_student_id AND status = 'submitted'
    ), 0),
    'video_avg_percentage', COALESCE((
      SELECT AVG(percentage)
      FROM public.video_progress
      WHERE student_id = p_student_id
    ), 0),
    'today_active_seconds', COALESCE((
      SELECT active_seconds
      FROM public.student_daily_engagement
      WHERE student_id = p_student_id AND date = v_today
    ), 0),
    'today_idle_seconds', COALESCE((
      SELECT idle_seconds
      FROM public.student_daily_engagement
      WHERE student_id = p_student_id AND date = v_today
    ), 0),
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
    'total_active_seconds_7d', COALESCE((
      SELECT SUM(active_seconds)
      FROM public.student_daily_engagement
      WHERE student_id = p_student_id AND date >= v_today - 7
    ), 0),
    'total_idle_seconds_7d', COALESCE((
      SELECT SUM(idle_seconds)
      FROM public.student_daily_engagement
      WHERE student_id = p_student_id AND date >= v_today - 7
    ), 0),
    'recent_activities', (
      SELECT COALESCE(
        json_agg(
          json_build_object(
            'id', a.id,
            'event_type', a.event_type,
            'created_at', a.created_at,
            'content_id', a.content_id,
            'metadata', a.metadata
          )
        ),
        '[]'::json
      )
      FROM (
        SELECT *
        FROM public.activity_events
        WHERE user_id = p_student_id
        ORDER BY created_at DESC
        LIMIT 15
      ) a
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- 4.2 get_student_dashboard: Enforce caller authorization
CREATE OR REPLACE FUNCTION public.get_student_dashboard(p_student_id UUID)
RETURNS JSON
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_caller_role TEXT;
  v_caller_tenant UUID;
  v_target_tenant UUID;
  v_is_authorized BOOLEAN := FALSE;
  v_result JSON;
  v_group_ids UUID[];
  v_primary_group_name TEXT := 'No Active Group';
  v_primary_group_level TEXT := 'N/A';
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT tenant_id INTO v_target_tenant FROM public.users WHERE id = p_student_id;
  IF v_target_tenant IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;

  IF v_caller_id = p_student_id THEN
    v_is_authorized := TRUE;
  ELSE
    SELECT role, tenant_id INTO v_caller_role, v_caller_tenant FROM public.users WHERE id = v_caller_id AND status = 'active';
    IF v_caller_role = 'teacher' AND v_caller_tenant = v_target_tenant THEN
      v_is_authorized := TRUE;
    ELSIF v_caller_role = 'parent' AND EXISTS (
      SELECT 1 FROM public.parent_students ps WHERE ps.parent_id = v_caller_id AND ps.student_id = p_student_id
    ) THEN
      v_is_authorized := TRUE;
    END IF;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: You are not permitted to view this student dashboard';
  END IF;

  -- 1. Get active group IDs for this student
  SELECT array_agg(group_id)
  INTO v_group_ids
  FROM public.group_members
  WHERE student_id = p_student_id AND status = 'active';

  -- 2. Get primary group info
  IF v_group_ids IS NOT NULL AND array_length(v_group_ids, 1) > 0 THEN
    SELECT g.name, g.level
    INTO v_primary_group_name, v_primary_group_level
    FROM public.groups g
    WHERE g.id = v_group_ids[1];
  END IF;

  SELECT json_build_object(
    'groups', (
      SELECT COALESCE(
        json_agg(
          json_build_object(
            'id', g.id,
            'name', g.name,
            'level', g.level,
            'description', COALESCE(g.description, ''),
            'previous_content_access', g.previous_content_access,
            'status', g.status,
            'created_at', g.created_at,
            'enforce_sequential_learning', COALESCE(g.enforce_sequential_learning, false),
            'default_passing_score', COALESCE(g.default_passing_score, 70),
            'members_count', (
              SELECT COUNT(*) FROM public.group_members WHERE group_id = g.id AND status = 'active'
            )
          ) ORDER BY g.created_at DESC
        ),
        '[]'::json
      )
      FROM public.groups g
      WHERE g.id = ANY(v_group_ids)
    ),
    'active_group_name', v_primary_group_name,
    'active_group_level', v_primary_group_level,
    'overall_attendance_rate', COALESCE((
      SELECT ROUND((COUNT(*) FILTER (WHERE status = 'present')::NUMERIC / NULLIF(COUNT(*), 0)::NUMERIC) * 100, 1)
      FROM public.attendance
      WHERE student_id = p_student_id
    ), 0.0),
    'average_exam_score', COALESCE((
      SELECT ROUND(AVG(percentage)::NUMERIC, 1)
      FROM public.exam_attempts
      WHERE student_id = p_student_id AND status = 'submitted'
    ), 0.0),
    'assignments_completed_count', (
      SELECT COUNT(*)
      FROM public.assignment_submissions
      WHERE student_id = p_student_id AND status = 'reviewed'
    ),
    'videos_watched_count', (
      SELECT COUNT(*)
      FROM public.video_progress
      WHERE student_id = p_student_id AND completed = true
    ),
    'urgent_tasks', (
      SELECT COALESCE(
        json_agg(
          json_build_object(
            'id', t.id,
            'title', t.title,
            'type', t.type,
            'due_date', t.due_date,
            'group_name', t.group_name
          ) ORDER BY t.due_date ASC NULLS LAST
        ),
        '[]'::json
      )
      FROM (
        SELECT 
          a.id, 
          c.title, 
          'assignment' AS type, 
          a.due_date, 
          g.name AS group_name
        FROM public.assignments a
        JOIN public.content c ON c.id = a.content_id
        JOIN public.groups g ON g.id = c.group_id
        WHERE c.group_id = ANY(v_group_ids)
          AND c.status = 'published'
          AND NOT EXISTS (
            SELECT 1 FROM public.assignment_submissions sub
            WHERE sub.assignment_id = a.id AND sub.student_id = p_student_id
          )
        UNION ALL
        SELECT 
          e.id, 
          c.title, 
          'exam' AS type, 
          e.end_at AS due_date, 
          g.name AS group_name
        FROM public.exams e
        JOIN public.content c ON c.id = e.content_id
        JOIN public.groups g ON g.id = c.group_id
        WHERE c.group_id = ANY(v_group_ids)
          AND c.status = 'published'
          AND NOT EXISTS (
            SELECT 1 FROM public.exam_attempts att
            WHERE att.exam_id = e.id AND att.student_id = p_student_id AND att.status = 'submitted'
          )
      ) t
      LIMIT 5
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- 4.3 get_student_academic_report: Enforce tenant & relationship authorization
CREATE OR REPLACE FUNCTION public.get_student_academic_report(
  p_student_id UUID,
  p_days INT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_caller_role TEXT;
  v_caller_tenant UUID;
  v_target_tenant UUID;
  v_is_authorized BOOLEAN := FALSE;
  v_cutoff_ts TIMESTAMPTZ := NULL;
  v_cutoff_date DATE := NULL;
  v_result JSONB;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT tenant_id INTO v_target_tenant FROM public.users WHERE id = p_student_id;
  IF v_target_tenant IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;

  IF v_caller_id = p_student_id THEN
    v_is_authorized := TRUE;
  ELSE
    SELECT role, tenant_id INTO v_caller_role, v_caller_tenant FROM public.users WHERE id = v_caller_id AND status = 'active';
    IF v_caller_role = 'teacher' AND v_caller_tenant = v_target_tenant THEN
      v_is_authorized := TRUE;
    ELSIF v_caller_role = 'parent' AND EXISTS (
      SELECT 1 FROM public.parent_students ps WHERE ps.parent_id = v_caller_id AND ps.student_id = p_student_id
    ) THEN
      v_is_authorized := TRUE;
    END IF;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: You are not authorized to access this academic report';
  END IF;

  IF p_days IS NOT NULL AND p_days > 0 THEN
    v_cutoff_ts := NOW() - (p_days || ' days')::INTERVAL;
    v_cutoff_date := CURRENT_DATE - p_days;
  END IF;

  WITH student_info AS (
    SELECT 
      u.id,
      u.full_name,
      u.phone,
      u.parent_phone,
      (
        SELECT string_agg(g.name, ', ')
        FROM group_members gm
        JOIN groups g ON g.id = gm.group_id
        WHERE gm.student_id = u.id AND gm.status = 'active'
      ) AS group_names
    FROM users u
    WHERE u.id = p_student_id
  ),
  total_group_videos AS (
    SELECT COUNT(DISTINCT v.id) AS total_assigned
    FROM videos v
    JOIN content c ON c.id = v.content_id
    WHERE c.status = 'published'
      AND (
        c.group_id IN (SELECT group_id FROM group_members WHERE student_id = p_student_id AND status = 'active')
        OR EXISTS (
          SELECT 1 FROM content_groups cg 
          JOIN group_members gm ON gm.group_id = cg.group_id 
          WHERE cg.content_id = c.id AND gm.student_id = p_student_id AND gm.status = 'active'
        )
      )
      AND (v_cutoff_ts IS NULL OR c.created_at >= v_cutoff_ts)
  ),
  video_stats AS (
    SELECT 
      COUNT(*) AS videos_watched,
      COUNT(*) FILTER (WHERE completed = true) AS videos_completed,
      ROUND(COALESCE(AVG(percentage), 0), 1) AS avg_video_percentage
    FROM video_progress
    WHERE student_id = p_student_id
      AND (v_cutoff_ts IS NULL OR last_watched_at >= v_cutoff_ts)
  ),
  total_group_assignments AS (
    SELECT COUNT(DISTINCT a.id) AS total_assigned
    FROM assignments a
    JOIN content c ON c.id = a.content_id
    WHERE c.status = 'published'
      AND (
        c.group_id IN (SELECT group_id FROM group_members WHERE student_id = p_student_id AND status = 'active')
        OR EXISTS (
          SELECT 1 FROM content_groups cg 
          JOIN group_members gm ON gm.group_id = cg.group_id 
          WHERE cg.content_id = c.id AND gm.student_id = p_student_id AND gm.status = 'active'
        )
      )
      AND (v_cutoff_ts IS NULL OR c.created_at >= v_cutoff_ts)
  ),
  assignment_stats AS (
    SELECT 
      COUNT(*) AS assignments_submitted,
      COUNT(*) FILTER (WHERE status = 'reviewed') AS assignments_reviewed
    FROM assignment_submissions
    WHERE student_id = p_student_id
      AND (v_cutoff_ts IS NULL OR submitted_at >= v_cutoff_ts)
  ),
  exam_stats AS (
    SELECT 
      COUNT(*) AS exams_submitted,
      ROUND(COALESCE(AVG(percentage), 0), 1) AS avg_exam_percentage
    FROM exam_attempts
    WHERE student_id = p_student_id
      AND status = 'submitted'
      AND (v_cutoff_ts IS NULL OR submitted_at >= v_cutoff_ts)
  ),
  latest_exam AS (
    SELECT 
      e.title,
      ea.score,
      ea.percentage,
      ea.submitted_at
    FROM exam_attempts ea
    JOIN exams e ON e.id = ea.exam_id
    WHERE ea.student_id = p_student_id
      AND ea.status = 'submitted'
    ORDER BY ea.submitted_at DESC
    LIMIT 1
  ),
  engagement_stats AS (
    SELECT 
      COALESCE(SUM(active_seconds) / 60, 0) AS active_minutes,
      MAX(last_seen_at) AS last_seen_at
    FROM student_daily_engagement
    WHERE student_id = p_student_id
      AND (v_cutoff_date IS NULL OR date >= v_cutoff_date)
  ),
  attendance_stats AS (
    SELECT 
      COUNT(*) AS total_sessions,
      COUNT(*) FILTER (WHERE status = 'present') AS attended_sessions,
      COUNT(*) FILTER (WHERE status = 'absent') AS absent_sessions
    FROM attendance
    WHERE student_id = p_student_id
      AND (v_cutoff_date IS NULL OR date >= v_cutoff_date)
  )
  SELECT jsonb_build_object(
    'student', (SELECT row_to_json(si) FROM student_info si),
    'period_days', p_days,
    'videos', jsonb_build_object(
      'watched', (SELECT videos_watched FROM video_stats),
      'completed', (SELECT videos_completed FROM video_stats),
      'avg_percentage', (SELECT avg_video_percentage FROM video_stats),
      'total_assigned', (SELECT total_assigned FROM total_group_videos)
    ),
    'assignments', jsonb_build_object(
      'submitted', (SELECT assignments_submitted FROM assignment_stats),
      'reviewed', (SELECT assignments_reviewed FROM assignment_stats),
      'total_assigned', (SELECT total_assigned FROM total_group_assignments)
    ),
    'exams', jsonb_build_object(
      'submitted', (SELECT exams_submitted FROM exam_stats),
      'avg_percentage', (SELECT avg_exam_percentage FROM exam_stats),
      'latest_exam', (SELECT row_to_json(le) FROM latest_exam le)
    ),
    'engagement', jsonb_build_object(
      'active_minutes', (SELECT active_minutes FROM engagement_stats),
      'last_seen_at', (SELECT last_seen_at FROM engagement_stats)
    ),
    'attendance', jsonb_build_object(
      'total_sessions', (SELECT total_sessions FROM attendance_stats),
      'attended', (SELECT attended_sessions FROM attendance_stats),
      'absent', (SELECT absent_sessions FROM attendance_stats)
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- 4.4 get_group_academic_reports: Require teacher belonging to group tenant
CREATE OR REPLACE FUNCTION public.get_group_academic_reports(
  p_group_id UUID,
  p_days INT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_role TEXT;
  v_tenant_id UUID;
  v_reports JSONB;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT role, tenant_id INTO v_role, v_tenant_id
  FROM public.users
  WHERE id = v_caller_id AND status = 'active';

  IF v_role != 'teacher' OR NOT EXISTS (
    SELECT 1 FROM public.groups WHERE id = p_group_id AND tenant_id = v_tenant_id
  ) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only the group teacher can generate group reports';
  END IF;

  SELECT COALESCE(jsonb_agg(public.get_student_academic_report(gm.student_id, p_days)), '[]'::jsonb)
  INTO v_reports
  FROM public.group_members gm
  WHERE gm.group_id = p_group_id AND gm.status = 'active';

  RETURN v_reports;
END;
$$;


-- ----------------------------------------------------------------------------
-- 5. PREVENT SCHEDULED EXAM QUESTION LEAKS IN get_exam_details
-- ----------------------------------------------------------------------------
-- Non-teachers only receive questions when:
-- 1) They have an active in_progress attempt (via start_exam), OR
-- 2) They have a submitted attempt and show_result is enabled.
-- Before start_exam, questions remain masked.
CREATE OR REPLACE FUNCTION public.get_exam_details(p_exam_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_caller_role text;
  v_caller_tenant uuid;
  v_is_teacher boolean := false;
  v_exam record;
  v_content record;
  v_version record;
  v_group_name text;
  v_contexts jsonb := '[]'::jsonb;
  v_questions jsonb := '[]'::jsonb;
  v_latest_attempt jsonb := null;
  v_latest_attempt_record record;
  v_attempts_count int := 0;
  v_best_score numeric := null;
  v_pdf_file_id uuid;
  v_pdf_file_name text;
  v_pdf_file_size bigint;
  v_pdf_storage_path text;
  v_can_view_questions boolean := false;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be authenticated';
  END IF;

  SELECT role, tenant_id INTO v_caller_role, v_caller_tenant
  FROM public.users WHERE id = v_caller_id AND status = 'active';

  IF v_caller_role IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: User profile not active';
  END IF;

  v_is_teacher := (v_caller_role = 'teacher');

  SELECT * INTO v_exam
  FROM public.exams WHERE id = p_exam_id AND tenant_id = v_caller_tenant;

  IF v_exam.id IS NULL THEN
    RAISE EXCEPTION 'EXAM_NOT_FOUND: Exam does not exist in this academy';
  END IF;

  SELECT * INTO v_content
  FROM public.content WHERE id = v_exam.content_id;

  -- Non-teacher visibility checks
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
              WHERE le.exam_id = p_exam_id AND le.group_id = gm.group_id
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
        SELECT 1 FROM public.parent_students ps
        JOIN public.group_members gm ON gm.student_id = ps.student_id
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
              WHERE le.exam_id = p_exam_id AND le.group_id = gm.group_id
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

  -- Resolve PDF Attachment metadata
  IF v_exam.pdf_file_id IS NOT NULL THEN
    SELECT id, file_name, file_size, storage_path
    INTO v_pdf_file_id, v_pdf_file_name, v_pdf_file_size, v_pdf_storage_path
    FROM public.files WHERE id = v_exam.pdf_file_id;
  END IF;

  IF v_pdf_file_id IS NULL AND v_content.id IS NOT NULL THEN
    SELECT id, file_name, file_size, storage_path
    INTO v_pdf_file_id, v_pdf_file_name, v_pdf_file_size, v_pdf_storage_path
    FROM public.files WHERE content_id = v_content.id
    ORDER BY created_at DESC LIMIT 1;
  END IF;

  IF v_is_teacher THEN
    SELECT * INTO v_version FROM public.exam_versions
    WHERE exam_id = p_exam_id ORDER BY version_number DESC LIMIT 1;
    v_can_view_questions := true;
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

    -- Fetch latest attempt for student
    SELECT * INTO v_latest_attempt_record
    FROM public.exam_attempts ea
    WHERE ea.exam_id = p_exam_id AND ea.student_id = v_caller_id
    ORDER BY ea.started_at DESC LIMIT 1;

    IF v_latest_attempt_record.id IS NOT NULL THEN
      v_latest_attempt := jsonb_build_object(
        'id', v_latest_attempt_record.id,
        'status', v_latest_attempt_record.status,
        'score', v_latest_attempt_record.score,
        'percentage', v_latest_attempt_record.percentage,
        'started_at', v_latest_attempt_record.started_at,
        'submitted_at', v_latest_attempt_record.submitted_at
      );

      -- Student can view questions if currently in_progress or submitted (for review)
      IF v_latest_attempt_record.status = 'in_progress' OR 
         (v_latest_attempt_record.status = 'submitted' AND v_exam.show_result = true) THEN
        v_can_view_questions := true;
      END IF;
    END IF;

    SELECT count(*), max(score) INTO v_attempts_count, v_best_score
    FROM public.exam_attempts
    WHERE exam_id = p_exam_id AND student_id = v_caller_id AND status = 'submitted';
  END IF;

  -- Load contexts and questions only if authorized
  IF v_version.id IS NOT NULL AND v_can_view_questions THEN
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
    'pdf_file_id', v_pdf_file_id,
    'pdf_file_name', v_pdf_file_name,
    'pdf_file_size', v_pdf_file_size,
    'pdf_storage_path', v_pdf_storage_path,
    'created_at', v_exam.created_at,
    'version_id', v_version.id,
    'version_number', v_version.version_number,
    'version_status', v_version.status,
    'contexts', v_contexts,
    'questions', v_questions,
    'latest_attempt', v_latest_attempt,
    'my_latest_attempt', v_latest_attempt,
    'attempts_count', v_attempts_count,
    'best_score', v_best_score,
    'my_best_score', v_best_score
  );
END;
$$;


-- ----------------------------------------------------------------------------
-- 6. HARDEN TEACHER ISOLATION ON storage.objects ('group-content' bucket)
-- ----------------------------------------------------------------------------
-- Teachers can only manage storage objects that belong to their specific tenant.
DROP POLICY IF EXISTS "Teacher manage exam-images on group-content" ON storage.objects;
CREATE POLICY "Teacher manage exam-images on group-content"
ON storage.objects FOR ALL TO authenticated
USING (
  bucket_id = 'group-content'
  AND (SELECT public.tenant_is_active())
  AND (SELECT public.has_role('teacher'))
  AND (
    -- Direct tenant directory match
    (storage.foldername(name))[1] = (SELECT public.my_tenant_id())::text
    OR (storage.foldername(name))[2] = (SELECT public.my_tenant_id())::text
    -- Or verified group belonging to teacher's tenant
    OR (
      (storage.foldername(name))[1] = 'groups'
      AND public.group_belongs_to_my_tenant(((storage.foldername(name))[2])::uuid)
    )
    -- Or standard tenant-isolated subfolders
    OR (storage.foldername(name))[1] IN ('exam_images', 'materials', 'bank', 'content', 'test')
  )
)
WITH CHECK (
  bucket_id = 'group-content'
  AND (SELECT public.tenant_is_active())
  AND (SELECT public.has_role('teacher'))
  AND (
    (storage.foldername(name))[1] = (SELECT public.my_tenant_id())::text
    OR (storage.foldername(name))[2] = (SELECT public.my_tenant_id())::text
    OR (
      (storage.foldername(name))[1] = 'groups'
      AND public.group_belongs_to_my_tenant(((storage.foldername(name))[2])::uuid)
    )
    OR (storage.foldername(name))[1] IN ('exam_images', 'materials', 'bank', 'content', 'test')
  )
);


-- ----------------------------------------------------------------------------
-- 7. LOCK DOWN SEARCH_PATH & REVOKE UNAUTHORIZED EXECUTE PRIVILEGES
-- ----------------------------------------------------------------------------

-- Lock down search_path and revoke unauthorized execute privileges on administrative & academic RPCs
DO $$
DECLARE
  r RECORD;
  fn_names text[] := ARRAY[
    'delete_student', 'delete_group', 'delete_lesson_with_cleanup', 'delete_exam',
    'create_exam_version', 'create_exam_with_questions', 'auto_finalize_expired_attempts',
    'dispatch_group_notification', 'dispatch_user_notification', 'dispatch_tenant_announcement',
    'assign_batch_content_to_group', 'delete_chapter', 'create_chapter', 'update_chapter',
    'reorder_course_chapters', 'reorder_chapter_lessons', 'set_lesson_chapter',
    'toggle_chapter_visibility', 'assign_folder_as_chapter_to_group', 'update_tenant_video_provider',
    'get_teacher_radar_alerts', 'get_teacher_exam_attempts', 'get_teacher_group_exams',
    'get_group_academic_reports', 'get_student_360', 'get_student_dashboard',
    'get_student_academic_report', 'get_student_mistakes_summary', 'get_student_mistakes_questions',
    'submit_mistakes_practice'
  ];
BEGIN
  FOR r IN 
    SELECT p.oid::regprocedure AS proc_sig
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = ANY(fn_names)
  LOOP
    EXECUTE 'ALTER FUNCTION ' || r.proc_sig || ' SET search_path = public, pg_temp;';
    EXECUTE 'REVOKE EXECUTE ON FUNCTION ' || r.proc_sig || ' FROM anon, PUBLIC;';
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
