---
> **Canonical v1.0 · 2026-09-06 · قواعد الوكيل الموحدة**
> = AGENTS.md (النسخة النهائية) + rules/01-architecture + 03-security + 04-ui-design + 05-workflow.
> قاعدة 02-data-model مستبدلة بـ 04_DATA_MODEL.md (منع التكرار).
> عند التعارض: 03_ARCHITECTURE_MASTER > هذا الملف > 10_DECISIONS.md.
---

# AGENTS.md — عقد تنفيذ منصة SaaS التعليمية
> لأي AI Coding Agent (Antigravity IDE / Claude Code / Cursor / Codex …)

## ترتيب القراءة الإلزامي
1. `Education_SaaS_Master_Architecture.md` — **الوثيقة المرجعية الموحدة** (المصدر الأعلى، 25 قسمًا). أي تنفيذ يبدأ بقراءة القسم ذي الصلة منها.
2. `rules/01..05` — القواعد المحسومة (ملخص الوثيقة للتنفيذ السريع).
3. `memory/*.md` — سجل القرارات والمنعيات.

**المرجعية عند التعارض:** الوثيقة المرجعية > `rules/*` > `memory/constraints.md`. لا يُعدَّل بند مقفول 🔒 إلا بقرار "مراجعة" صريح موثّق.

---

## المشروع بجملة واحدة
White-label **Education SaaS** للمدرسين (Multi-Tenant من اليوم الأول). V1: نظام أمريكي، ~10 طلاب، منظَّمون في **Groups** (Basics / Advanced / SAT / EST / ACT)، وقد ينتمي الطالب لأكثر من Group.

## Stack — محسوم نهائيًا (لا ارتجال، أي سؤال خارج هذا = اسأل)
| الطبقة | الاختيار |
|---|---|
| Frontend | **Flutter** (stable) — Web + Android/iOS |
| State Management | **flutter_bloc — Cubit فقط** (لا Riverpod، Bloc/Events فقط لـState Machine معقدة نادرة) |
| Routing | **go_router** |
| Backend | **Supabase**: Auth + PostgreSQL + RLS + Storage + Edge Functions |
| فيديو | **Bunny Stream** (قاعدة البيانات تحفظ Metadata فقط، لا Binary) |
| Push | **FCM** — بنية توصيل فقط |
| Web Host | **Cloudflare Pages** |
| Models | `json_serializable` + `build_runner` + `equatable` |
| Localization | `flutter_localizations` + ARB (`app_ar.arb`, `app_en.arb`) — RTL/LTR من اليوم الأول |
| لا في V1 | VPS، Docker، Redis، Node Server خاص، Microservices، Drift/Offline DB |

**Secrets:** لا Service Role Key ولا أي Secret داخل Flutter/Git أبدًا — فقط داخل Edge Function Secrets. في التطبيق: Supabase URL + Anon Key فقط.

## قواعد غير قابلة للتفاوض (من الوثيقة قسم 0)
1. **Flutter عميل غير موثوق.** أي `tenant_id`/`role`/`status`/`score`/`is_correct` من العميل = صفر ثقة. الحقيقة تُشتق من `auth.uid()` → `public.users` → tenant/role/status.
2. **RLS هي خط الدفاع الحقيقي**، وليس إخفاء الأزرار. صلاحية غير مفروضة على قاعدة البيانات = غير موجودة أمنيًا.
3. **العزل بين الـTenants مطلق** — لا استثناء "مؤقتًا".
4. **البيانات الأكاديمية التاريخية Immutable** — نتائج/درجات قديمة لا تتغير بأثر رجعي (Exam Versioning = Snapshot).
5. **العمليات الحساسة عبر Edge Function/RPC Atomic** — لا حساب درجات/موافقات/صلاحيات من Flutter.
6. **لا تعقيد بلا حاجة حقيقية** — كل جدول/باكدج/طبقة يجب أن يكون له سبب.
7. **الذكاء الاصطناعي منفّذ، وليس مهندسًا معماريًا** (القسم 23).
8. **لا وعود لا نقدر نفيها** — لا "Anti-Cheat 100%"، لا "منع تصوير الشاشة"، لا "Unlimited".
9. **التعريب الفوري المتزامن (Zero Localization Debt):** ممنوع منعاً باتاً كتابة أي نص ثابت (Hardcoded String) في أي Widget أو Dialog أو رسالة. عند إضافة أو تعديل أي شاشة، يجب فوراً وفي نفس اللحظة إضافة المفتاح في `app_en.arb` وترجمته العربية المطابقة في `app_ar.arb` وتشغيل `flutter gen-l10n`. نسبة التطابق دائماً 100% وممنوع تأجيل الترجمة نهائياً.

