# خارطة الطريق والمهام — V1 (المعتمد)
> الإصدار 1.0 · 2026-09-06 · المرجع: الوثيقة القسم 14.3 + خريطة مراحل Build_Plan (مدمجة هنا).
> **القاعدة:** كل مهمة تُسلَّم عبر قالب `09_DEFINITION_OF_DONE.md` ومعها DoD. لا تنتقل للمهمة التالية قبل اجتياز DoD.

---

## القسم أول: المهام الـ16 بالترتيب الإلزامي

| # | المهمة | المخرجات الرئيسية | معايير القبول الحرجة |
|---|---|---|---|
| 1 | **Bootstrap** | `flutter create` + pubspec (الـPackages المعتمدة) + `analysis_options.yaml` (strict) + هيكل `lib/core` + `lib/features` + ARB (ar/en) + .gitignore | `flutter analyze` نظيف؛ l10n يعمل RTL |
| 2 | **Theme** | `lib/core/theme`: ColorScheme (Deep Indigo seed) + AppSpacing (4..64) + TextTheme + `AppButton/AppTextField/AppCard/AppLoading/AppErrorView/AppEmptyView` | لا `Color(0xFF…)` داخل Widget؛ تباين ≥ 4.5:1 |
| 3 | **Supabase Foundation** | تطبيق `supabase/migrations/0001_init.sql` على Dev + Seed Dev فقط + تشغيل اختبارات RLS الأساسية | RLS مفعّل على كل جدول؛ سيناريوهات 12.5 تُنفَّذ |
| 4 | **Auth** | تسجيل دخول (Teacher/Student/Parent) + pending view للطالب + email verification + password reset عبر Supabase Auth | لا حذف حساب في V1؛ role يُحدَّد Server-side |
| 5 | **Routing** | `go_router` + Shell منفصل لكل دور + حماية routes حسب الدور + deep links آمنة (تُعامل كـUntrusted) | لا Dashboard واحد بشرط `if role ==` |
| 6 | **Onboarding (Platform)** | إنشاء Tenant + حساب Teacher الأول — "المنصة تنشئ، لا تسجيل ذاتي" | تدفق كامل Dev |
| 7 | **Students** | قائمة (Pagination 20–25) + بحث/فلترة + approve/reject/suspend عبر `approve-student` + Student 360° | الطالب لا يفعّل نفسه؛ rejected يُحتفظ به |
| 8 | **Groups** | CRUD + `group_members` (الطالب لا يضيف نفسه) + `previous_content_access` (allow/deny) | `UNIQUE(group_id, student_id)`؛ سياسة joined_at تعمل |
| 9 | **Content** | CRUD (video/pdf/image/assignment/exam) + Draft→Published→Archived + `sort_order` + رفع ملفات (Private Buckets + Signed URLs + تحقق MIME/حجم) | لا نشر Draft؛ لا Public Bucket |
| 10 | **Assignments** | إنشاء → تسليم (عدة ملفات) → مراجعة/تقييم → إشعار + re-submit (attempt_number) | Idempotency؛ لا Optimistic للتقييم |
| 11 | **Exams** | Builder (MCQ/True-False) + **Versioning (Published = Snapshot)** + `start-exam` + `submit-exam` Atomic + Retake (أعلى درجة) + Shuffle مثبَّت + انتهاء الوقت Server-side | `is_correct` لا يصل للطالب؛ لا Race Condition (Partial Unique Index)؛ الدرجة Server-side |
| 12 | **Attendance** | تسجيل يومي `UNIQUE(group_id, student_id, date)` + عرض للمدرس/الطالب/الوالد | لا session_id في V1 |
| 13 | **Videos** | تكامل Bunny: رفع مباشر من Flutter→Bunny (بعد تفويض) + `bunny-webhook` (status) + `video-playback` (تفويض مؤقت) + `video_progress` (UPSERT + Resume + تعريف Completion) | لا رابط دائم؛ لا Publish قبل ready؛ لا تزوير Progress سهل |
| 14 | **Notifications** | In-App أولًا دائمًا + `notifications`/`notification_recipients` + FCM (Web/Android/iOS) + Announcement + Payload غير حساس | فشل Push لا يحذف الإشعار؛ Whitelist فقط |
| 15 | **Parent** | Dashboard قراءة فقط (أبناؤه المرتبطون فقط) + نتائج الامتحانات | عزل غير المرتبطين (اختبار 12.5) |
| 16 | **QA/Production** | اختبارات الهجوم 12.5 كاملة + Smoke للرحلات الحرجة (21.3) + `EXPLAIN ANALYZE` (5.5) + Pre-ship Checklist (17.5) + Build مهوّب (`--obfuscate --split-debug-info`) | لا Production Release قبل اجتياز القائمة |

---

## القسم ثاني: خريطة المراحل (مرجع فلسفي — الجدول أعلاه هو الملزم)

```text
مرحلة 0: الأساس التقني        ← المهام 1-3 (و5 جزئيًا)
مرحلة 1: المصادقة والدورة     ← المهمة 4
مرحلة 2: الطلاب والمجموعات    ← المهام 6-8
مرحلة 3: المحتوى والفيديو والنشاط ← المهام 9 و13 (النشاط F9 يبنى معها)
مرحلة 4: الواجبات والامتحانات  ← المهام 10-11 (الأكثر حساسية)
مرحلة 5: الحضور               ← المهمة 12
مرحلة 6: الإشعارات            ← المهمة 14 (تُوصَّل بكل ما سبق)
مرحلة 7: التحليلات وأولياء الأمور ← المهمة 15 (التحليلات F11 ضمن T-01/T-04/P-01)
مرحلة 8: التصليب والإطلاق      ← المهمة 16
```

**قاعدة الربط:** كل ميزة جديدة تُنهى بتاسك «الربط» يصلها بالميزات السابقة (تنقل، إشعار، تحليلات، ظهور لولي الأمر). عند أي اختلاف ترتيب بين خريطة المراحل والجدول: **الجدول هو الملزم**.

---

## القسم ثالث: واجبات موازية (تبدأ مبكرًا ولا تتوقف)
- **Docs:** إبقاء `05_API_CONTRACT.md` متزامنًا مع أي تغيير في عقود الدوال.
- **Memory:** تحديث `10_DECISIONS.md` عند أي قرار تنفيذي جديد غير مغطى بالوثيقة.
- **Performance:** Pagination في أي قائمة منذ اليوم الأول.

## القسم رابع: خارج النطاق — ممنوع البدء به (البند 24)
Subscription/Billing (v1.16) · Subscription Enforcement (v1.22) · Data Deletion Flow · Chat · Dark Mode · Excel/PDF Export · AI Risk Score · Custom Domain لكل Tenant · Staging Environment.
