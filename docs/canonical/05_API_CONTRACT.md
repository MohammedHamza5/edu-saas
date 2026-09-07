---
> **Canonical v1.0 · 2026-09-06 · المعتمد الوحيد** — هذه النسخة تحل محل أي ملف قديم بنفس الاسم أو الغرض.
---

# عقد التكامل مع الـBackend — Edge Functions + Repository

> المرجع: الوثيقة القسم 11. **المبدأ:** UI → Cubit → Repository (Interface) → DataSource → Supabase.
> ممنوع استدعاء Supabase داخل Widget أو داخل `build()`.

## تدفق الطبقات (إلزامي)
```text
UI (Widget) → Cubit (State فقط) → Repository (Interface) →
DataSource (Supabase تحديدًا) → Supabase
```

## 1) متى Supabase مباشرة (CRUD + RLS)
عمليات بسيطة غير حساسة: قراءة محتوى مصرّح، Groups/Students/Notifications، تحديث الملف الشخصي، قراءة Attendance/Video Progress.

## 2) متى Edge Function / RPC (إلزامي)
حساسة / متعددة الخطوات / تحتاج Secret / خدمة خارجية / لا نثق بمدخلات العميل:
`approve-student · start-exam · submit-exam · video-playback · bunny-webhook · send-notification · record-activity`

---

## 3) عقود الدوال (الإدخال/التحقق/الإخراج/الأخطاء)

### `approve-student`
- **الغرض:** اعتماد/رفض/تعليق طالب pending.
- **التحقق:** JWT → `users.role = teacher` + tenant نشط → الطالب المستهدف `pending` وبنفس الـTenant.
- **الإدخال:** `{ student_id: uuid, action: 'approve'|'reject'|'suspend'|'activate' }`
- **السلوك:** تحديث `users.status` → سجل `audit_logs` → إنشاء `notifications` (وPush عبر FCM).
- **الإخراج:** `{ ok: true, status }`

### `start-exam`
- **الغرض:** بدء محاولة امتحان — تُثبَّت النسخة ووقت البدء Server-side.
- **التحقق:** عضوية Group + `exam published` + داخل نافذة `start_at/end_at` + لا توجد Attempt نشطة (`one_active_attempt_per_student` — القسم 4.3) + عدم تجاوز حد المحاولات (`allow_retake`).
- **الإدخال:** `{ exam_id: uuid }`
- **السلوك:** (Transact) إنشاء `exam_attempt` (in_progress) → إنشاء/إرجاع ترتيب الأسئلة المثبَّت (Shuffle يُحفظ عند البدء ولا يتغير) → إرجاع أسئلة **بدون is_correct**.
- **الإخراج:** `{ attempt_id, exam_version_id, started_at, duration_minutes, questions: [{ id, text, type, points, options: [{id, text}] }] }`
- **الأخطاء:** `EXAM_NOT_FOUND · NOT_AUTHORIZED · EXAM_EXPIRED · EXAM_NOT_STARTED · ATTEMPT_ALREADY_EXISTS · ATTEMPTS_LIMIT_REACHED`

### `submit-exam` — Atomic واحدة (القسم 7.5)
- **التحقق:** ملكية الـAttempt → التوقيت (`now <= started_at + duration`) → تحميل النسخة الدقيقة → تحقق كل question/option ضمن النسخة.
- **الإدخال:** `{ attempt_id, answers: [{ question_id, selected_option_id }] }`
- **السلوك (كل شيء في Transaction واحدة):** حساب الدرجة Server-side → حفظ `exam_answers` (بـ is_correct/points_earned مثبّتة) → تحديث الـAttempt (score/percentage/status) → Idempotency (تكرار التسليم لا ينتج نتيجة ثانية) → سجل activity `exam_submitted` → Notification.
- **الإخراج:** `{ attempt_id, score, percentage, status }` (فقط عند `show_result=true`)
- **الأخطاء:** `ATTEMPT_NOT_FOUND · NOT_AUTHORIZED · EXAM_EXPIRED · EXAM_ALREADY_SUBMITTED · VALIDATION_ERROR`

