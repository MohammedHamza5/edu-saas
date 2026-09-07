---
> **Canonical v1.0 · 2026-09-06 · المعتمد الوحيد** — هذه النسخة تحل محل أي ملف قديم بنفس الاسم أو الغرض.
---

# كتالوج المميزات والشاشات ورحلات المستخدم
# منصة SaaS التعليمية — V1

| | |
|---|---|
| **الإصدار** | 1.0 |
| **التاريخ** | 6 سبتمبر 2026 |
| **المرجع** | مستمد من الوثيقة المرجعية الموحّدة (v0.1 → v1.21) |

> **قاعدة عامة على كل الشاشات:** كل شاشة لها حالات Loading (Skeleton) / Empty / Error / Responsive. كل عملية حساسة تمر عبر Backend. Navigation مختلف تمامًا حسب الدور (Teacher/Student/Parent) — لا Dashboard واحد بشرط `if role ==`.

---

# القسم أول: خريطة المميزات (Features)

## F1 — المصادقة ودورة حياة الحساب
- تسجيل طالب → `pending` (يدخل لكن يرى شاشة انتظار فقط).
- تسجيل ولي أمر → حساب يُنشأ، والربط بالطالب يتم من المدرس فقط.
- Login، Email Verification (مستقلة عن موافقة المدرس)، Password Reset عبر Supabase Auth بالكامل.
- حالات الطالب: `pending / active / rejected / suspended` — لا حذف نهائي في V1.
- Tenant معلَّق (`suspended`): منع دخول كامل لكل مستخدميه + إبطال Sessions عند أول طلب لاحق، والمحتوى لا يُحذف.

## F2 — إدارة الطلاب (Teacher)
- قائمة طلاب الـTenant: بحث/فلترة/ترتيب على مستوى Database + Pagination.
- مراجعة طلبات التسجيل: Approve / Reject (عبر Edge Function `approve-student` مع Audit Log + إشعار).
- Suspend / Reactivate.
- إسناد عضوية Groups (خطوة منفصلة عن الموافقة — الطالب قد ينتمي لأكثر من Group).
- ملف Student 360° (راجع F11).

## F3 — المجموعات (Groups)
- CRUD للـGroups: اسم، مستوى نصي حر، وصف، حالة.
- سياسة **المحتوى السابق** لكل Group كاملة: `allow / deny` — المرجع الزمني هو `joined_at` الخاص بالعضوية مقابل `published_at` للمحتوى.
- إدارة الأعضاء: إضافة/إزالة (الطالب **لا يضيف نفسه** أبدًا).

## F4 — المحتوى (Content)
- الأنواع: `video / pdf / image / assignment / exam`.
- دورة الحياة: `Draft` (لا يظهر لأي طالب حتى لو عرف الـID) → `Published` → `Archived`.
- المحتوى ملك للـGroup كاملة، ويُرتَّب يدويًا (`sort_order`) وليس بتاريخ الإنشاء.
- الملفات في Buckets خاصة، Signed URL مؤقت، قيود أنواع (PDF/JPG/JPEG/PNG) + حجم + MIME validation حقيقي.

## F5 — الفيديو
- رفع مباشر من Flutter إلى Bunny بعد تفويض Backend (لا Proxy عبر السيرفر).
- حالات: `uploading → processing → ready / failed` — **لا Publish قبل `ready`**.
- Webhook من Bunny يحدّث الحالة.
- التشغيل عبر تفويض مؤقت فقط (عضوية Group + نشر + سياسة المحتوى السابق) — **لا رابط دائم، لا Download**.
- تتبع Progress: سجل واحد لكل (طالب، فيديو) بـUPSERT، إرسال دوري throttled، **Resume** من آخر نقطة.
- التوصيف التسويقي: "Protected Streaming" — لا وعد بمنع تصوير الشاشة.

## F6 — الواجبات (Assignments)
- إنشاء: تعليمات، Group مستهدفة، موعد تسليم (`due_at`)، سماح التسليم المتأخر، الدرجة القصوى.
- تسليم الطالب: ملفات متعددة (صور + PDF) لكل تسليم، إعادة رفع مدعومة (`attempt_number` أو البديل المبسّط).
- تقييم المدرس: درجة + Feedback → إشعار للطالب.
- الحالات: `submitted / reviewed / late`.

