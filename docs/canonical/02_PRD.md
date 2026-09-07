---
> **Canonical v1.0 · 2026-09-06 · المعتمد الوحيد** — هذه النسخة تحل محل أي ملف قديم بنفس الاسم أو الغرض.
---

# وثيقة متطلبات المنتج (PRD)
# منصة SaaS التعليمية White-Label للمدرسين

| | |
|---|---|
| **الإصدار** | 1.0 |
| **التاريخ** | 6 سبتمبر 2026 |
| **الحالة** | مسودة اعتماد — مستمدة بالكامل من الوثيقة المرجعية الموحّدة (v0.1 → v1.21) |
| **المرجع** | Education_SaaS_Master_Architecture.md |

---

## 1. ملخص تنفيذي

**المنتج:** منصة تعليمية SaaS بنموذج White-Label موجّهة للمدرسين المستقلين (وليست موقعًا لمدرس واحد). كل مدرس = Tenant معزول تمامًا. العميل الحالي (مدرس نظام أمريكي، ~10 طلاب) هو أول Tenant.

**الوعد الأساسي:** منصة تعليمية كاملة (محتوى + فيديو + واجبات + امتحانات + حضور + متابعة أولياء الأمور) بعزل بيانات مطلق بين المدرسين، وأمان حقيقي مفروض على مستوى قاعدة البيانات وليس الواجهة، دون Enterprise-complexity غير ضرورية.

**نطاق V1:** نظام أمريكي (American System)، طلاب منظّمون في Groups (Basics, Advanced, SAT, EST, ACT...)، والطالب قد ينتمي لأكثر من Group. الـGroup هي وحدة توزيع المحتوى.

---

## 2. المشكلة والفرصة

- المدرسون المستقلون يديرون عملهم التعليمي بأدوات متفرقة (WhatsApp، Google Drive، Excel، امتحانات ورقية) — بلا أمان، بلا حماية للفيديو، بلا متابعة حقيقية لأولياء الأمور.
- المنتجات الحالية إما LMS معقد Enterprise، أو موقع "مدرس واحد" لا يتوسّع.
- الفرصة: منصة بسيطة بما يكفي للمدرس الفردي، ومعزولة بما يكفي لبيعها لمدرسين كثر لاحقًا دون إعادة هندسة.

---

## 3. الأهداف ومؤشرات النجاح

| الهدف | كيف نقيسه |
|---|---|
| تشغيل منصة حقيقية للعميل الحالي | اجتياز كل الرحلات الحرجة (قسم 11) E2E قبل الإطلاق |
| عزل مطلق بين Tenants | اجتياز كل سيناريوهات الهجوم في قسم 12.5 من الوثيقة المرجعية كاختبارات فعلية |
| حماية الفيديو والمحتوى | لا رابط دائم/عام لأي فيديو؛ Playback مفوَّض مؤقت فقط |
| سلامة النتائج الأكاديمية | النتائج تُحسب Server-side فقط، والإصدارات المنشورة من الامتحانات Immutable |
| تجربة بسيطة | لا شاشة تحتاج Enterprise-training؛ كل دور له Navigation خاص به |

### Explicitly Non-Goals في V1
- ❌ Chat/Messaging بين المستخدمين
- ❌ SMS، Email Marketing
- ❌ AI Risk Score / Predictions
- ❌ Excel/PDF Export (مؤجَّل V1.1/V2)
- ❌ Offline-First كامل / Drift Local DB
- ❌ Dark Mode (Tokens جاهزة لاحقًا)
- ❌ Custom Domain لكل Tenant
- ❌ Essay/Matching/Drag&Drop question types
- ❌ جدولة حصص كاملة (Session Scheduling)
- ❌ لا وعود تسويقية بـ"Anti-Cheat 100%" أو "منع تصوير الشاشة" أو "Unlimited Everything"

---

## 4. الشخصيات (Personas)

### 4.1 Teacher (مالك الـTenant)
- إدارة كاملة: طلاب، Groups، محتوى، واجبات، امتحانات، حضور، نشاط، إشعارات، ربط أولياء الأمور.
- يريد: رؤية 360° لكل طالب من شاشة واحدة بدل 5 شاشات.

### 4.2 Student
- يسجّل → ينتظر الموافقة → يصل لمحتوى Groups الخاصة به → يحل واجبات وامتحانات → يرى نتائجه ونشاطه فقط.
- غالبيتهم قُصَّر (<18) — اعتبار خصوصية أساسي (راجع قسم 10).