## ممنوعات أمنية (الأخطر — القسم 23.3)
- تعطيل RLS أو `using (true)` على بيانات المستخدمين.
- استخدام Service Role Key داخل Flutter / Hard-code أي Secret / تخزينه في `shared_preferences`.
- تجاوز Authorization أو تخفيفها "لأنها بتعمل Error" — الحل دائمًا إصلاح التنفيذ، لا إلغاء البنية الأمنية.
- إرسال `question_options.is_correct` للطالب في أي Response.
- جعل Storage Bucket عامًا لتسهيل الرفع.
- حساب الدرجات Client-side أو قبولها من العميل.

## الحلقة الإلزامية قبل قول "تم" (القسم 21 + 04-workflow)
```text
اقرأ الملف أولًا → خطة قصيرة (≤7 أسطر) لو المهمة تلمس >3 ملفات → أصغر تغيير →
تعريب متزامن فوري (app_en.arb + app_ar.arb) → flutter gen-l10n (تطابق 100% وصفر مفاتيح ناقصة) →
dart run build_runner build --delete-conflicting-outputs (عند أي codegen) →
flutter analyze → flutter test → flutter build (web/apk حقيقي، ليس analyze فقط) →
شغّل الشاشة/الفلو فعليًا وتحقق من الـdebug console → حدّث memory/
```
- أي خطأ في الـanalyzer/test أو وجود مفاتيح غير مترجمة = **فشل**. لا "تم" قبل رؤية الإشارة.
- الحالات الثلاث إلزامية في كل شاشة تجلب بيانات: **loading / empty / error**.
- `context.mounted` بعد أي await، و`mounted` قبل setState، وDispose لكل Controller/Subscription.

## طريقة إعطاء المهام (نموذج إلزامي — القسم 23.4)
```text
Context: [القسم/الرابط من الوثيقة المرجعية]
Feature: <اسم الميزة بجملة>
Constraints: استخدم Cubit + Repository. لا تعدّل Schema/RLS/Routing/State-Management.
Required: حالات loading/error/empty + اختبارات للمنطق الحرج.
Acceptance Criteria: <معايير محددة قابلة للتحقق>
```
كل Metric تحليلي جديد يتطلب توثيقًا صريحًا: `Name / Definition / Source / Calculation / UI Location` قبل التنفيذ.

## حدود العمل
نفّذ المطلوب فقط، بالحجم المطلوب. لا Refactors جانبية، لا Renames، لا ميزات إضافية. لو الطلب يبدو مخالفًا للوثيقة: اعترض بسطر واحد ثم نفّذ ما طُلب.

## ملفات التنفيذ الهامة
| الملف | الغرض |
|---|---|
| `supabase/migrations/0001_init.sql` | الـSchema الكامل (24 جدولًا + Indexes + RLS helper) |
| `docs/api-contract.md` | عقود الـEdge Functions + فئات الأخطاء |
| `docs/cost-model.md` | نموذج التكلفة الشهرية (تشغيل خارج التطوير) |
| `TASKS.md` | قائمة مهام V1 مرتبة حسب ترتيب البناء المعتمد |
| `.env.example` | المتغيرات المطلوبة (Flutter + Edge Functions) |


---