## F7 — الامتحانات (Exams)
- أنواع الأسئلة: `multiple_choice / true_false` فقط.
- **Versioning:** النسخة المنشورة Snapshot غير قابل للتعديل؛ أي تعديل جوهري بعد الاستخدام = Version جديدة. كل Attempt مرتبطة بالـVersion الدقيقة.
- إعدادات: مدة، درجة قصوى، درجة نجاح، Shuffle (يُثبَّت وقت بدء الـAttempt)، إظهار النتيجة، Retake (السياسة: أعلى درجة).
- **التوقيت Server-side فقط** (`started_at` مرجع الحقيقة؛ مؤقّت الواجهة للعرض فقط)؛ انتهاء الوقت → `expired` مع حفظ آخر إجابات.
- **التسليم Atomic واحد:** تحقق ملكية → توقيت → تحميل الـVersion → تحقق من كل إجابة → حساب الدرجة Server-side → حفظ → Commit. Idempotent ضد التسليم المزدوج.
- `is_correct` لا يصل للطالب في أي Response. الطالب يرسل `selected_option_id` فقط.
- حماية Race Condition: Partial Unique Index (محاولة `in_progress` واحدة فقط لكل طالب/امتحان).
- Exam Draft محلي أثناء الأداء (حماية من انقطاع لحظي) — التسليم النهائي دائمًا Server-validated.

## F8 — الحضور (Attendance)
- سجل يومي بسيط لكل Group: `present / absent / late / excused` + ملاحظة.
- `UNIQUE(group_id, student_id, date)` يمنع التكرار.
- لا جدولة حصص (Sessions) في V1.

## F9 — تتبع النشاط (Activity)
- Whitelist فقط: `login, content_opened, video_started, video_completed, assignment_submitted, exam_started, exam_submitted` — لا tracking لكل تفاعل UI.
- `last_activity_at` = "آخر نشاط معروف"، وليس "وقت خروج دقيق".
- Activity ≠ Audit: الـAudit Log للأفعال الإدارية الحساسة فقط، غير قابل للتعديل أو الحذف حتى من المدرس.

## F10 — الإشعارات (Notifications)
- In-App أولًا دائمًا (DB = مصدر الحقيقة)؛ Push (FCM/Web) = وسيلة توصيل قد تفشل دون فقدان الإشعار.
- الأنواع: `new_content, assignment_created, assignment_due, assignment_reviewed, exam_published, exam_result, attendance_marked, important_announcement`.
- لا بيانات حساسة في الـPush ("نتيجتك متاحة" وليس "92/100").
- Deep Linking عبر مرجع — مع إعادة تحقق Authorization عند فتح الشاشة.
- إعلانات المدرس: عنوان + نص + استهداف (كل الطلاب أو Group) — **ليست Chat**.
- طلب إذن الإشعارات (Web) بعد شرح السبب، وليس فور فتح الموقع.

## F11 — التحليلات والتقارير
- **لا رقم سحري واحد** — الحضور/الواجبات/الامتحانات/إكمال المحتوى تظهر منفصلة دائمًا.
- "Average Progress" = متوسط إكمال الفيديوهات فقط (المحتوى القابل للقياس).
- "Completed" للفيديو = Threshold تقني واضح قرب النهاية، وليس `100%` حرفيًا ولا مجرد Play.
- Student 360°: شاشة واحدة تجمع كل شيء عن الطالب (تفصيلها في القسم الثاني).
- Parent Dashboard: ملخص مفهوم فقط.
- ❌ لا AI Risk Score، لا Heatmap، لا Export في V1.

## F12 — ربط أولياء الأمور
- المدرس يربط Parent ↔ Student (Many-to-Many من جهة الأب — أب لأكثر من طفل).
- الـParent لا يربط نفسه بنفسه أبدًا.

---

# القسم الثاني: كتالوج الشاشات

## A. شاشات عامة (مشتركة)