### 4.3 Parent
- متابعة Read-only للأبناء المرتبطين به فقط: واجبات، درجات، حضور، نشاط.
- **لا يربط نفسه بطالب** — الربط يتم عبر المدرس/المنصة فقط.
- يرى ملخصًا مفهومًا، لا Raw Database ولا تفاصيل تقنية.

### خارج V1 عمدًا
Admin، Assistant Teacher، Moderator، Staff — لا تُضاف إلا بحاجة حقيقية مثبتة.

---

## 5. المبادئ الحاكمة (غير قابلة للتفاوض)

1. **العميل (Flutter) غير موثوق.** الحقيقة تُشتق دائمًا من `auth.uid() → users → tenant/role/status`.
2. **RLS هو خط الدفاع الحقيقي**، وليس إخفاء الأزرار.
3. **عزل Tenants مطلق** — لا استثناء حتى "مؤقتًا".
4. **البيانات الأكاديمية التاريخية Immutable** — النتائج القديمة لا تتغير بأثر رجعي.
5. **العمليات الحساسة Atomic عبر Backend/RPC/Edge Functions** — لا حسابات درجات من العميل.
6. **لا تعقيد بلا حاجة حالية** — كل جدول/Package/Abstraction له سبب حقيقي.
7. **لا وعود لا نفيها** — لا "Anti-Cheat 100%"، لا "منع تصوير الشاشة"، لا "Unlimited".

---

## 6. نطاق المنتج الوظيفي (V1)

> التفصيل الكامل لكل Feature والشاشات والرحلات في الملف المرافق: **Features_Screens_UserFlows.md**

| # | المجال | الوظائف الأساسية |
|---|---|---|
| F1 | Auth & دورة الحساب | تسجيل طالب (pending) / ولي أمر، Login، Email Verification، Password Reset (Supabase Auth فقط) |
| F2 | إدارة الطلاب | مراجعة واعتماد/رفض، تعليق (Suspend)، إسناد Groups |
| F3 | Groups | CRUD، أعضاء (Many-to-Many)، سياسة المحتوى السابق على مستوى الـGroup |
| F4 | المحتوى | فيديو / PDF / صورة / واجب / امتحان؛ Draft → Published → Archived؛ ترتيب يدوي (sort_order) |
| F5 | الفيديو | رفع مباشر لـBunny، Encoding، Streaming مفوَّض مؤقت، Resume، تتبع Progress — لا Download |
| F6 | الواجبات | إنشاء، موعد تسليم، تسليم متعدد الملفات، إعادة رفع، تقييم + Feedback |
| F7 | الامتحانات | MCQ/True-False، Versioning (Snapshot منشور)، توقيت Server-side، تسليم Atomic، Shuffle، Retake (أعلى درجة) |
| F8 | الحضور | تسجيل يومي بسيط (present/absent/late/excused) لكل Group |
| F9 | تتبع النشاط | Whitelist من 7 أحداث معنوية فقط + last_activity_at |
| F10 | الإشعارات | In-App أولًا + Push (FCM/Web) كتوصيل؛ 8 أنواع Whitelisted؛ إعلانات المدرس |
| F11 | التحليلات | Teacher Dashboard، Student 360°، Parent Dashboard — مؤشرات منفصلة لا رقم سحري واحد |
| F12 | ربط أولياء الأمور | Teacher يربط Parent ↔ Student يدويًا |

---

## 7. متطلبات غير وظيفية

### 7.1 الأمان
- طبقات: TLS → JWT → Tenant Isolation → RLS → Backend Validation → Business Rules.
- `is_correct` لا يصل للطالب أبدًا. الدرجة تُحسب Server-side. التوقيت Server-side.
- Idempotency إلزامية للعمليات الحساسة (تسليم امتحان، اعتماد طالب، إرسال إشعار).
- Secrets (Service Role, Bunny, FCM) في Edge Function Secrets فقط — أبدًا في Flutter/Git.
- Storage Buckets خاصة دائمًا؛ Signed URLs مؤقتة؛ UUID-based paths.
- سيناريوهات الهجوم (قسم 12.5 مرجعية) تُكتب كاختبارات فعلية قبل الإطلاق + `EXPLAIN ANALYZE` لأداء RLS.

### 7.2 الأداء
- Pagination دائمًا (20–25 عنصرًا). Search/Filter/Sort على الـDatabase.
- Video Progress throttled. Realtime انتقائي فقط. Skeletons للتحميل.
- Optimistic UI ممنوع في: تسليم امتحان، تقييم واجب، اعتماد طالب، حضور، نشر امتحان.

### 7.3 التوافر والتشغيل
- Online-First + Offline-Tolerant (لا Offline-First). Exam Draft محلي أثناء الأداء فقط.
- بيئتان منفصلتان: Development / Production.
- CI/CD Gate: analyze + test + build — لا يصل Production كود فاشل.
- Backups مُدارة + أولويات استعادة P0→P3.