# 01 — القرارات المعمارية المحسومة (من الوثيقة المرجعية: أقسام 0، 1، 2، 3، 14، 16، 17، 18)

> أي قرار معماري غير مذكور هنا أو في الوثيقة = **اسأل، لا تخترع**. أي قرار مذكور = نفّذ بلا نقاش.

## المنتج ونطاق V1 (القسم 1)
- White-label Education SaaS — العميل الحالي أول Tenant. نظام **أمريكي**، ~10 طلاب حاليًا.
- الطلاب في **Groups** (قد ينتمي الطالب لأكثر من Group). الـGroup = وحدة توزيع المحتوى.
- الأدوار الثلاثة فقط في V1: **Teacher / Student / Parent** — لا Admin/Assistant/Staff.

## تعدد المستأجرين (القسم 2)
- Multi-Tenant معماريًا من اليوم الأول، والعزل في Database/RLS وليس Flutter.
- اشتقاق الـTenant الحقيقي دائمًا: `auth.uid() → public.users.id → public.users.tenant_id`.

## دورة حياة الحسابات (القسم 3)
- **Teacher:** لا تسجيل ذاتي — يُنشأ عبر Onboarding من المنصة.
- **Student:** `Register → pending → Teacher Review → active/rejected` — الموافقة لا تضيف Group تلقائيًا (خطوة منفصلة). `rejected` لا يُحذف. `suspended` يمنع الوصول مع بقاء حساب Auth.
- **Parent:** لا يربط نفسه — الربط عبر `parent_students` من المدرس فقط. قد يرتبط بأكثر من طفل.
- لا حذف نهائي لحسابات V1 — فقط Suspend/Deactivate.
- **Tenant معلق (3.6):** منع تسجيل دخول كامل + إبطال Sessions عند أول طلب + منع قراءة/كتابة كامل + لا حذف للبيانات + إعادة التفعيل تعيد كل شيء فورًا.

## معمارية الـFrontend (القسم 14)
- **Cubit** (flutter_bloc) — لا Riverpod. معمارية لا تُربَط بالأداة:
  `UI → Cubit → (UseCase اختياري) → Repository (Interface) → DataSource → Supabase`
- **ممنوع:** استدعاء Supabase داخل Widget أو داخل `build()`، Cubit ضخم واحد لكل التطبيق، Cubit يستدعي Cubit آخر (التواصل عبر Backend/Realtime/Notification).
- الهيكل: `lib/core/{config,constants,errors,extensions,localization,router,theme,utils,widgets}` + `lib/features/<name>/{data,domain,presentation}`.
- UseCase يُستخدم فقط للأعمال الثقيلة (مثال: `SubmitExamUseCase`) — لا نفرضه للشكل.
- Naming: `snake_case` ملفات، `PascalCase` كلاسات، ممنوع `Helper/Manager/Utils` بلا مسؤولية.
- **ترتيب بناء الميزات:** Bootstrap → Theme → Supabase → Auth → Routing → Onboarding → Students → Groups → Content → Assignments → Exams → Attendance → Videos → Notifications → Parent → QA/Production.

## الأداء والعمل دون إنترنت (القسم 16)
- **Online-First + Offline-Tolerant** — لا Drift في V1. Supabase = مصدر الحقيقة دائمًا.
- Cache 3 فئات: قصيرة العمر (شبكة مباشرة) / مناسبة للـCache (Memory + Background Refresh) / الفيديو (لا Cache — Streaming عبر Bunny).
- **Pagination دائمًا** (20-25 عنصر). Search/Filter/Sort على مستوى Database.
- Video Progress مُرسَل دوريًا (وليس كل ثانية). Exam Draft محلي فقط أثناء الأداء، والتسليم النهائي Server-validated.
- Optimistic UI فقط للعمليات الآمنة تمامًا (مثل mark-as-read) — ممنوع في: تسليم امتحان/تقييم/اعتماد/حضور/نشر.
- Retry محدود (2-3 محاولات) للشبكة فقط. Realtime انتقائي فقط.

