# تعريف الإتمام (DoD) الموحدة + قوالب المهام
> الإصدار 1.0 · 2026-09-06 · تُنسخ القوالب وتُملأ لكل تاسك. لا تبدأ تاسكًا بلا قالب مملوء، ولا تنتقل للتالية قبل اجتياز DoD.

---

## أولًا: القواعد الحاكمة (تنطبق على كل تاسك بلا استثناء)

1. **لا ميزة بلا عزل Tenant** — كل جدول يحمل `tenant_id` وكل سياسة وصول تفحصه أولًا.
2. **لا جدول بلا صلاحيات + سياسات وصول** في نفس خطوة الإنشاء.
3. **لا واجهة بلا 4 حالات:** تحميل (Skeleton) / فارغة / خطأ / نجاح.
4. **لا زر بلا حالة انتظار ومنع النقر المزدوج.**
5. **لا نموذج بلا تحقق مزدوج:** واجهة + خادم (الخادم هو المرجع).
6. **الموبايل أولًا** ثم الشاشات الكبيرة، ودعم كامل للعربية RTL.
7. **كل ميزة تُسلَّم مع سيناريو اختبار يدوي مكتوب** يُنفَّذ قبل الانتقال.
8. **لا تعديل على ميزة مكتملة** إلا عبر تاسك "تعديل" مستقل موثّق.

## ثانيًا: قائمة التحقق الموحدة (DoD)

- [ ] `flutter analyze` نظيف + `flutter test` يمر + Build حقيقي (`flutter build web` / `apk`)
- [ ] حالات loading / empty / error في كل شاشة تجلب بيانات (+ Responsive)
- [ ] RLS محققة على الجداول المعنية + فحص IDOR (محاولة قراءة/كتابة معرف غير مصرّح)
- [ ] منع النقر المزدوج + `context.mounted` بعد كل await
- [ ] التحديث في `10_DECISIONS.md` (قرار/منع/تفضيل جديد)
- [ ] سيناريو اختبار يدوي مكتوب ومُنفَّذ للميزة
- [ ] RTL يعمل + تباين ≥ 4.5:1 + لا `Color(0xFF…)` داخل Widget
- [ ] لا Secrets في الكود/الـGit (فقط Edge Function Secrets)

## ثالثًا: قالب المهمة 1 — ميزة جديدة

```markdown
## Feature
<اسم الميزة بجملة واحدة>

## User & goal
As a <مدرس/طالب/ولي أمر> I want <الإجراء> so that <القيمة>.

## Scope
In scope:
- ...
Out of scope (don't touch):
- ...

## Data
Backend track: Supabase (RLS) / Edge Function / Bunny / FCM
New tables/fields: ...
Who reads? Who writes? (لتحديد سياسات RLS بدقة)

## UI
Screen(s): ...
State management: Cubit + Repository
Required states: loading / empty / error / success

## Acceptance criteria
- [ ] ...
- [ ] flutter analyze + flutter test + real build clean
- [ ] RLS + GRANTs + server-side role check present
- [ ] لا ألوان/أحجام Hard-coded داخل أي Widget

## Delivery
1. خطة قصيرة (≤7 أسطر) — انتظر موافقتي.
2. ثم نفّذ دفعة واحدة، شغّل التحقق، واعرض الناتج.
```

## رابعًا: قالب المهمة 2 — إصلاح خطأ

```markdown
## Symptoms
What I see: ... What I expect: ... Repro steps: 1) 2) 3)
Exception text: <الصق الخطأ حرفيًا>
Platform: iOS / Android / Web / all

## Rules
1. لا تلمس أي كود قبل شرح السبب الجذري مع دليل (Stack trace / سطر كود).
2. أصلح الفئة لا الحالة: افحص كل شاشة تشارك نفس الافتراض واصلحها في نفس الجلسة.
3. ممنوع: try/catch صامت، `!`/`as` بلا تحقق، تعطيل قاعدة Analyzer، Refactor واسع.
4. أثبت الإصلاح: flutter analyze / flutter test / تشغيل المسار المعطوب وعرض النتيجة.
5. بعد 3 محاولات فاشلة: توقف وغيّر المنهج واعرض فرضيتين بديلتين.
```

## خامسًا: قالب المهمة 3 — تصميم/إعادة تصميم

```markdown
## Screen
<الاسم + الغرض>

## Visual direction (ثبّتها — لا انجراف)
Mood: <هادئ/تحريري — ليس Material افتراضي>
Reference: <تطبيق/منتج محدد>
Rejection: لا <الأسلوب الممنوع>

## Requirements
1. أولًا: حرّر lib/core/theme/ فقط — ColorScheme (light+dark) + TextTheme + spacing/radius ThemeExtension. اعرض قبل أي Widget.
2. ثانيًا: ابنِ الشاشة باستخدام Tokens فقط + متغيرات Widgets.
3. Composition: حددها صراحة (عدد الأقسام/الأزرار/البطاقات).

## Banned
seed-purple الافتراضي · AppBar/Card افتراضي بلا هوية · Roboto بلا تخصيص · أي لون/حجم Hard-coded.

## Acceptance
- [ ] كل Token موجود في light وdark
- [ ] لا Hard-coded داخل أي Widget
- [ ] اختبار: هاتف صغير + كبير + Tablet (+ RTL إن انطبق)
- [ ] تباين ≥ 4.5:1 ويدعم تكبير نص النظام
```

## سادسًا: قاعدة التسليم

كل تاسك: **قالب مملوء ← خطة قصيرة للموافقة ← تنفيذ دفعة واحدة ← إثبات بالتشغيل ← تحديث الذاكرة**. لا "تم" بدون دليل قابل للتشغيل.