| # | الشاشة | الوصف |
|---|---|---|
| S-01 | Splash / Bootstrap | تحميل الجلسة وتوجيه المستخدم حسب الدور والحالة |
| S-02 | Login | بريد + كلمة مرور؛ رسالة واضحة عند Tenant suspended |
| S-03 | Student Registration | التسجيل → ينتهي بحالة pending |
| S-04 | Parent Registration | إنشاء حساب بانتظار الربط من المدرس |
| S-05 | Password Reset | عبر Supabase Auth بالكامل |
| S-06 | Email Verification | مستقلة عن موافقة المدرس |
| S-07 | Pending Approval (Student) | شاشة انتظار فقط — لا وصول لأي محتوى |
| S-08 | Account Suspended | رسالة حالة مع إمكانية التواصل |
| S-09 | Notification Permission Prompt (Web) | تُعرض بعد شرح السبب، وليس فور الفتح |
| S-10 | Profile | تعديل محدود للملف الشخصي + Avatar (Storage خاص) |
| S-11 | Notifications Center | قائمة إشعارات المستخدم (Pagination) + وضع كمقروء |
| S-12 | تفاصيل إشعار / Deep Link Target | فتح الهدف مع إعادة تحقق الصلاحية |

## B. شاشات المدرس (Teacher)

| # | الشاشة | الوصف |
|---|---|---|
| T-01 | Teacher Dashboard | مؤشرات منفصلة: حضور، تسليمات، امتحانات، متوسط إكمال فيديو — لا رقم مدمج واحد |
| T-02 | Students List | بحث/فلترة بالحالة/Group + Pagination |
| T-03 | Pending Approvals | مراجعة طلبات التسجيل → Approve/Reject |
| T-04 | Student 360° Profile | Groups + Attendance % + Assignments (مُسلَّم/مُراجَع) + Exams (متوسط) + Video Completion % + Last Activity |
| T-05 | Assign Groups to Student | إسناد/إزالة عضويات (خطوة منفصلة عن الموافقة) |
| T-06 | Groups List | CRUD + عدد الأعضاء |
| T-07 | Group Detail | الأعضاء + المحتوى + سياسة المحتوى السابق (`allow/deny`) + إحصائيات المجموعة |
| T-08 | Group Members Manager | إضافة/إزالة طلاب |
| T-09 | Content Library (per Group) | قائمة مرتبة يدويًا (sort_order) مع حالات draft/published/archived |
| T-10 | Create/Edit Content | حسب النوع (video/pdf/image) |
| T-11 | Video Upload Flow | رفع مباشر لـBunny + متابعة حالة processing → ready |
| T-12 | Create Assignment | تعليمات + due_at + allow_late + max_score |
| T-13 | Submissions Inbox | تسليمات الواجب الواحد (submitted/late) |
| T-14 | Review Submission | عرض الملفات + درجة + Feedback |
| T-15 | Create Exam + Versions | بناء الأسئلة (MCQ/True-False) + خيارات + إعدادات (مدة، shuffle، retake...) |
| T-16 | Exam Version Manager | نشر نسخة (Snapshot) / إنشاء نسخة جديدة / أرشفة |
| T-17 | Exam Results | محاولات الطلاب ونتائجهم (قراءة فقط — النتائج Immutable) |
| T-18 | Attendance Screen | اختيار Group + تاريخ → تحديد حالة كل طالب |
| T-19 | Activity / Reports View | أحداث النشاط ومؤشرات الطلاب (Pagination) |
| T-20 | Link Parent ↔ Student | بحث عن حساب Parent وربطه بطالب |
| T-21 | Send Announcement | عنوان + نص + استهداف (الكل / Group) |
| T-22 | Audit Log View | قراءة محدودة للأفعال الإدارية (الكتابة Backend فقط) |

## C. شاشات الطالب (Student)

| # | الشاشة | الوصف |
|---|---|---|
| ST-01 | Student Home / Dashboard | محتوى Groups المنشور والمصرّح به (مع تطبيق سياسة المحتوى السابق) |
| ST-02 | My Groups | عضويات الطالب (قراءة فقط) |
| ST-03 | Group Content Feed | عناصر المحتوى مرتبة بـsort_order |
| ST-04 | Content Viewer — PDF/Image | عرض عبر Signed URL مؤقت |
| ST-05 | Video Player | Streaming مفوَّض + Resume من آخر نقطة + إرسال Progress دوري |
| ST-06 | Assignment Detail | التعليمات + الموعد + حالة التسليم |
| ST-07 | Submit Assignment | رفع ملفات متعددة + إعادة رفع (attempt جديد) |
| ST-08 | My Submission / Feedback | الدرجة + Feedback بعد المراجعة |
| ST-09 | Exam Intro | القواعد: المدة، Retake، إظهار النتيجة → زر Start |
| ST-10 | Exam Taking | أسئلة بترتيب الـAttempt المثبَّت + مؤقّت عرض + حفظ Draft محلي |
| ST-11 | Exam Result | النتيجة (حسب إعداد show_result) — بدون كشف `is_correct` أثناء الأداء |
| ST-12 | My Grades / Results | نتائجي في الواجبات والامتحانات (الأعلى عند Retake) |
| ST-13 | My Attendance | سجل حضوري (قراءة فقط) |
| ST-14 | My Activity | نشاطي وآخر نشاط معروف |