## البنية التحتية والنشر (القسم 17)
```text
Internet → Cloudflare (DNS/SSL/CDN) → Flutter Web (Cloudflare Pages)
                                    ↘ Supabase (Auth/Postgres+RLS/Storage/Edge Functions)
                                         ↘ Bunny Stream (فيديو) + FCM (Push)
```
- بيئتان: **Development وProduction** منفصلتان تمامًا (مشاريع Supabase مختلفة). Staging لاحقًا.
- CI/CD: PR → analyze → test → build → Merge → main → Deploy. فشل Build = Production يبقى على آخر نسخة ناجحة.
- لا Migrations يدوية على Production — فقط `supabase/migrations/`. التغييرات الهدّامة على مراحل.
- Rollback فوري للكود؛ DB عبر Migrations تدريجية + Supabase Managed Backups.

## تهيئة المشروع والـPackages (القسم 18)
`flutter_bloc` • `supabase_flutter` • `go_router` • `json_serializable`+`build_runner` • `equatable` • `file_picker` • `cached_network_image` • `AppVideoPlayer` abstraction فوق `video_player` • `intl` • `flutter_localizations`+ARB
- Git: `main` / `develop` / `feature/*`؛ Commit convention (`feat:` `fix:` `refactor:` `test:` `chore:`) — لا عمل مباشر على main.

## البنود المفتوحة (لا تنفَّذ الآن — القسم 24)
v1.16 Subscription & Billing (فجوة توثيقية — يحتاج إعادة كتابة) • v1.22 Subscription Enforcement • Data Deletion Flow • مراجعة قانونية للخصوصية (قُصَّر) • Notification Preferences متقدمة • Quiet Hours • Excel/PDF Export • AI Risk Score • Custom Domain لكل Tenant • Staging • Chat • Dark Mode.


---

# 03 — الأمان والصلاحيات (المرجع: الوثيقة أقسام 5، 11، 12)

## المبدأ
> Flutter يحدد ما **يظهر**، RLS + Backend يحددان ما **يُسمح فعليًا**.
> كل Policy تستخرج الهوية من `auth.uid()` ثم Tenant/Role/Status من `public.users` — لا ثقة بأي قيمة من العميل.

## مصفوفة الصلاحيات (5.2) — ملخص
| المورد | Teacher | Student | Parent |
|---|:---:|:---:|:---:|
| ملفه | RW | RW محدود | RW محدود |
| Students | CRUD (Tenant) | بياناته فقط | الأبناء المرتبطون فقط |
| Groups | CRUD | عضوياته فقط (قراءة) | عضويات الأبناء |
| Group Members | CRUD | لا يضيف نفسه | قراءة |
| Content | CRUD | منشور + مصرح فقط | المصرح للأبناء |
| Files/Videos | CRUD | المصرح به | المصرح للأبناء |
| Assignments | CRUD | قراءة + تسليم | قراءة |
| Submissions | قراءة/تقييم | ملكه فقط | ملك الأبناء |
| Exams | CRUD (قيود بعد النشر) | أداء/نتيجته | نتيجة الأبناء |
| Questions/Options | CRUD | حقول آمنة (بدون is_correct) | حقول آمنة |
| Attempts/Answers | قراءة | ملكه فقط | ملك الأبناء |
| Attendance | CRUD | قراءة | قراءة الأبناء |
| Activity | قراءة (Tenant) | ملكه فقط | ملك الأبناء |
| Notifications | إنشاء/قراءة | ملكه فقط | ملكه فقط |
| Audit Logs | قراءة محدودة (كتابة Backend فقط) | ❌ | ❌ |

## قواعد أساسية
- **previous_content_access:** المقارنة مع `group_members.joined_at` وليس تاريخ إنشاء الحساب.
- **Draft Content:** لا يصل لأي طالب مهما عرف الـID — شرط `status = published` إلزامي في كل Policy/Query.
- **Video:** لا رابط دائم — Playback عبر تفويض مؤقت (`video-playback` Edge Function).
- **Exam Submission:** الطالب يرسل `selected_option_id` فقط — أبدًا score/is_correct/percentage.
- **DELETE** حقيقي مسموح فقط للبيانات المؤقتة/غير الحساسة.

