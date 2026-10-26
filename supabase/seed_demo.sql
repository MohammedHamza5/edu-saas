-- ============================================================================
-- EduSaaS: Seed Demo Sandbox (Multi-Tenant Demo Environment)
-- Tenant ID: 11111111-1111-1111-1111-111111111111
-- Description:
-- Sets up the complete VIP Demo environment with:
-- 1. Demo Tenant (American Math Platform)
-- 2. Teacher & Student accounts in auth.users and public.users
-- 3. Active Group (Digital SAT Elite)
-- 4. Authentic Digital SAT Math Exam (Desmos, Formula Sheet, Scratchpad enabled)
-- 5. Pre-graded attempt with mistakes for testing Anki Drills & WhatsApp Dispatch
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ── 1. Create or Update Demo Tenant ──────────────────────────────────────────
INSERT INTO public.tenants (
  id,
  name,
  logo_url,
  email,
  phone,
  status,
  created_at,
  updated_at
) VALUES (
  '11111111-1111-1111-1111-111111111111'::uuid,
  'منصة رياضيات الدبلومة الأمريكية (نسخة تجريبية)',
  'https://antounios.edsentre.com/assets/images/dr_antounios_logo.png',
  'demo@edsentre.com',
  '+201000000000',
  'active',
  now(),
  now()
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  status = 'active',
  updated_at = now();

-- ── 2. Create Auth Users (Encrypted Passwords: Demo@2026!) ────────────────────
DO $$
DECLARE
  v_encrypted_pw text := crypt('Demo@2026!', gen_salt('bf'));
  v_teacher_id uuid := '10000000-0000-0000-0000-000000000001'::uuid;
  v_student1_id uuid := '20000000-0000-0000-0000-000000000001'::uuid;
  v_student2_id uuid := '20000000-0000-0000-0000-000000000002'::uuid;
BEGIN
  -- 2.1 Teacher Account: demo.teacher@edsentre.com
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'demo.teacher@edsentre.com') THEN
    INSERT INTO auth.users (
      id, instance_id, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
    ) VALUES (
      v_teacher_id, '00000000-0000-0000-0000-000000000000'::uuid,
      'demo.teacher@edsentre.com', v_encrypted_pw, now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"full_name":"أ. محمد عبد الله (معاينة المنصة)","role":"teacher","tenant_id":"11111111-1111-1111-1111-111111111111"}'::jsonb,
      now(), now(), 'authenticated', 'authenticated'
    );
  END IF;

  -- 2.2 Student 1 (Fresh): demo.student1@edsentre.com
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'demo.student1@edsentre.com') THEN
    INSERT INTO auth.users (
      id, instance_id, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
    ) VALUES (
      v_student1_id, '00000000-0000-0000-0000-000000000000'::uuid,
      'demo.student1@edsentre.com', v_encrypted_pw, now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"full_name":"كريم أحمد (طالب جديد - حل الامتحان)","role":"student","tenant_id":"11111111-1111-1111-1111-111111111111","parent_phone":"+201012345678"}'::jsonb,
      now(), now(), 'authenticated', 'authenticated'
    );
  END IF;

  -- 2.3 Student 2 (With Mistakes): demo.student2@edsentre.com
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'demo.student2@edsentre.com') THEN
    INSERT INTO auth.users (
      id, instance_id, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
    ) VALUES (
      v_student2_id, '00000000-0000-0000-0000-000000000000'::uuid,
      'demo.student2@edsentre.com', v_encrypted_pw, now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"full_name":"سارة محمود (طالبة - معاينة الأخطاء والواتساب)","role":"student","tenant_id":"11111111-1111-1111-1111-111111111111","parent_phone":"+201098765432"}'::jsonb,
      now(), now(), 'authenticated', 'authenticated'
    );
  END IF;
END $$;

-- ── 3. Upsert Public Profiles in public.users ─────────────────────────────────
INSERT INTO public.users (
  id, tenant_id, role, full_name, email, phone, parent_phone, status, created_at, updated_at
)
SELECT 
  u.id,
  '11111111-1111-1111-1111-111111111111'::uuid,
  (u.raw_user_meta_data->>'role')::text,
  (u.raw_user_meta_data->>'full_name')::text,
  u.email,
  '+201000000000',
  (u.raw_user_meta_data->>'parent_phone')::text,
  'active',
  now(),
  now()
