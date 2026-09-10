-- ============================================================================
-- 0002_exam_rpc.sql — Atomic Exam Execution, Versioning & Attempt Security
-- المصدر: الوثيقة المرجعية الموحدة (الأقسام 4.3، 5.2، 7.3، 7.4، 7.5، 11.3)
-- ============================================================================

-- 1) Partial Unique Index: منع وجود أكثر من محاولة نشطة لنفس الطالب ونفس الامتحان
create unique index if not exists idx_exam_attempts_one_active
  on public.exam_attempts (exam_id, student_id)
  where status = 'in_progress';

-- 2) start_exam: بدء محاولة امتحان مع تثبيت الوقت والنسخة وترتيب الأسئلة وحجب الإجابات الصحيحة
create or replace function public.start_exam(p_exam_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid := auth.uid();
  v_tenant_id uuid;
  v_exam record;
  v_version record;
  v_active_attempt record;
  v_attempt_id uuid;
  v_questions jsonb;
begin
  if v_student_id is null then
    raise exception 'AUTH_REQUIRED: User must be authenticated';
  end if;

  -- استخراج tenant_id للطالب والتحقق من نشاط حسابه
  select tenant_id into v_tenant_id from public.users where id = v_student_id and status = 'active';
  if v_tenant_id is null then
    raise exception 'NOT_AUTHORIZED: Active student profile required';
  end if;

  -- فحص بيانات الامتحان والمحتوى التابع له
  select e.*, c.group_id, c.status as content_status into v_exam
  from public.exams e
  join public.content c on c.id = e.content_id
  where e.id = p_exam_id and e.tenant_id = v_tenant_id;

  if v_exam.id is null then
    raise exception 'EXAM_NOT_FOUND: Exam does not exist';
  end if;

  if v_exam.content_status != 'published' then
    raise exception 'NOT_AUTHORIZED: Exam is not published';
  end if;

  -- فحص نافذة الوقت (start_at / end_at) إن وُجدت
  if v_exam.start_at is not null and now() < v_exam.start_at then
    raise exception 'EXAM_NOT_STARTED: Exam start time is in the future';
  end if;

  if v_exam.end_at is not null and now() > v_exam.end_at then
    raise exception 'EXAM_EXPIRED: Exam window has passed';
  end if;

  -- فحص عضوية الطالب في المجموعة وسياسة المحتوى السابق
  if not exists (
    select 1 from public.group_members gm
    where gm.student_id = v_student_id
      and gm.group_id = v_exam.group_id
      and gm.status = 'active'
  ) then
    raise exception 'NOT_AUTHORIZED: Student is not an active member of this group';
  end if;

  -- فحص إذا كانت هناك محاولة قيد التنفيذ بالفعل (استئناف آمن)
  select * into v_active_attempt
  from public.exam_attempts
  where exam_id = p_exam_id and student_id = v_student_id and status = 'in_progress';

  if v_active_attempt.id is not null then
    -- فحص انتهاء الوقت للمحاولة الحالية
    if (v_active_attempt.started_at + (v_exam.duration_minutes || ' minutes')::interval) < now() then
      update public.exam_attempts
      set status = 'expired'
      where id = v_active_attempt.id;
    else
      -- المحاولة لا تزال نشطة وصالحة: إرجاع نفس المحاولة والأسئلة لاستئنافها
      v_attempt_id := v_active_attempt.id;
      select * into v_version from public.exam_versions where id = v_active_attempt.exam_version_id;
    end if;
  end if;

  -- إذا لم تكن هناك محاولة نشطة صالحة: نتحقق من قيود إعادة المحاولة وننشئ محاولة جديدة
  if v_attempt_id is null then
    -- فحص إن كان الطالب قد سلّم محاولات سابقة ولا يُسمح بالإعادة
    if not v_exam.allow_retake and exists (
      select 1 from public.exam_attempts
      where exam_id = p_exam_id and student_id = v_student_id and status in ('submitted', 'expired')
    ) then
      raise exception 'ATTEMPTS_LIMIT_REACHED: Retake is not allowed for this exam';
    end if;

    -- جلب النسخة المنشورة الحديثة المجمدة (Snapshot)
    select * into v_version
    from public.exam_versions
    where exam_id = p_exam_id and status = 'published'
    order by version_number desc
    limit 1;

    if v_version.id is null then
      raise exception 'EXAM_NOT_FOUND: No published version available for this exam';
    end if;

    -- إنشاء المحاولة بـ started_at خادمي حصرياً
    insert into public.exam_attempts (
      exam_id,
      exam_version_id,
      student_id,
      started_at,
      status
    ) values (
      p_exam_id,
      v_version.id,
      v_student_id,
      now(),
      'in_progress'
    ) returning id into v_attempt_id;

    -- تسجيل نشاط exam_started
    insert into public.activity_events (
      tenant_id,
      user_id,
      group_id,
      content_id,
      event_type,
      metadata
    ) values (
      v_tenant_id,
      v_student_id,
      v_exam.group_id,
      v_exam.content_id,
      'exam_started',
      jsonb_build_object('attempt_id', v_attempt_id, 'version_id', v_version.id)
    );
  end if;

  -- بناء قائمة الأسئلة والخيارات الآمنة (بدون حقل is_correct إطلاقاً!)
  -- دعم shuffle_questions إذا كان مفعّلاً
  select coalesce(jsonb_agg(q_item), '[]'::jsonb) into v_questions
  from (
    select
      eq.id,
      eq.question_text,
      eq.question_type,
      eq.points,
      eq.sort_order,
      (
        select coalesce(jsonb_agg(
          jsonb_build_object(
            'id', qo.id,
            'option_text', qo.option_text,
            'sort_order', qo.sort_order
          ) order by qo.sort_order
        ), '[]'::jsonb)
        from public.question_options qo
        where qo.question_id = eq.id
      ) as options
    from public.exam_questions eq
    where eq.exam_version_id = v_version.id
    order by case when v_exam.shuffle_questions then random() else eq.sort_order end
  ) q_item;

  return jsonb_build_object(
    'attempt_id', v_attempt_id,
    'exam_version_id', v_version.id,
    'started_at', coalesce(v_active_attempt.started_at, now()),
    'duration_minutes', v_exam.duration_minutes,
    'show_result', v_exam.show_result,
    'questions', v_questions
  );
end;
$$;

-- 3) submit_exam: تصحيح الامتحان الذري وحساب الدرجة خادمياً وحفظ الإجابات
create or replace function public.submit_exam(p_attempt_id uuid, p_answers jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid := auth.uid();
  v_attempt record;
  v_exam record;
  v_version record;
  v_ans_record record;
  v_question record;
  v_selected_option record;
  v_is_correct boolean;
  v_points_earned numeric(8,2);
  v_total_score numeric(8,2) := 0;
  v_max_score numeric(8,2) := 0;
  v_percentage numeric(5,2) := 0;
  v_status text;
begin
  if v_student_id is null then
    raise exception 'AUTH_REQUIRED: User must be authenticated';
  end if;

  -- فحص ملكية المحاولة وحالتها
  select * into v_attempt
  from public.exam_attempts
  where id = p_attempt_id and student_id = v_student_id;

  if v_attempt.id is null then
    raise exception 'ATTEMPT_NOT_FOUND: Attempt does not exist';
  end if;

  -- حماية Idempotency: لو سُلّمت المحاولة مسبقاً، تُرجع نتيجتها المحفوظة دون إعادة الحساب
  if v_attempt.status in ('submitted', 'expired') then
    select show_result into v_exam from public.exams where id = v_attempt.exam_id;
    return jsonb_build_object(
      'attempt_id', v_attempt.id,
      'status', v_attempt.status,
      'score', case when v_exam.show_result then v_attempt.score else null end,
      'percentage', case when v_exam.show_result then v_attempt.percentage else null end
    );
  end if;

  -- جلب بيانات الامتحان والمحتوى
  select e.*, c.group_id into v_exam
  from public.exams e
  join public.content c on c.id = e.content_id
  where e.id = v_attempt.exam_id;

  -- التحقق من التوقيت الخادمي
  if (v_attempt.started_at + (v_exam.duration_minutes || ' minutes')::interval) < now() then
    v_status := 'expired';
  else
    v_status := 'submitted';
  end if;

  -- مسح أي إجابات سابقة لنفس المحاولة لضمان الذرية التامة
  delete from public.exam_answers where attempt_id = p_attempt_id;

  -- معالجة وتصحيح كل إجابة بدقة بالغة
  for v_question in
    select eq.id, eq.points
    from public.exam_questions eq
    where eq.exam_version_id = v_attempt.exam_version_id
  loop
    v_max_score := v_max_score + v_question.points;

    -- استخراج الخيار الذي حدده الطالب لهذا السؤال من مصفوفة الإجابات
    select value::text into v_selected_option
    from jsonb_each_text(p_answers)
    where key = v_question.id::text;

    if v_selected_option is not null and v_selected_option != '' then
      -- التحقق من صحة الخيار المحفوظ في قاعدة البيانات
      select qo.is_correct into v_is_correct
      from public.question_options qo
      where qo.id = v_selected_option::uuid and qo.question_id = v_question.id;

      if v_is_correct is true then
        v_points_earned := v_question.points;
        v_total_score := v_total_score + v_points_earned;
      else
        v_is_correct := false;
        v_points_earned := 0;
      end if;

      -- تسجيل الإجابة بدقة مع تثبيت النقاط تاريخياً
      insert into public.exam_answers (
        attempt_id,
        question_id,
        selected_option_id,
        is_correct,
        points_earned,
        answered_at
      ) values (
        p_attempt_id,
        v_question.id,
        v_selected_option::uuid,
        v_is_correct,
        v_points_earned,
        now()
      );
    else
      -- لم يُجب الطالب على هذا السؤال
      insert into public.exam_answers (
        attempt_id,
        question_id,
        selected_option_id,
        is_correct,
        points_earned,
        answered_at
      ) values (
        p_attempt_id,
        v_question.id,
        null,
        false,
        0,
        now()
      );
    end if;
  end loop;

  -- حساب النسبة المئوية
  if v_max_score > 0 then
    v_percentage := round((v_total_score / v_max_score) * 100, 2);
  else
    v_percentage := 0;
  end if;

  -- تحديث المحاولة بالنتيجة المحسوبة خادمياً
  update public.exam_attempts
  set
    submitted_at = now(),
    status = v_status,
    score = round(v_total_score)::integer,
    percentage = v_percentage
  where id = p_attempt_id;

  -- تسجيل نشاط exam_submitted
  insert into public.activity_events (
    tenant_id,
    user_id,
    group_id,
    content_id,
    event_type,
    metadata
  ) values (
    v_exam.tenant_id,
    v_student_id,
    v_exam.group_id,
    v_exam.content_id,
    'exam_submitted',
    jsonb_build_object(
      'attempt_id', p_attempt_id,
      'score', round(v_total_score)::integer,
      'percentage', v_percentage,
      'status', v_status
    )
  );

  return jsonb_build_object(
    'attempt_id', p_attempt_id,
    'status', v_status,
    'score', case when v_exam.show_result then round(v_total_score)::integer else null end,
    'percentage', case when v_exam.show_result then v_percentage else null end
  );
end;
$$;