## حماية IDOR (5.4)
كل وصول بمُعرّف يمر بالسلسلة: `User → Tenant → Group Membership → Resource Authorization`.
امتلاك UUID صالح ≠ صلاحية وصول.

## متى Supabase مباشرة (CRUD + RLS) — 11.2
عمليات بسيطة غير حساسة: قراءة محتوى مصرح، Groups/Students/Notifications، تحديث الملف الشخصي، قراءة Attendance/Video Progress.

## متى Edge Function / RPC إلزامي — 11.3
حساسة/متعددة الخطوات/تحتاج Secret/خدمة خارجية/لا نثق بمدخلات العميل:
```text
approve-student · start-exam · submit-exam · video-playback ·
bunny-webhook · send-notification · record-activity
```
- **approve-student:** JWT → Teacher الحقيقي + Tenant → الطالب pending وبنفس الـTenant → تحديث الحالة → Audit → Notification. الطالب لا يفعّل نفسه أبدًا.
- **submit-exam:** Transaction واحدة كما في rules/02 (Atomic + Idempotent).
- **video-playback:** عضوية Group + نشر + previous-content policy → تفويض Bunny مؤقت.

## Secrets — لا استثناء (11.5)
`SUPABASE_SERVICE_ROLE_KEY · BUNNY_API_KEY · BUNNY_WEBHOOK_SECRET · FCM_SERVER_CREDENTIALS`
= فقط داخل Edge Function Secrets. لا Flutter/.env في Build/GitHub.

## Error Contract موحّد (11.6)
Backend يرجع فئات واضحة → Repository يحولها إلى `AppException` نوعية → Cubit يحولها لحالة UI مفهومة.
`AUTH_REQUIRED · NOT_AUTHORIZED · VALIDATION_ERROR · EXAM_EXPIRED · EXAM_ALREADY_SUBMITTED · VIDEO_NOT_READY · ATTEMPT_ALREADY_EXISTS …`

## سيناريوهات الهجوم (12.5) — تُكتب كاختبارات فعلية قبل أي Production Release
```text
Student A → بيانات Student B            ❌ يفشل   |  Student A → Tenant B        ❌ يفشل
Parent A → طفل B غير مرتبط              ❌ يفشل   |  Student → Draft Content      ❌ يفشل
Student → فيديو غير مصرح                ❌ يفشل   |  Student → تعديل درجته         ❌ يفشل
Student → رؤية is_correct قبل التسليم    ❌ يفشل   |  Student → عملية إدارية        ❌ يفشل
Student → محتواه الخاص                  ✅ ينجح   |  Parent → طفله المرتبط         ✅ ينجح
Teacher → بيانات Tenant الخاص به        ✅ ينجح
```
- **أداء RLS (5.5):** `EXPLAIN ANALYZE` على أهم الاستعلامات المحمية قبل الإطلاق وعند أي نمو ملحوظ — لا Sequential Scan مخفي داخل الـPolicy.
- الحدود الواقعية: لا ندّعي منع غش 100% أو "أمان مطلق" — نحمي كل عملية حساسة في الطبقة ذات السلطة الحقيقية.

## خصوصية القُصَّر (القسم 13 — هندسي وليس قانونيًا)
Data Minimization (full_name/email/phone فقط) • موافقة ولي الأمر عبر المدرس كطبقة مراجعة بشرية • حساب `rejected` بمدة احتفاظ معقولة • بند مفتوح: Data Deletion Request Flow • Private Buckets دائمًا • لا بيانات حساسة في Push/Lock Screen • لا بيع/مشاركة لبيانات الطلاب.


---

# 04 — نظام التصميم (المرجع: الوثيقة القسم 15 + 02-design-system من الحزمة)

