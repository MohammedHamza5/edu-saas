# وثيقة المواصفات الفنية والمعمارية: منظومة إدراج الصور ولقطات الشاشة في الامتحانات
## (Exam Image & Screenshot Engine with Cloudflare R2 Integration)

> **الهدف:** تمكين المعلم من بناء امتحانات احترافية بسرعة خارقة عبر السحب والإفلات، اللصق المباشر من الحافظة (Ctrl+V بعد لقطة الشاشة)، أداة قص وتحرير مدمجة، وتخزين سحابي فائق السرعة وبلا تكلفة باندويث (Zero Egress) عبر **Cloudflare R2**، مع تجربة عرض وتكبير تفاعلي مريح للطالب.

---

## 1. الفلسفة المعمارية واختيار Cloudflare R2

### أ) لماذا Cloudflare R2 وليس التخزين التقليدي؟
1. **انعدام تكاليف نقل البيانات (Zero Egress Fees):**
   في منصات التعليم، يقوم مئات أو آلاف الطلاب بتحميل صور الامتحانات في نفس اللحظة. في التخزين التقليدي (AWS S3 أو Supabase Storage)، تُفرض رسوم باهظة على كل جيجابايت يخرج للطلاب. Cloudflare R2 يقدم **$0 تكلفة Egress نهائياً**.
2. **شبكة التوزيع العالمية (Cloudflare Global Edge CDN):**
   تُسلَّم الصور من أقرب خادم كاش جغرافي للطالب (في مصر أو الشرق الأوسط أو العالم)، مما يضمن فتح الصور فوراً في أجزاء من الثانية حتى على شبكات الجوال الضعيفة.
3. **توافق كامل مع معايير S3 (S3-Compatible API):**
   سهولة التعامل مع التخزين باستخدام نفس بروتوكولات AWS S3 القياسية ومكتبات HTTP البسيطة.
4. **باقة مجانية سخية شهرياً:**
   - 10 جيجابايت تخزين مجاني دائم.
   - 10 ملايين عملية قراءة Class B مجانية شهرياً.

---

## 2. رحلة المعلم وتجربة المستخدم (Teacher Dashboard & Question Builder)

### أ) طرق إدخال الصور الفائقة السرعة (Input Methods)
1. **اللصق المباشر من الحافظة (Direct Paste - `Ctrl + V` / `Cmd + V`):**
   * **الميزة التنافسية الأقوى:** المعلم يفتح ملف PDF أو ورقة امتحان، يلتقط لقطة شاشة باستخدام اختصار الويندوز (`Win + Shift + S`) أو الماك (`Cmd + Shift + 4`).
   * يتوجه مباشرة إلى واجهة بناء السؤال ويضغط `Ctrl + V`.
   * يلتقط محرر Flutter حدث اللصق من الحافظة (`Clipboard.readImage()`) ويحوّلها فورياً إلى ملف رقمي دون الحاجة لحفظها على جهازه وتصفح المجلدات.
2. **السحب والإفلات (Drag & Drop):**
   * منطقة إفلات تفاعلية داخل السؤال (Drop Target) تدعم سحب أي ملف صورة من سطح المكتب أو المجلدات.
3. **مستكشف الملفات (File Picker):**
   * زر استعراض تقليدي لاختيار صورة من الجهاز (`image/png`, `image/jpeg`, `image/webp`).

### ب) أداة القص والتحرير المدمجة (In-App Image Cropper Modal)
* بمجرد لصق أو إفلات الصورة، تفتح نافذة منبثقة تفاعلية فوراً قبل الرفع:
  - **القص (Crop):** بمستطيل تحديد ذكي يدعم النسب الحرة أو النسب القياسية (16:9, 4:3, 1:1).
  - **التدوير (Rotate):** تدوير بـ 90 درجة لتصحيح زوايا لقطات الشاشة أو تصوير الموبايل.
  - **الإلغاء والتأكيد (Cancel / Apply):** عند الضغط على "تأكيد"، يتم ضغط الصورة وتحويلها ورفعها تلقائياً.

