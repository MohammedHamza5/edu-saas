# نظام مرجعي معتمد — منصة SaaS التعليمية White-Label (V1)
> الإصدار 1.0 · 2026-09-06 · **هذا الملف هو السياق الوحيد الذي يُلصق في بداية كل دردشة — لا ترسل غيره.**

## المنتج
منصة تعليمية SaaS بنموذج White-Label للمدرسين المستقلين؛ كل مدرس = Tenant معزول تمامًا. V1: نظام أمريكي، ~10 طلاب، مُنظَّمون في Groups (Basics / Advanced / SAT / EST / ACT)، والطالب قد ينتمي لأكثر من Group. الـGroup = وحدة توزيع المحتوى.

## الستاك المقفول (لا ارتجال — أي سؤال خارجه = اسأل)
Flutter (stable) · flutter_bloc — **Cubit فقط** (لا Riverpod) · go_router · Supabase (Auth + PostgreSQL + RLS + Storage + Edge Functions) · Bunny Stream (الـDB يحفظ Metadata فقط) · FCM (توصيل فقط) · Cloudflare Pages · json_serializable + equatable · ARB (ar/en) مع RTL/LTR من اليوم الأول. **لا** VPS/Docker/Redis/Node Server خاص/Drift في V1.

## أصل الحقيقة — غير قابل للتفاوض
1. Flutter عميل غير موثوق: أي `tenant_id / role / status / score / is_correct` من العميل = صفر ثقة؛ الحقيقة من `auth.uid()` → `public.users`.
2. RLS هو خط الدفاع الحقيقي — صلاحية غير مفروضة على قاعدة البيانات = غير موجودة أمنيًا.
3. عزل Tenants مطلق — لا استثناء حتى "مؤقتًا".
4. البيانات الأكاديمية التاريخية Immutable — Exam Published = Snapshot مجمَّد.
5. العمليات الحساسة Atomic عبر Edge Functions فقط: `approve-student · start-exam · submit-exam · video-playback · bunny-webhook · send-notification · record-activity`.
6. لا تعقيد بلا حاجة حقيقية.
7. لا وعود لا نفيها (لا "Anti-Cheat 100%"، لا "منع تصوير الشاشة").

## ممنوعات — ارفض أي اقتراح منها بسطر واحد
لا Riverpod · لا Drift/Offline DB · لا Dark Mode في V1 · لا Chat · لا Excel/PDF Export · لا AI Risk Score · لا أدوار Admin/Assistant · لا Service Role Key في Flutter/Git · لا Public Bucket · لا إرسال `is_correct` للطالب أبدًا · لا حساب درجات Client-side · لا Optimistic UI في (تسليم امتحان/تقييم واجب/اعتماد طالب/حضور/نشر امتحان) · لا Subscription/Billing قبل قرار موثّق · لا تعديل Schema/RLS خارج تاسك "تعديل" موثّق.

## طريقة العمل — مهمة واحدة في كل مرة
1. نفّذ المهمة الحالية بالترتيب من `07_ROADMAP_TASKS.md` — لا تقفز، ولا تبدأ التالية قبل اجتياز DoD.
2. انسخ قالب المهام من `09_DEFINITION_OF_DONE.md` واملأه لتاسكك.
3. اكتب خطة قصيرة (≤7 أسطر) وانتظر موافقتي قبل أي كود.
4. نفّذ دفعة واحدة، ثم أثبت: `flutter analyze` نظيف + `flutter test` + Build حقيقي + تمرين الشاشات + حالات loading/empty/error.
5. أي قرار تنفيذي جديد → سجّله في `10_DECISIONS.md` ثم أكمل.

## المرجعية عند الحاجة للتفاصيل
`03_ARCHITECTURE_MASTER.md` هو المصدر الأعلى — يُستدعى برقم القسم (مثال: "Context: القسم 7 + 14"). التفاصيل: `02_PRD.md` (النطاق) · `04_DATA_MODEL.md` (الجداول/الفهارس/قواعد الأعمال) · `05_API_CONTRACT.md` (العقود/الأخطاء/الطبقات) · `06_UI_UX_SCREENS.md` (الشاشات/الرحلات/الإشعارات) · `08_AGENTS_RULES.md` (قواعد التنفيذ الحُكمية).

## البنود المفتوحة — لا تنفَّذ حتى قرار موثّق
Subscription/Billing (v1.16 فجوة موثّقة) · Subscription Enforcement (v1.22) · Data Deletion Flow · المراجعة القانونية للخصوصية (قُصَّر) · تأكيد Bunny العملي النهائي.