## الاتجاه البصري: "Modern Mathematical Academic SaaS"
ليس LMS كرتونيًا، وليس Admin Panel. Screenshot بدون Logo يجب أن يقول "منصة تعليم رياضيات" عبر لغة التصميم نفسها: أرقام بارزة، Grid/Graph خفيف، رموز رياضية شفافة جدًا (∑ π √x f(x))، دقة هندسية، بساطة.

## الألوان (Tokens فقط — ممنوع ألوان مباشرة في الـWidgets)
| Token | القيمة |
|---|---|
| Primary | **Deep Indigo / Mathematical Blue** (نقطة انطلاق ColorScheme من `0xFF5B4FE0` — يُثبَّت في memory/design.md) |
| Background | Off-white دافئ |
| Surface | أبيض |
| Text | Charcoal / Navy |
| Accent | محدود جدًا لعناصر الـAction فقط |
| Success / Warning / Error / Info | دلالية فقط |
| ممنوع | Rainbow UI، أكثر من 3-4 ألوان أساسية، `Color(0xFF…)` داخل أي Widget |

## قواعد الصياغة (الحديدية)
- كل لون عبر `Theme.of(context).colorScheme.*`، كل مسافة عبر `ThemeExtension` (AppSpacing)، كل خط عبر `textTheme.*`.
- Special look = widget variant (constructor/enum) — لا style overrides متفرقة.
- RTL: `EdgeInsetsDirectional`/`AlignmentDirectional` (لا left/right) — الدعم الكامل للعربية من اليوم الأول. أيقونات الاتجاه تُترك لـFlutter auto-mirror.
- الأرقام (`82%`, `03:42`, `10 Students`) عنصر بصري بارز، وليست نصًا عاديًا.
- A11y: أهداف ≥48×48، `Semantics` لأزرار الأيقونات، تباين ≥4.5:1، دعم text scaling.
- Responsive: `LayoutBuilder`/breakpoints — اختبار على موبايل صغير وكبير وTablet.

## المقاييس
- Spacing scale: **4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48 / 64**
- Radius: متوسط (8–16). **Border أفضل من Shadow ثقيل**.
- Typography: عناوين هندسية حديثة + Body واضح، دعم عربي/إنجليزي.
- Loading = **Skeletons** (وليس CircularProgressIndicator في كل مكان). Empty/Error States بشخصية المنتج.
- **Light Theme فقط في V1** (Dark لاحقًا دون كسر Tokens). Animation قليلة وظيفية — لا Parallax/Glassmorphism/Neon.
- Navigation مختلفة تمامًا حسب الدور (Teacher/Student/Parent) — لا Dashboard واحد بشرط `if role ==`.

## Design System موحّد
`AppButton (primary/hero/…) · AppTextField · AppCard · AppLoading · AppErrorView · AppEmptyView`
— لا شاشة تخترع Component خاصًا بها.

## الـLogo
لا كليشيهات: لا آلة حاسبة، لا قبعة تخرج، لا حرف M. شكل هندسي مجرد مستوحى من Graph / ∑ / نظام إحداثيات.

## الأداء كجزء من التصميم
لا صور ضخمة، لا إعادة بناء غير ضرورية، لا Animations ثقيلة. Pagination + Lazy Loading + Image Caching = "تصميم جيد" وليس تفصيلًا منفصلًا.


---

# 05 — سير العمل وضمان الجودة (المرجع: الوثيقة أقسام 17.3، 21 + 04-workflow من الحزمة)