FROM auth.users u
WHERE u.email IN ('demo.teacher@edsentre.com', 'demo.student1@edsentre.com', 'demo.student2@edsentre.com')
ON CONFLICT (id) DO UPDATE SET
  tenant_id = '11111111-1111-1111-1111-111111111111'::uuid,
  role = EXCLUDED.role,
  full_name = EXCLUDED.full_name,
  parent_phone = EXCLUDED.parent_phone,
  status = 'active',
  updated_at = now();

-- ── 4. Create Group & Assign Members ──────────────────────────────────────────
INSERT INTO public.groups (
  id, tenant_id, name, level, description, previous_content_access, status, created_at, updated_at
) VALUES (
  '30000000-0000-0000-0000-000000000001'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid,
  'Digital SAT Elite • Class of 2026',
  'Grade 11 - 12',
  'مجموعة النخبة المكثفة لاختبارات الـ Digital SAT ومحاكاة بيئة الـ Bluebook',
  'allow',
  'active',
  now(),
  now()
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  status = 'active';

-- Link students to the group
INSERT INTO public.group_members (group_id, student_id, joined_at, status)
SELECT 
  '30000000-0000-0000-0000-000000000001'::uuid,
  u.id,
  now(),
  'active'
FROM auth.users u
WHERE u.email IN ('demo.student1@edsentre.com', 'demo.student2@edsentre.com')
ON CONFLICT (group_id, student_id) DO UPDATE SET status = 'active';

-- ── 5. Create Authentic Digital SAT Exam with Questions ───────────────────────
-- 5.1 Content Item
INSERT INTO public.content (
  id, tenant_id, group_id, title, description, type, status, sort_order, published_at, created_at, updated_at
) VALUES (
  '40000000-0000-0000-0000-000000000001'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid,
  '30000000-0000-0000-0000-000000000001'::uuid,
  'Digital SAT Math Practice #1 (Official Desmos & Formula Sheet)',
  'اختبار محاكاة رسمي لموديول الرياضيات مع حاسبة Desmos والمسودة الرقمية وورقة القوانين المعتمدة',
  'exam',
  'published',
  1,
  now(),
  now(),
  now()
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  status = 'published';

-- 5.2 Exam Settings
INSERT INTO public.exams (
  id, content_id, tenant_id, duration_minutes, max_score, passing_score,
  shuffle_questions, show_result, allow_retake, created_at, updated_at
) VALUES (
  '40000000-0000-0000-0000-000000000001'::uuid,
  '40000000-0000-0000-0000-000000000001'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid,
  25,
  800,
  500,
  true,
  true,
  true, -- Allows multiple test retakes for prospective teachers!
  now(),
  now()
)
ON CONFLICT (id) DO UPDATE SET
  allow_retake = true,
  show_result = true,
  duration_minutes = 25;

-- 5.3 Exam Version (Published Snapshot)
INSERT INTO public.exam_versions (
  id, exam_id, version_number, status, published_at, created_at
) VALUES (
  '60000000-0000-0000-0000-000000000001'::uuid,
  '40000000-0000-0000-0000-000000000001'::uuid,
  1,
  'published',
  now(),
  now()
)
ON CONFLICT (id) DO UPDATE SET
  status = 'published';

-- ── 6. Authentic SAT Math Questions ──────────────────────────────────────────
-- Clean previous child records in correct dependency order
DELETE FROM public.student_mistakes WHERE tenant_id = '11111111-1111-1111-1111-111111111111'::uuid;

DELETE FROM public.exam_answers WHERE attempt_id IN (
  SELECT id FROM public.exam_attempts WHERE exam_version_id = '60000000-0000-0000-0000-000000000001'::uuid
    OR student_id IN ('20000000-0000-0000-0000-000000000001'::uuid, '20000000-0000-0000-0000-000000000002'::uuid)
) OR question_id IN (
  SELECT id FROM public.exam_questions WHERE exam_version_id = '60000000-0000-0000-0000-000000000001'::uuid
);

DELETE FROM public.exam_attempts WHERE exam_version_id = '60000000-0000-0000-0000-000000000001'::uuid
  OR student_id IN ('20000000-0000-0000-0000-000000000001'::uuid, '20000000-0000-0000-0000-000000000002'::uuid)
  OR exam_id IN ('40000000-0000-0000-0000-000000000001'::uuid, '50000000-0000-0000-0000-000000000001'::uuid);

DELETE FROM public.question_options WHERE question_id IN (
  SELECT id FROM public.exam_questions WHERE exam_version_id = '60000000-0000-0000-0000-000000000001'::uuid
);
DELETE FROM public.exam_questions WHERE exam_version_id = '60000000-0000-0000-0000-000000000001'::uuid;

-- Question 1: Heart of Algebra
INSERT INTO public.exam_questions (
  id, exam_version_id, question_text, question_type, points, sort_order
) VALUES (
  '70000000-0000-0000-0000-000000000001'::uuid,
  '60000000-0000-0000-0000-000000000001'::uuid,
  'If 4x + 12 = 36, what is the value of 2x - 3 ?',
  'multiple_choice',
  160,
  1
);
INSERT INTO public.question_options (id, question_id, option_text, sort_order, is_correct) VALUES
  (gen_random_uuid(), '70000000-0000-0000-0000-000000000001'::uuid, '6', 1, false),
  ('80000000-0000-0000-0000-000000000001'::uuid, '70000000-0000-0000-0000-000000000001'::uuid, '9', 2, true),
  (gen_random_uuid(), '70000000-0000-0000-0000-000000000001'::uuid, '12', 3, false),
  (gen_random_uuid(), '70000000-0000-0000-0000-000000000001'::uuid, '15', 4, false);

-- Question 2: Advanced Math (Quadratic Function & Vertex)
INSERT INTO public.exam_questions (
  id, exam_version_id, question_text, question_type, points, sort_order
) VALUES (
  '70000000-0000-0000-0000-000000000002'::uuid,
  '60000000-0000-0000-0000-000000000001'::uuid,
  'The function f is defined by f(x) = (x - 5)^2 + 4. What is the minimum value of f(x) on the xy-plane? (Tip: Use the embedded Desmos calculator to graph and verify)',
  'multiple_choice',
  160,
  2
);
INSERT INTO public.question_options (id, question_id, option_text, sort_order, is_correct) VALUES
  ('80000000-0000-0000-0000-000000000002'::uuid, '70000000-0000-0000-0000-000000000002'::uuid, '4', 1, true),
  (gen_random_uuid(), '70000000-0000-0000-0000-000000000002'::uuid, '5', 2, false),
  (gen_random_uuid(), '70000000-0000-0000-0000-000000000002'::uuid, '-4', 3, false),
  (gen_random_uuid(), '70000000-0000-0000-0000-000000000002'::uuid, '9', 4, false);

-- Question 3: Geometry (Circle Area & Formula Sheet)
INSERT INTO public.exam_questions (
  id, exam_version_id, question_text, question_type, points, sort_order
) VALUES (
  '70000000-0000-0000-0000-000000000003'::uuid,
  '60000000-0000-0000-0000-000000000001'::uuid,
  'A circle has a diameter of 16 cm. What is the area of the circle, in square centimeters? (Click the Formula Sheet icon above to reference standard geometric formulas)',
  'multiple_choice',
  160,
  3
);
INSERT INTO public.question_options (id, question_id, option_text, sort_order, is_correct) VALUES
  (gen_random_uuid(), '70000000-0000-0000-0000-000000000003'::uuid, '16π', 1, false),
  (gen_random_uuid(), '70000000-0000-0000-0000-000000000003'::uuid, '32π', 2, false),
  ('80000000-0000-0000-0000-000000000003'::uuid, '70000000-0000-0000-0000-000000000003'::uuid, '64π', 3, true),
  (gen_random_uuid(), '70000000-0000-0000-0000-000000000003'::uuid, '256π', 4, false);

-- Question 4: Problem Solving & Data Analysis (Percentages)
INSERT INTO public.exam_questions (
  id, exam_version_id, question_text, question_type, points, sort_order
) VALUES (
  '70000000-0000-0000-0000-000000000004'::uuid,
  '60000000-0000-0000-0000-000000000001'::uuid,
  'A course price was increased by 20%, and then discounted by 20% for a seasonal sale. Compared to the original price, the final price is:',
  'multiple_choice',
  160,
  4
);
INSERT INTO public.question_options (id, question_id, option_text, sort_order, is_correct) VALUES
  (gen_random_uuid(), '70000000-0000-0000-0000-000000000004'::uuid, 'The same as the original price', 1, false),
  ('80000000-0000-0000-0000-000000000004'::uuid, '70000000-0000-0000-0000-000000000004'::uuid, '4% lower than original', 2, true),
  (gen_random_uuid(), '70000000-0000-0000-0000-000000000004'::uuid, '4% higher than original', 3, false),
  (gen_random_uuid(), '70000000-0000-0000-0000-000000000004'::uuid, '2% lower than original', 4, false);

-- Question 5: Passport to Advanced Math (Exponents)
INSERT INTO public.exam_questions (
  id, exam_version_id, question_text, question_type, points, sort_order
) VALUES (
  '70000000-0000-0000-0000-000000000005'::uuid,
  '60000000-0000-0000-0000-000000000001'::uuid,
  'If 2^(3x - 1) = 32, what is the value of x ?',
  'multiple_choice',
  160,
  5
);
INSERT INTO public.question_options (id, question_id, option_text, sort_order, is_correct) VALUES
  ('80000000-0000-0000-0000-000000000005'::uuid, '70000000-0000-0000-0000-000000000005'::uuid, '2', 1, true),
  (gen_random_uuid(), '70000000-0000-0000-0000-000000000005'::uuid, '3', 2, false),
  (gen_random_uuid(), '70000000-0000-0000-0000-000000000005'::uuid, '4', 3, false),
  (gen_random_uuid(), '70000000-0000-0000-0000-000000000005'::uuid, '5', 4, false);

-- ── 7. Seed Student 2 Graded Attempt & Mistake Vault (Anki Ready) ─────────────
-- Delete any old demo attempts and answers
DELETE FROM public.exam_answers WHERE attempt_id = '90000000-0000-0000-0000-000000000001'::uuid;
DELETE FROM public.exam_attempts WHERE student_id = '20000000-0000-0000-0000-000000000002'::uuid;

-- Insert submitted attempt for Sarah (Score: 480/800 = 60%, 2 mistakes)
INSERT INTO public.exam_attempts (
  id, exam_id, exam_version_id, student_id, started_at, submitted_at,
  status, score, percentage
) VALUES (
  '90000000-0000-0000-0000-000000000001'::uuid,
  '40000000-0000-0000-0000-000000000001'::uuid,
  '60000000-0000-0000-0000-000000000001'::uuid,
  '20000000-0000-0000-0000-000000000002'::uuid,
  now() - interval '30 minutes',
  now() - interval '8 minutes',
  'submitted',
  480,
  60.0
);

-- Seed answers for Sarah
INSERT INTO public.exam_answers (
  attempt_id, question_id, selected_option_id, is_correct, points_earned, answered_at
) VALUES
  -- Q1: Correct
  ('90000000-0000-0000-0000-000000000001'::uuid, '70000000-0000-0000-0000-000000000001'::uuid, '80000000-0000-0000-0000-000000000001'::uuid, true, 160, now()),
  -- Q2: Wrong (Selected option -4 instead of 4)
  ('90000000-0000-0000-0000-000000000001'::uuid, '70000000-0000-0000-0000-000000000002'::uuid, null, false, 0, now()),
  -- Q3: Correct
  ('90000000-0000-0000-0000-000000000001'::uuid, '70000000-0000-0000-0000-000000000003'::uuid, '80000000-0000-0000-0000-000000000003'::uuid, true, 160, now()),
  -- Q4: Wrong (Selected 'The same as original')
  ('90000000-0000-0000-0000-000000000001'::uuid, '70000000-0000-0000-0000-000000000004'::uuid, null, false, 0, now()),
  -- Q5: Correct
  ('90000000-0000-0000-0000-000000000001'::uuid, '70000000-0000-0000-0000-000000000005'::uuid, '80000000-0000-0000-0000-000000000005'::uuid, true, 160, now());

-- Seed Mistake Vault for Sarah (Q2 and Q4 ready for Anki Drills)
DELETE FROM public.student_mistakes WHERE student_id = '20000000-0000-0000-0000-000000000002'::uuid;

INSERT INTO public.student_mistakes (
  id, tenant_id, student_id, question_id, source_exam_id, source_attempt_id,
  selected_option_id, is_resolved, first_failed_at, last_failed_at, failure_count
) VALUES
  (
    gen_random_uuid(),
    '11111111-1111-1111-1111-111111111111'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    '70000000-0000-0000-0000-000000000002'::uuid,
    '40000000-0000-0000-0000-000000000001'::uuid,
    '90000000-0000-0000-0000-000000000001'::uuid,
    null,
    false,
    now(),
    now(),
    1
  ),
  (
    gen_random_uuid(),
    '11111111-1111-1111-1111-111111111111'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    '70000000-0000-0000-0000-000000000004'::uuid,
    '40000000-0000-0000-0000-000000000001'::uuid,
    '90000000-0000-0000-0000-000000000001'::uuid,
    null,
    false,
    now(),
    now(),
    1
  );

-- Done!
SELECT '🎉 VIP Demo Environment Seeded Successfully!' AS status;