## D. شاشات ولي الأمر (Parent)

| # | الشاشة | الوصف |
|---|---|---|
| P-01 | Parent Dashboard | ملخص مفهوم لكل طفل مرتبط — لا Raw Data |
| P-02 | Child Selector / Children List | التنقل بين الأبناء المرتبطين |
| P-03 | Child Overview | حضور + واجبات + درجات + نشاط (قراءة فقط) |
| P-04 | Child Assignments | حالة التسليمات والتقييمات |
| P-05 | Child Exam Results | النتائج فقط (وليس إجابات الأسئلة) |
| P-06 | Child Attendance | سجل الحضور |
| P-07 | Child Video/Content Progress | نسب الإكمال للمحتوى المصرّح به |

---

# القسم الثالث: رحلات المستخدم (User Flows)

## رحلة 1 — تسجيل طالب واعتماده ⭐ (حرجة)
```text
Student → S-03 Register → status=pending → S-07 شاشة انتظار
   ↓ (إشعار للمدرس)
Teacher → T-03 Pending Approvals → Approve (Edge Function: approve-student)
   → status=active + Audit Log + إشعار للطالب
Teacher → T-05 إسناد Group(s) — خطوة منفصلة إلزامية
Student → ST-01 يرى محتوى Groups (محتوى ما قبل joined_at حسب سياسة الـGroup)
```
**حالات بديلة:** Reject → الحساب يبقى `rejected` (لا يُحذف، قابل للتحويل active لاحقًا). Email غير موثّق لكن مُعتمد = حالتان مستقلتان.

## رحلة 2 — إنشاء ونشر محتوى (فيديو) ⭐
```text
Teacher → T-09/T-10 إنشاء Content (draft) → T-11 رفع الفيديو مباشرة إلى Bunny
   → videos.status: uploading → processing → (Webhook) → ready
Teacher → Publish (يُمنع قبل ready) → content.status=published + published_at
   → إشعار new_content لطلاب الـGroup
```
**اختبار إلزامي:** طالب انضم بعد النشر + سياسة Group = deny → لا يرى المحتوى (حتى بالـUUID مباشرة).

## رحلة 3 — مشاهدة فيديو (طالب) ⭐
```text
Student → ST-05 فتح فيديو → Backend (video-playback):
   تحقق (عضوية Group + published + سياسة المحتوى السابق) → تفويض تشغيل مؤقت
Player → Resume من آخر progress_seconds → إرسال Progress دوري (throttled UPSERT)
   → completed عند Threshold قرب النهاية → event: video_completed
```

## رحلة 4 — دورة الواجب كاملة ⭐
```text
Teacher → T-12 إنشاء واجب + نشر → إشعار assignment_created
Student → ST-06 فتح الواجب → ST-07 رفع ملفات متعددة → submit
   → (قبل due_at: submitted / بعده + مسموح: late) → event + إشعار للمدرس
Teacher → T-13/T-14 مراجعة → درجة + Feedback → reviewed → إشعار assignment_reviewed
Student → ST-08 يرى النتيجة والـFeedback
```
**بديل:** إعادة الرفع = attempt_number جديد (أو النموذج المبسّط المعتمد أثناء التنفيذ).