### ج) إعدادات مظهر العرض داخل السؤال (Display Settings)
* **المحاذاة (Alignment):** يمين (Right) | وسط (Center - الافتراضي) | يسار (Left).
* **الحجم (Width Sizing):**
  - صغير: 40% من عرض الشاشة.
  - متوسط: 70% من عرض الشاشة (الافتراضي).
  - كامل: 100% (Full Width) للرسوم البيانية الكبيرة والجداول المعقدة.
* **تفعيل التكبير (Enable Lightbox Zoom):** خيار تفعيل/تعطيل زر العدسة المكبرة للطالب.

---

## 3. مستويات دعم الصور داخل هيكل الامتحان (Structural Support)

1. **صورة على مستوى السؤال (Question-Level Image):**
   - تظهر أسفل نص السؤال ومباشرة قبل خيارات الإجابة.
2. **صورة السياق المشترك (Shared Passage / Context Image):**
   - رسم بياني، قطعة قراءة، أو كود برمجي تشترك فيه عدة أسئلة (مثلاً: "الأسئلة من 5 إلى 8 بناءً على الشكل التالي").
   - تمنع تكرار رفع نفس الصورة 4 مرات وتوفر مساحة الشاشة وسرعة التحميل.
3. **صورة لكل خيار إجابة (Option-Level Image):**
   - في أسئلة الاختيار من متعدد، يمكن أن يكون كل خيار (A, B, C, D) عبارة عن صورة (شكل هندسي، رسمة بيانية، كود، أو معادلة رياضية).

---

## 4. نموذج البيانات المقترح في PostgreSQL (Data Model)

```sql
-- 1. جدول السياقات المشتركة (للأسئلة التابعة لقطعة أو رسم مشترك)
CREATE TABLE IF NOT EXISTS public.exam_contexts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exam_version_id UUID NOT NULL REFERENCES public.exam_versions(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES public.tenants(id),
    title TEXT,                                   -- مثال: "Based on the following diagram"
    context_text TEXT,                            -- نص القطعة إن وجد
    image_url TEXT,                               -- رابط الصورة على Cloudflare R2
    image_meta JSONB NOT NULL DEFAULT '{"alignment": "center", "width_percent": 80, "enable_zoom": true}'::jsonb,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. تحديث جدول أسئلة الامتحانات لدعم الصور وإعدادات العرض
ALTER TABLE public.exam_questions 
    ADD COLUMN IF NOT EXISTS image_url TEXT NULL,
    ADD COLUMN IF NOT EXISTS image_meta JSONB NULL DEFAULT '{"alignment": "center", "width_percent": 75, "enable_zoom": true}'::jsonb,
    ADD COLUMN IF NOT EXISTS context_id UUID NULL REFERENCES public.exam_contexts(id) ON DELETE SET NULL;

-- 3. تحديث جدول خيارات الأسئلة لدعم الصور
ALTER TABLE public.question_options
    ADD COLUMN IF NOT EXISTS image_url TEXT NULL,
    ADD COLUMN IF NOT EXISTS image_meta JSONB NULL DEFAULT '{"alignment": "center", "width_percent": 100}'::jsonb;

-- 4. فهارس الأداء
CREATE INDEX IF NOT EXISTS idx_exam_questions_context ON public.exam_questions(context_id);
CREATE INDEX IF NOT EXISTS idx_exam_contexts_version ON public.exam_contexts(exam_version_id);
```

---

## 5. خط أنابيب معالجة ورفع الملفات (Upload Pipeline & Cloudflare R2)

```
[لقطة شاشة Ctrl+V أو سحب ملف]
             ↓
[نافذة القص والتحرير In-App Cropper]
             ↓
[ضغط في المتصفح وتحويل لـ WebP بدقة 85%]
             ↓
[طلب رابط رفع مؤقت Presigned Upload URL] ← Edge Function
             ↓
[الرفع المباشر إلى Cloudflare R2 Bucket]
             ↓
[توليد رابط CDN السريع وحفظه في السؤال]
```

### أ) هيكل المسارات المنظم داخل R2 Bucket:
```text
tenants/{tenant_id}/exams/{exam_id}/questions/{question_id}_{timestamp}.webp
tenants/{tenant_id}/exams/{exam_id}/contexts/{context_id}_{timestamp}.webp
tenants/{tenant_id}/exams/{exam_id}/options/{option_id}_{timestamp}.webp
```