### 7.4 التقنية
- Frontend: Flutter Web + Mobile — Cubit (flutter_bloc)، go_router، supabase_flutter.
- Backend: Supabase (Auth + PostgreSQL/RLS + Storage + Realtime + Edge Functions).
- فيديو: Bunny Stream (شبه نهائي — يحتاج اختبار عملي قبل القفل 100%).
- Push: FCM (Delivery فقط). استضافة الويب: Cloudflare Pages.
- عربي/إنجليزي، RTL/LTR كاملان من اليوم الأول (ARB files).

---

## 8. دورات حياة الحالات (State Machines)

**Student:** `Register → Pending ⇄ (Rejected | Active) ⇄ Suspended` — لا حذف نهائي في V1.
**Teacher/Tenant:** يُنشأ عبر Onboarding من طرف المنصة (لا Self-signup). `active ⇄ suspended` (الإيقاف = منع كامل، المحتوى لا يُحذف).
**Content:** `Draft → Published → Archived`.
**Exam:** `Draft → Published → Active → Closed → Archived` — النسخة المنشورة Snapshot غير قابل للتعديل.
**Video:** `uploading → processing → ready | failed | deleted` — لا Publish قبل `ready`.

---

## 9. النموذج الاقتصادي

- هيكل التكلفة: Infrastructure + Storage + Video Delivery (المتغير الأكبر) + Push (مجاني) + Support.
- **لا "Unlimited Everything".** Fair Usage Policy + تسعير مستقبلي بـStudent Capacity (Starter/Growth/Pro).
- مراقبة استهلاك فعلي (`students_count`, `storage_used`, `video_bandwidth_used`) من اليوم الأول.
- اتفاق العميل الحالي لا يتغيّر؛ النموذج الجديد للعملاء القادمين.
- ⚠️ ركن v1.16 (Subscription & Billing) **فجوة موثّقة** — يجب استرجاعه/إعادة كتابته قبل أي منطق فوترة.

---

## 10. الخصوصية (قُصَّر)

- حد أدنى من البيانات. لا بيع/مشاركة مع أطراف ثالثة (Bunny/FCM = Delivery-only).
- لا درجات دقيقة في Push/Lock Screen.
- حسابات rejected تحتاج مدة احتفاظ محددة لاحقًا (بند مفتوح).
- Data Deletion Request Flow غير موجود — بند مفتوح يجب حسمه قبل نمو العملاء.
- **مراجعة قانونية مطلوبة قبل الإطلاق التجاري** (موافقة ولي الأمر، مدة الاحتفاظ، آلية الحذف).

---

## 11. معايير الإطلاق (Definition of Done)

1. كل Feature: UI + Responsive + Loading/Empty/Error + Validation + Cubit/Repository + RLS محقَّقة + اختبارات + critical flow.
2. الرحلات الحرجة E2E: تسجيل/اعتماد طالب، محتوى + سياسة المحتوى السابق، دورة واجب كاملة، دورة امتحان كاملة (وقت، تسليم مزدوج، انقطاع إنترنت، محاولة كشف الإجابة)، رحلة Parent مع عزل غير المرتبطين، فيديو (رفع/معالجة/تشغيل/استئناف).
3. اختبارات أمن RLS (سيناريوهات الهجوم) كلها خضراء.
4. اختبار أداء RLS (`EXPLAIN ANALYZE`) على الاستعلامات الرئيسية.
5. Smoke Test كامل بعد نشر كل إصدار Production.

---

## 12. المخاطر المفتوحة

| الخطر | الإجراء |
|---|---|
| محتوى v1.16 (Billing) مفقود | استرجاعه/إعادة كتابته قبل أي فوترة |
| v1.22 (Subscription Enforcement) لم يُكتب | إنجازه قبل اعتبار دورة حياة الـTenant التجارية مكتملة |
| خصوصية القُصَّر بلا مراجعة قانونية | جلسة قانونية قبل التوسع |
| Bunny غير مؤكد 100% | اختبار عملي فعلي قبل القفل |
| أداء RLS غير مُختبَر | EXPLAIN ANALYZE إلزامي قبل الإطلاق |

---

## 13. خارطة الطريق (مؤجَّلات معتمدة)

V1.1/V2: Excel/PDF Export، Notification Preferences متقدمة، Quiet Hours، Needs-Attention indicator (Rules-based بسيط)، Dark Mode، Staging Environment، Custom Domain لكل Tenant، تأكيد Bunny النهائي، Data Deletion Flow.