### `video-playback`
- **التحقق:** عضوية Group + نشر المحتوى + سياسة previous_content + `videos.status = ready`.
- **الإدخال:** `{ video_id: uuid }`
- **السلوك:** تفويض تشغيل مؤقت من Bunny (Signed/Token) — **لا رابط دائم يعود للعميل**.
- **الإخراج:** `{ playback_url (مؤقت), expires_at, video_meta }`
- **الأخطاء:** `VIDEO_NOT_READY · NOT_AUTHORIZED · CONTENT_NOT_PUBLISHED`

### `bunny-webhook`
- **المصدر:** Bunny (server-to-server) — يتحقق من `BUNNY_WEBHOOK_SECRET`.
- **السلوك:** تحديث `videos.status` (uploading→processing→ready/failed) حسب أحداث Bunny → تخزين `provider_video_id/thumbnail_url/duration`.
- **الإخراج:** `{ ok: true }`

### `send-notification`
- **الغرض:** إشعارات Announcement من المدرس + إشعارات النظام.
- **التحقق:** Teacher (للـAnnouncement) + ملكية الـTenant.
- **الإدخال:** `{ type, title, body, target: 'all'|{group_id}, data? }` — **لا بيانات حساسة في title/body** (القسم 9.6).
- **السلوك:** إنشاء `notifications` + `notification_recipients` لكل مستخدم مستهدف → محاولة Push (FCM Web/Android/iOS) → لا يُحذف الإشعار عند فشل الـPush (يبقى In-App).

### `record-activity`
- **الغرض:** تسجيل أحداث Whitelist فقط (القسم 8.1): login, content_opened, video_started, video_completed, assignment_submitted, exam_started, exam_submitted — **لا** click/scroll/hover.
- **الإدخال:** `{ event_type, group_id?, content_id?, metadata? }`
- **السلوك:** Idempotent حيث أمكن + تحديث `users.last_activity_at` عند Meaningful Activity فقط.

---

## 4) Error Contract الموحّد (القسم 11.6)

### فئات أخطاء الـBackend
```text
AUTH_REQUIRED · NOT_AUTHORIZED · VALIDATION_ERROR · EXAM_EXPIRED ·
EXAM_ALREADY_SUBMITTED · ATTEMPT_ALREADY_EXISTS · ATTEMPTS_LIMIT_REACHED ·
VIDEO_NOT_READY · CONTENT_NOT_PUBLISHED · TENANT_SUSPENDED · NOT_FOUND
```

### خريطة التحويل (Backend → AppException → حالة UI)
| Backend | AppException | حالة UI |
|---|---|---|
| AUTH_REQUIRED | AuthException | توجيه لتسجيل الدخول |
| NOT_AUTHORIZED / TENANT_SUSPENDED | PermissionException | رسالة "لا تملك صلاحية" / شاشة معلّق |
| VALIDATION_ERROR | ValidationException | رسائل الحقول |
| EXAM_EXPIRED | ExamExpiredException | "انتهى وقت الامتحان" + عرض ما حُفظ |
| EXAM_ALREADY_SUBMITTED | ExamAlreadySubmittedException | عرض النتيجة الحالية |
| ATTEMPT_ALREADY_EXISTS | ConflictException | استئناف المحاولة الموجودة |
| VIDEO_NOT_READY | VideoNotReadyException | "الفيديو قيد المعالجة" |
| أي خطأ شبكة | NetworkException | Retry محدود (2-3) ثم رسالة |

> لا يُعرض Stack Trace خام للمستخدم أبدًا.

## 5) تسمية الـRepository (مثال)
```text
AuthRepository          usersRepository
StudentsRepository      GroupsRepository
ContentRepository       FilesRepository
VideoRepository (بما فيه Player abstraction)
AssignmentsRepository   ExamsRepository
AttendanceRepository    ActivityRepository
NotificationsRepository ParentRepository
```

## 6) Secrets (لا استثناء)
`SUPABASE_SERVICE_ROLE_KEY · BUNNY_API_KEY · BUNNY_WEBHOOK_SECRET · FCM_SERVER_CREDENTIALS`
= داخل Edge Function Secrets فقط. **لا تدخل Flutter/.env ضمن Build/GitHub أبدًا.**