## رحلة 5 — دورة الامتحان كاملة ⭐ (الأكثر حساسية)
```text
Teacher → T-15 بناء الأسئلة والخيارات → T-16 نشر Version (Snapshot مجمَّد)
   → إشعار exam_published
Student → ST-09 Intro → Start → Edge Function (start-exam):
   started_at Server-side + تثبيت ترتيب Shuffle + (Partial Unique Index: محاولة واحدة نشطة)
Student → ST-10 أداء الامتحان (Draft محلي + مؤقّت عرض فقط)
Student → Submit → Edge Function (submit-exam) Transaction واحدة Atomic:
   ملكية → توقيت → الـVersion الدقيقة → تحقق إجابات → حساب الدرجة → حفظ → Commit
   → إشعار exam_result (حسب show_result)
```
**حالات حرجة يجب اجتيازها:** انتهاء الوقت → expired مع حفظ آخر إجابات • تسليم مزدوج (Network Retry) → نتيجة واحدة • فتح في تبويبين → Attempt واحدة • انقطاع إنترنت أثناء الأداء → Draft محلي يستعيد • محاولة كشف `is_correct` → تفشل • Retake مسموح → النتيجة المعروضة = الأعلى • تعديل امتحان بعد استخدامه → Version جديدة، نتائج الطلاب القدامى لا تتغير.

## رحلة 6 — تسجيل الحضور
```text
Teacher → T-18 اختيار Group + تاريخ → تحديد present/absent/late/excused لكل طالب
   → UNIQUE(group, student, date) يمنع التكرار → إشعار attendance_marked للطالب وولي الأمر
```

## رحلة 7 — رحلة ولي الأمر كاملة ⭐
```text
Parent → S-04 Register → حساب بدون أبناء
Teacher → T-20 ربط Parent ↔ Student (parent_students)
Parent → P-01 Dashboard → P-02 اختيار طفل → P-03..P-07 (قراءة فقط)
   → يستقبل إشعارات: نتيجة امتحان، حضور، (واجبات اختياري)، إعلانات
```
**اختبار إلزامي:** Parent A يحاول الوصول لطفل غير مرتبط → يفشل Server-side دائمًا.

## رحلة 8 — إعلان من المدرس
```text
Teacher → T-21 عنوان + نص + استهداف (الكل / Group)
   → Notification في DB لكل مستلم → محاولة Push
   → (فشل Push؟ الإشعار يبقى ويظهر عند فتح التطبيق)
```

## رحلة 9 — Tenant معلَّق
```text
tenant.status = suspended → أي مستخدم للـTenant يحاول Login/أي طلب لاحق
   → منع كامل: "This account is currently suspended. Contact support."
   → المحتوى والملفات محفوظة → suspended→active يعيد كل شيء فورًا
```

---

# القسم الرابع: مصفوفة الإشعارات (من يستقبل ماذا)

| الحدث | Teacher | Student | Parent |
|---|:---:|:---:|:---:|
| تسجيل طالب جديد | ✅ | — | — |
| اعتماد الطالب | — | ✅ | — |
| محتوى/واجب جديد | — | ✅ | Optional |
| تسليم واجب | ✅ | — | Optional |
| مراجعة واجب | — | ✅ | Optional |
| نشر/نتيجة امتحان | — | ✅ | ✅ (نتيجة فقط) |
| تسجيل حضور | — | ✅ | ✅ |
| إعلان مهم | ✅ | ✅ | ✅ |

---

# القسم الخامس: قواعد عرض عابرة للشاشات

1. **إخفاء الزر ≠ صلاحية.** كل شاشة تعيد التحقق Server-side (الـDeep Link لا يمنح وصولًا).
2. كل قائمة قد تكبر: Pagination (20–25) + بحث/فلترة على الـDatabase.
3. Loading = Skeletons. Empty/Error states بهوية المنتج.
4. الأرقام (`82%`, `03:42`, `10 Students`) عنصر بصري بارز.
5. عربي/إنجليزي + RTL/LTR في كل شاشة من اليوم الأول — لا نصوص hard-coded.
6. Optimistic UI مسموح فقط لـ"وضع إشعار كمقروء"؛ ممنوع في تسليم امتحان/تقييم واجب/اعتماد طالب/حضور/نشر امتحان.
7. Realtime انتقائي (إشعارات وتحديثات حالة مهمة) — ليس على كل جدول.

---

# القسم السادس: ما لا يُبنى في V1 (حدود الشاشات)

❌ Chat/Messaging • ❌ SMS • ❌ Email Marketing • ❌ Notification Preferences متقدمة / Quiet Hours • ❌ Notification Analytics • ❌ AI notifications • ❌ AI Risk Score • ❌ Video Heatmap • ❌ Excel/PDF Export • ❌ Dark Mode • ❌ جدولة حصص • ❌ Essay/Matching questions • ❌ تحميل الفيديو • ❌ Custom Domain لكل Tenant