## الحلقة الإلزامية لكل دفعة تعديلات
```text
1. اقرأ قبل أن تكتب — لا تعدّل ملفًا لم تقرأه في هذه الجلسة.
2. Scope: طلب واضح ضيق → نفّذ. طلب واسع/غامض → اسأل سؤالين على الأكثر ثم نفّذ.
3. خطة قصيرة (≤7 أسطر) لو المهمة تلمس >3 ملفات: الملفات المتأثرة + الترتيب + معيار "تم".
4. أصغر تغيير يحقق الهدف — لا Refactors/إعادة تسمية/"تحسينات" جانبية.
5. تحقق آلي بعد كل دفعة:
   dart run build_runner build --delete-conflicting-outputs   # لو تغيّر أي codegen
   flutter analyze
   dart format --set-exit-if-changed .
   flutter test
   flutter build apk --debug   # أو ios/web — Build حقيقي وليس analyze فقط
   اقرأ كل المخرجات. exit 0 مع كلمة "error" في أي سطر = فشل.
6. تحقق بصري/سلوكي: شغّل على جهاز/Simulator، تمرّن على الشاشة/الفلو فعليًا، افحص الـdebug console.
7. حدّث memory/ بأي قرار/تفضيل/رفض جديد.
```

## Debugging
- ابدأ من الإشارة: Stack trace ← debug console ← الـWidget/State المعني. لا تخمين.
- شخّص → تحقق → أصلح → أثبت. أصلح **فئة** الخطأ لا الحالة الواحدة.
- بعد 3 محاولات فاشلة على نفس الخطأ: توقف، غيّر المنهج (Widget test معزول / ابحث بالنص الحرفي للاستثناء).
- ممنوع: `try/catch {}` صامت، `// ignore:` بلا سبب، `!` (null assertion) بلا تحقق.

## Definition of Done لأي Feature (21.4)
```text
☑ UI + Responsive        ☑ حالات Loading/Empty/Error   ☑ Validation
☑ Cubit + Repository     ☑ RLS محقَّقة                ☑ Permission checks
☑ Unit tests للمنطق الحرج ☑ Critical flow مختبر        ☑ flutter analyze نظيف
☑ flutter test ناجح      ☑ Production build ينجح
```
> لا Feature "مكتملة" لمجرد أن الشاشة ظهرت — يجب أن تجتاز معاييرها ولا تكسر أي Flow حرج موجود.

## اختبارات RLS/Security (ذراع إلزامي)
سيناريوهات القسم 12.5 تُكتب كـTests فعلية (Supabase tests + Repository layer tests):
- Unit: حساب درجة الامتحان، حالة الحضور، قواعد الوصول للـGroup.
- Repository/Data: طالب في Group A لا يحصل على محتوى Group B.
- RLS Attack Tests: قائمة 12.5 كاملة.
- أداء الـPolicies عبر `EXPLAIN ANALYZE` (5.5).

## الرحلات الحرجة E2E (21.3)
تسجيل واعتماد طالب → إنشاء/نشر محتوى (مع previous_content_access) → دورة واجب كاملة → دورة امتحان كاملة (انتهاء وقت، تسليم مزدوج، انقطاع إنترنت، محاولة الوصول للإجابة الصحيحة) → رحلة Parent (عزل الأبناء غير المرتبطين) → الفيديو (رفع، معالجة، تشغيل، استئناف، منع تزوير الـProgress بسهولة).

## CI/CD Gate
كود لا يمر بـ analyze + test + build لا يصل Production — بوابة آلية، لا ثقة يدوية.
```text
PR → flutter analyze → flutter test → Build → PASS → Merge → main → Deploy
```

## التواصل
باختصار: ماذا تغيّر + كيف تحققت. لا سرد ملف-بملف. لو الطلب خاطئ تقنيًا: قل ذلك بسطر واحد ثم نفّذ المطلوب. لا تدّعِ إنجازًا بلا تشغيل فعلي.

## Memory (احفظ فورًا)
- قرار صريح، تصحيح لك، فكرة مرفوضة، قاعدة عمل.
- `memory/project.md` (الهدف/النطاق/خارج النطاق) · `memory/design.md` (الاتجاه + Tokens) · `memory/decisions.md` (ADR مصغّر: قرار + لماذا + البدائل المرفوضة) · `memory/constraints.md` (منعيات نهائية + السبب + التاريخ).
- عند تعارض تعليمات جديدة مع memory: اعترض بسطر واحد واحصل على تأكيد قبل التطبيق — لا تكتُب فوقها بصمت.
