-- 0097_fix_exam_details_and_student_exams_rpc.sql
-- 1. Fix get_exam_details to return root questions/contexts AND active_version object with created_at
-- 2. Fix get_exam_details to return pdf_storage_provider, my_best_score, best_score, attempts_count
-- 3. Fix get_student_exams: compute real attempts_count, my_best_score, my_best_percentage, has_passed, has_active_attempt, and full my_latest_attempt object
-- 4. Enrich get_student_exams and get_teacher_group_exams with PDF metadata (pdf_file_id, pdf_file_name, pdf_storage_path, pdf_storage_provider)

-- 1. Update public.get_exam_details
CREATE OR REPLACE FUNCTION public.get_exam_details(p_exam_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
  v_pdf_file_id    uuid := null;
  v_pdf_file_name  text := null;
  v_pdf_file_size  bigint := null;
  v_pdf_storage_path text := null;
  v_pdf_storage_provider text := null;
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

  -- Resolve PDF Attachment metadata (Check material_library first, then files)
  IF v_exam.pdf_file_id IS NOT NULL THEN
    SELECT id, COALESCE(file_name, title), file_size, storage_path, storage_provider
    INTO v_pdf_file_id, v_pdf_file_name, v_pdf_file_size, v_pdf_storage_path, v_pdf_storage_provider
    FROM public.material_library WHERE id = v_exam.pdf_file_id;

    IF v_pdf_file_id IS NULL THEN
      SELECT id, file_name, file_size, storage_path, storage_provider
      INTO v_pdf_file_id, v_pdf_file_name, v_pdf_file_size, v_pdf_storage_path, v_pdf_storage_provider
      FROM public.files WHERE id = v_exam.pdf_file_id;
    END IF;
  END IF;

  IF v_pdf_file_id IS NULL AND v_content.id IS NOT NULL THEN
    SELECT id, file_name, file_size, storage_path, storage_provider
    INTO v_pdf_file_id, v_pdf_file_name, v_pdf_file_size, v_pdf_storage_path, v_pdf_storage_provider
    FROM public.files WHERE content_id = v_content.id
    ORDER BY created_at DESC LIMIT 1;
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
    'pdf_file_id', v_pdf_file_id,
    'pdf_file_name', v_pdf_file_name,
    'pdf_file_size', v_pdf_file_size,
    'pdf_storage_path', v_pdf_storage_path,
    'pdf_storage_provider', v_pdf_storage_provider,
    'created_at', v_exam.created_at,
    'version_id', v_version.id,
    'version_number', v_version.version_number,
    'version_status', v_version.status,
    'contexts', v_contexts,
    'questions', v_questions,
    'active_version', CASE 
      WHEN v_version.id IS NOT NULL THEN jsonb_build_object(
        'id', v_version.id,
        'exam_id', v_exam.id,
        'version_number', v_version.version_number,
        'status', v_version.status,
        'created_at', COALESCE(v_version.created_at, v_exam.created_at),
        'questions', v_questions,
        'contexts', v_contexts
      )
      ELSE null
    END,
    'latest_attempt', v_latest_attempt,
    'my_latest_attempt', v_latest_attempt,
    'attempts_count', v_attempts_count,
    'best_score', v_best_score,
    'my_best_score', v_best_score
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_exam_details(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_exam_details(uuid) TO authenticated;

-- 2. Update public.get_student_exams
CREATE OR REPLACE FUNCTION public.get_student_exams(
    p_page integer DEFAULT 0,
    p_page_size integer DEFAULT 15
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
            e.pdf_file_id,
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
            e.pdf_file_id,
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
    student_latest_attempt AS (
        SELECT DISTINCT ON (ea.exam_id)
            ea.exam_id,
            ea.id AS attempt_id,
            ea.exam_version_id,
            ea.status AS attempt_status,
            ea.score,
            ea.percentage,
            ea.started_at,
            ea.submitted_at,
            COALESCE((
                SELECT count(DISTINCT ea_ans.question_id)::int
                FROM public.exam_answers ea_ans
                WHERE ea_ans.attempt_id = ea.id
            ), 0) AS answered_questions_count
        FROM public.exam_attempts ea
        WHERE ea.student_id = v_user_id
          AND ea.exam_id IN (SELECT id FROM paged_exams)
        ORDER BY ea.exam_id, ea.started_at DESC
    ),
    student_exam_aggregates AS (
        SELECT
            ea.exam_id,
            count(ea.id)::int AS attempts_count,
            max(ea.score) FILTER (WHERE ea.status = 'submitted') AS best_score,
            max(ea.percentage) FILTER (WHERE ea.status = 'submitted') AS best_percentage,
            bool_or(ea.status = 'in_progress') AS has_active_attempt
        FROM public.exam_attempts ea
        WHERE ea.student_id = v_user_id
          AND ea.exam_id IN (SELECT id FROM paged_exams)
        GROUP BY ea.exam_id
    ),
    exam_pdf_data AS (
        SELECT
            pe.id AS exam_id,
            COALESCE(ml.file_name, ml.title, f.file_name) AS pdf_file_name,
            COALESCE(ml.file_size, f.file_size) AS pdf_file_size,
            COALESCE(ml.storage_path, f.storage_path) AS pdf_storage_path,
            COALESCE(ml.storage_provider, f.storage_provider, 'supabase') AS pdf_storage_provider
        FROM paged_exams pe
        LEFT JOIN public.material_library ml ON ml.id = pe.pdf_file_id
        LEFT JOIN public.files f ON f.id = pe.pdf_file_id AND ml.id IS NULL
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
                'pdf_file_id', pe.pdf_file_id,
                'pdf_file_name', epd.pdf_file_name,
                'pdf_file_size', epd.pdf_file_size,
                'pdf_storage_path', epd.pdf_storage_path,
                'pdf_storage_provider', epd.pdf_storage_provider,
                'questions_count', COALESCE(es.questions_count, 0),
                'attempts_count', COALESCE(sea.attempts_count, 0),
                'has_active_attempt', COALESCE(sea.has_active_attempt, false),
                'has_passed', CASE 
                    WHEN sea.best_score IS NOT NULL AND pe.passing_score IS NOT NULL AND sea.best_score >= pe.passing_score THEN true 
                    ELSE false 
                END,
                'my_best_score', sea.best_score,
                'best_score', sea.best_score,
                'student_score', COALESCE(sea.best_score, sla.score),
                'my_best_percentage', sea.best_percentage,
                'student_percentage', COALESCE(sea.best_percentage, sla.percentage),
                'latest_attempt_id', sla.attempt_id,
                'latest_attempt_status', sla.attempt_status,
                'answered_questions_count', COALESCE(sla.answered_questions_count, 0),
                'latest_attempt', CASE 
                    WHEN sla.attempt_id IS NOT NULL THEN jsonb_build_object(
                        'id', sla.attempt_id,
                        'exam_id', pe.id,
                        'exam_version_id', sla.exam_version_id,
                        'student_id', v_user_id,
                        'status', sla.attempt_status,
                        'score', sla.score,
                        'percentage', sla.percentage,
                        'started_at', sla.started_at,
                        'submitted_at', sla.submitted_at
                    )
                    ELSE null
                END,
                'my_latest_attempt', CASE 
                    WHEN sla.attempt_id IS NOT NULL THEN jsonb_build_object(
                        'id', sla.attempt_id,
                        'exam_id', pe.id,
                        'exam_version_id', sla.exam_version_id,
                        'student_id', v_user_id,
                        'status', sla.attempt_status,
                        'score', sla.score,
                        'percentage', sla.percentage,
                        'started_at', sla.started_at,
                        'submitted_at', sla.submitted_at
                    )
                    ELSE null
                END
            )
            ORDER BY pe.created_at DESC
        ),
        '[]'::jsonb
    ) INTO v_result
    FROM paged_exams pe
    LEFT JOIN exam_stats es ON es.exam_id = pe.id
    LEFT JOIN student_latest_attempt sla ON sla.exam_id = pe.id
    LEFT JOIN student_exam_aggregates sea ON sea.exam_id = pe.id
    LEFT JOIN exam_pdf_data epd ON epd.exam_id = pe.id;

    RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_student_exams(integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_student_exams(integer, integer) TO authenticated;

-- 3. Update public.get_teacher_group_exams to include PDF metadata
CREATE OR REPLACE FUNCTION public.get_teacher_group_exams(
    p_group_id uuid,
    p_page int DEFAULT 0,
    p_page_size int DEFAULT 15
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_tenant_id uuid;
    v_user_role text;
    v_result jsonb;
BEGIN
    SELECT role, tenant_id INTO v_user_role, v_tenant_id
    FROM public.users
    WHERE id = auth.uid();

    IF v_user_role != 'teacher' OR v_tenant_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: only teachers can view teacher exams';
    END IF;

    WITH matched_exams AS (
        SELECT 
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
            e.pdf_file_id,
            c.title AS exam_title,
            c.group_id AS content_group_id,
            c.description AS content_description,
            c.status AS content_status
        FROM public.exams e
        JOIN public.content c ON c.id = e.content_id
        WHERE c.group_id = p_group_id
          AND e.tenant_id = v_tenant_id
          AND c.status != 'archived'
        UNION
        SELECT 
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
            e.pdf_file_id,
            c.title AS exam_title,
            c.group_id AS content_group_id,
            c.description AS content_description,
            c.status AS content_status
        FROM public.exams e
        JOIN public.content c ON c.id = e.content_id
        JOIN public.content_groups cg ON cg.associated_exam_id = e.id
        WHERE cg.group_id = p_group_id
          AND e.tenant_id = v_tenant_id
          AND c.status != 'archived'
        UNION
        SELECT 
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
            e.pdf_file_id,
            c.title AS exam_title,
            c.group_id AS content_group_id,
            c.description AS content_description,
            c.status AS content_status
        FROM public.exams e
        JOIN public.content c ON c.id = e.content_id
        JOIN public.lesson_exams le ON le.exam_id = e.id
        WHERE le.group_id = p_group_id
          AND e.tenant_id = v_tenant_id
          AND c.status != 'archived'
        ORDER BY created_at DESC
        LIMIT p_page_size OFFSET (p_page * p_page_size)
    ),
    exam_stats AS (
        SELECT 
            me.id AS exam_id,
            count(ea.id)::int AS attempts_count
        FROM matched_exams me
        LEFT JOIN public.exam_attempts ea ON ea.exam_id = me.id
        GROUP BY me.id
    ),
    exam_versions_agg AS (
        SELECT 
            ev.exam_id,
            jsonb_agg(
                jsonb_build_object(
                    'id', ev.id,
                    'exam_id', ev.exam_id,
                    'version_number', ev.version_number,
                    'status', ev.status,
                    'created_at', ev.created_at,
                    'published_at', ev.published_at,
                    'exam_questions', jsonb_build_array(
                        jsonb_build_object('count', (
                            SELECT count(*)::int
                            FROM public.exam_questions eq
                            WHERE eq.exam_version_id = ev.id
                        ))
                    )
                ) ORDER BY ev.version_number DESC
            ) AS versions_json
        FROM public.exam_versions ev
        WHERE ev.exam_id IN (SELECT id FROM matched_exams)
        GROUP BY ev.exam_id
    ),
    exam_pdf_data AS (
        SELECT
            me.id AS exam_id,
            COALESCE(ml.file_name, ml.title, f.file_name) AS pdf_file_name,
            COALESCE(ml.file_size, f.file_size) AS pdf_file_size,
            COALESCE(ml.storage_path, f.storage_path) AS pdf_storage_path,
            COALESCE(ml.storage_provider, f.storage_provider, 'supabase') AS pdf_storage_provider
        FROM matched_exams me
        LEFT JOIN public.material_library ml ON ml.id = me.pdf_file_id
        LEFT JOIN public.files f ON f.id = me.pdf_file_id AND ml.id IS NULL
    )
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', me.id,
                'content_id', me.content_id,
                'tenant_id', me.tenant_id,
                'title', me.exam_title,
                'description', me.content_description,
                'status', me.content_status,
                'group_id', me.content_group_id,
                'duration_minutes', me.duration_minutes,
                'max_score', me.max_score,
                'passing_score', me.passing_score,
                'shuffle_questions', me.shuffle_questions,
                'show_result', me.show_result,
                'allow_retake', me.allow_retake,
                'start_at', me.start_at,
                'end_at', me.end_at,
                'created_at', me.created_at,
                'updated_at', me.updated_at,
                'folder_id', me.folder_id,
                'pdf_file_id', me.pdf_file_id,
                'pdf_file_name', epd.pdf_file_name,
                'pdf_file_size', epd.pdf_file_size,
                'pdf_storage_path', epd.pdf_storage_path,
                'pdf_storage_provider', epd.pdf_storage_provider,
                'attempts_count', COALESCE(es.attempts_count, 0),
                'exam_versions', COALESCE(eva.versions_json, '[]'::jsonb)
            ) ORDER BY me.created_at DESC
        ),
        '[]'::jsonb
    ) INTO v_result
    FROM matched_exams me
    LEFT JOIN exam_stats es ON es.exam_id = me.id
    LEFT JOIN exam_versions_agg eva ON eva.exam_id = me.id
    LEFT JOIN exam_pdf_data epd ON epd.exam_id = me.id;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_teacher_group_exams(uuid, int, int) TO authenticated;
