---
> **Canonical v1.0 · 2026-09-06 · المعتمد الوحيد** — هذه النسخة تحل محل أي ملف قديم بنفس الاسم أو الغرض.
---

# 02 — نموذج البيانات (المرجع من الوثيقة القسم 4 — الـSQL الكامل في supabase/migrations/0001_init.sql)

## مبادئ عامة
- كل PK من نوع `uuid` عبر `gen_random_uuid()` — **ما عدا** `users.id` = `auth.users.id` تمامًا.
- `created_at`/`updated_at`: `timestamptz` بتوقيت UTC دائمًا (التحويل المحلي في التطبيق فقط).
- **لا PostgreSQL ENUM صارم** — `text` + تطبيق/تحقق على مستوى DB (مرونة التوسع).
- **لا Hard Delete** للبيانات ذات القيمة التاريخية (Content/Assignment/Exam/Group/User) → `status = archived/suspended`.
- Data Race Fix: Partial Unique Index على `exam_attempts` (انظر أدناه).

## الجداول (24)
| الجدول | أهم الأعمدة | قيود/ملاحظات حاسمة |
|---|---|---|
| tenants | name, logo_url, email, phone, status | status: `active`/`suspended` (سلوك 3.6) |
| users | tenant_id FK, role, full_name, email, phone, avatar_url, status, last_activity_at | id = auth.users.id؛ role: teacher/student/parent؛ status: pending/active/rejected/suspended |
| groups | tenant_id, name, level, description, **previous_content_access** (`allow`/`deny`), status | سياسة سابقة على مستوى الـGroup |
| group_members | group_id, student_id, joined_at, status | `UNIQUE(group_id, student_id)`؛ joined_at = مرجع "المحتوى السابق" |
| parent_students | parent_id, student_id, relationship | `UNIQUE(parent_id, student_id)` |
| content | tenant_id, group_id, title, description, type (video/pdf/image/assignment/exam), status (draft/published/archived), sort_order, published_at | المحتوى ملك للـGroup؛ لا يرى الطالب draft أبدًا |
| files | tenant_id, content_id, storage_path, file_name, mime_type, file_size | Metadata فقط؛ الملف الفعلي في Storage |
| videos | content_id, provider (`bunny`), provider_video_id, thumbnail_url, duration, status | status: uploading/processing/ready/failed/deleted؛ **لا Publish قبل ready** |
| assignments | content_id, tenant_id, instructions, due_at, allow_late_submission, max_score | |
| assignment_submissions | assignment_id, student_id, attempt_number, submitted_at, status, score, teacher_feedback, reviewed_at/by | `UNIQUE(assignment_id, student_id, attempt_number)` (تحسين اختياري: submission حي + submission_history — ينفَّذ بمراجعة) |
| submission_files | submission_id, storage_path, file_name, mime_type, file_size | عدة ملفات لكل تسليم |
| exams | content_id, tenant_id, duration_minutes, max_score, passing_score, shuffle_questions, show_result, allow_retake, start_at, end_at | |
| **exam_versions** | exam_id, version_number, status (draft/published/archived), published_at | **Published = Snapshot غير قابل للتعديل** — أي تعديل جوهري = Version جديدة |
| exam_questions | **exam_version_id** (وليست exam_id مباشرة!), question_text, question_type (multiple_choice/true_false), points, sort_order | |
| question_options | question_id, option_text, sort_order, **is_correct** | is_correct **ممنوع أن يصل للطالب** في أي Response (Repository/DTO) |
| exam_attempts | exam_id, exam_version_id, student_id, started_at (Server-side), submitted_at, status (in_progress/submitted/expired), score, percentage | score/percentage تُحسب Server-side فقط؛ **`UNIQUE (exam_id, student_id) WHERE status='in_progress'` (Partial Unique Index)** |
| exam_answers | attempt_id, question_id, selected_option_id, is_correct, points_earned, answered_at | الطالب يرسل selected_option_id فقط؛ is_correct/points تُثبَّت Server-side وقت التسليم (Historical Integrity) |
| attendance | tenant_id, group_id, student_id, date, status (present/absent/late/excused), marked_at, marked_by, note | `UNIQUE(group_id, student_id, date)`؛ بدون session_id في V1 |
| activity_events | tenant_id, user_id, group_id, content_id, event_type, metadata jsonb | Whitelist: login, content_opened, video_started, video_completed, assignment_submitted, exam_started, exam_submitted |
| video_progress | tenant_id, video_id, student_id, progress_seconds, duration_seconds, percentage, completed, last_watched_at | `UNIQUE(video_id, student_id)` — UPSERT دائمًا |
| notifications | tenant_id, title, body, type, data jsonb | لا بيانات حساسة في title/body |
| notification_recipients | notification_id, user_id, **read_at** (NULL=غير مقروء) | لا boolean is_read |
| user_devices | user_id, platform, push_token, is_active, last_seen_at | عدة أجهزة لكل مستخدم |
| audit_logs | tenant_id, actor_user_id, action, entity_type, entity_id, metadata | **غير قابل للتعديل/الحذف حتى من Teacher** |

## الفهارس (4.4)
```sql
users(tenant_id), users(tenant_id, role), users(tenant_id, status)
groups(tenant_id) · group_members(group_id, student_id) UNIQUE · group_members(student_id)
parent_students(parent_id), parent_students(student_id)
content(tenant_id, group_id), content(group_id, status), content(group_id, published_at)
assignments(content_id) · assignment_submissions(assignment_id, student_id)
exams(content_id) · exam_versions(exam_id) · exam_questions(exam_version_id)
exam_attempts(exam_id, student_id) + PARTIAL UNIQUE (in_progress)
attendance(group_id, date), attendance(student_id, date)
activity_events(user_id, created_at), activity_events(tenant_id, created_at)
video_progress(video_id, student_id) UNIQUE
notifications(tenant_id, created_at) · notification_recipients(user_id, read_at)
```
القاعدة: Index حسب الـQueries الفعلية، وليس Index لكل عمود.

## قواعد منطق الأعمال الحاسمة
1. **Exam Versioning:** Published = Snapshot. المحاولة مرتبطة بـ`exam_version_id` الدقيق. النتيجة القديمة لا تتغير مهما تغيّر الامتحان.
2. **التوقيت Server-side فقط:** `server_now <= started_at + duration_minutes`. انتهاء الوقت → `expired` مع حفظ آخر الإجابات.
3. **Submission Atomic + Idempotent:** Validate ownership → timing → load exact version → validate answers → حساب Server-side → save → commit (الكل أو لا شيء).
4. **Retake:** `allow_retake=true` → أكثر من محاولة؛ المعروض = **أعلى درجة**.
5. **Shuffle ثابت وقت بداية الـAttempt** — الترتيب يُحفظ لكل Attempt ولا يتغير أثناءه.
6. **Previous Content:** `content.published_at` مقابل `group_members.joined_at` + سياسة الـGroup.