### ب) معايير التحقق والضغط (Validation & Optimization):
* **الصيغ المقبولة:** PNG, JPEG, WebP.
* **الحد الأقصى:** 5 ميجابايت للملف الأصلي.
* **الضغط التلقائي:** تحويل إلى WebP بنسبة جودة 85% لتقليل حجم الصورة بنسبة 70% دون أي فقد في وضوح النصوص الرياضية أو الأرقام.

---

## 6. تجربة الطالب أثناء أداء الامتحان (Student UX)

1. **العرض المتجاوب الذكي (Responsive Layout):**
   * ضبط تلقائي لعرض الصورة حسب حجم شاشة الطالب (موبايل، تابلت، أو لابتوب) دون تشويه الأبعاد (`BoxFit.contain`).
2. **نافذة التكبير التفاعلية (Interactive Lightbox Zoom):**
   * عند النقر على أي صورة (أو أيقونة التكبير 🔍)، تفتح نافذة تكبير كاملة الشاشة مع دعم:
     - اللمس المتعدد للتكبير (Pinch-to-zoom).
     - النقر المزدوج (Double-tap zoom).
     - السحب لتحريك الصورة وفحص الأرقام الدقيقة.
   * إغلاق سلس بنقرة واحدة للعودة للامتحان دون ضياع ثانية واحدة من وقت الطالب.
3. **التحميل الكسول السريع ومنع قفزات الواجهة (CLS Prevention):**
   * استخدام `CachedNetworkImage` مع إظهار مستطيل تحميل رمادي خفيف (`Skeleton Placeholder`) بنفس الأبعاد المتوقعة حتى لا يقفز نص الامتحان عند اكتمال تحميل الصورة.

---

## 7. خطة التنفيذ المعتمدة (Implementation Roadmap)

### المرحلة 1: البنية التحتية السحابية وقاعدة البيانات (Cloudflare R2 & DB)
1. إنشاء R2 Bucket على Cloudflare باسم `edu-saas-media`.
2. ضبط سياسات الـ CORS ونطاق CDN المخصص (`cdn.edu-saas.com` أو رابط R2 العام).
3. تطبيق Migration على قاعدة البيانات لإضافة أعمدة `image_url` و `image_meta` وجدول `exam_contexts`.
4. بناء Edge Function لتوليد Presigned URLs لرفع الصور بأمان وعزل تام بين الـ Tenants.

### المرحلة 2: محرك الرفع والقص في واجهة المعلم (Flutter Teacher Builder)
1. تطبيق ميزة استماع الحافظة (`Ctrl + V` Pasting) لتحويل لقطات الشاشة فوراً لصور.
2. إضافة ميزة السحب والإفلات (Drag & Drop) ومستكشف الملفات.
3. بناء Widget مخصص للقص والتحرير (`AppImageCropperDialog`) مع خيارات التدوير وضبط الأبعاد.
4. لوحة تحكم إعدادات العرض (المحاذاة: يمين/وسط/يسار، الحجم: 40%/70%/100%).

### المرحلة 3: محرك عرض الصور التفاعلي للطلاب (Flutter Student Exam View)
1. بناء `ExamImageViewer` مع التحميل المؤقت و Skeleton Loading.
2. بناء نافذة التكبير التفاعلية `InteractiveLightboxView` (دعم اللمس، التكبير بالماوس، والتمرير).
3. دعم خيارات الإجابة الصورية (Option Images) والسياق المشترك (Passage Images).

---

## 8. معايير القبول والجودة (Definition of Done)

- [ ] المعلم يستطيع أخذ لقطة شاشة بـ `Win + Shift + S` والضغط على `Ctrl + V` داخل خانة السؤال لتفتح نافذة القص والرفع فوراً.
- [ ] الصورة تُرفع إلى Cloudflare R2 وتُخزن بصيغة WebP خفيفة وفائقة الوضوح.
- [ ] حفظ واسترجاع إعدادات المحاذاة (يمين، وسط، يسار) والحجم (40%, 70%, 100%) بنجاح.
- [ ] الطالب يستطيع النقر على الصورة وتكبيرها بمرونة كاملة وإغلاقها دون التأثير على سير الامتحان.
- [ ] فحص كود Flutter بالكامل والتأكد من خلوه التام من أخطاء `flutter analyze` مع التعريب الكامل للواجهات (Zero Localization Debt).
