# خطة تنفيذ ميزة إرفاق ملف PDF مع الاختبار (Exam Attached PDF Feature Plan)

> **الهدف:** تمكين المدرس من إرفاق ملف PDF (كراسة أسئلة / ورقة مفاهيم وقوانين) مع أي اختبار، مع تمكين الطالب من قراءة الملف أثناء حل الاختبار داخل التطبيق **دون أي خروج أو كسر لنظام منع الغش (Anti-Cheat Lockdown)**، مع ميزة "الإنشاء السريع لورقة الإجابة (Fast Bubble Sheet Generator)".

---

## 1. السياق والمحددات المعمارية الحاكمة (Critical Constraints)
1. **نظام منع الغش (Anti-Cheat Integrity):**
   * شاشة الامتحان [`ExamTakingPage`](file:///c:/Users/KimoStore/StudioProjects/edu_saas/lib/features/exams/presentation/pages/exam_taking_page.dart) تراقب `visibilitychange` و `AppLifecycleState.paused / hidden`.
   * **ممنوع منعاً باتاً** فتح الـ PDF في تبويب جديد (`_blank`) أو استخدام `url_launcher` أو تحميل الملف كملف خارجي، لأن ذلك يفقد الصفحة التركيز ويحسب فوراً مخالفة غش تؤدي لغلق الاختبار تلقائياً بعد 3 محاولات.
   * **الحل الإلزامي:** عرض الـ PDF داخلياً بنسبة 100% داخل شجرة الـ Widgets في Flutter عبر [`buildSecurePdfViewer`](file:///c:/Users/KimoStore/StudioProjects/edu_saas/lib/features/content/presentation/widgets/secure_pdf_viewer_web.dart) أو عرض متجاوب ومدمج مع علامة مائية باسم الطالب.
2. **الستاك المقفول (Locked Stack):**
   * إدارة الحالة: `Cubit` فقط (`flutter_bloc`).
   * حقن التبعيات: `Pure Constructor Injection` عبر `InjectionContainer`.
   * التوجيه: `go_router`.
   * التعريب الفوري (Zero Localization Debt): أي نصوص جديدة تضاف فوراً وبشكل متزامن في `app_en.arb` و `app_ar.arb` متبوعة بـ `flutter gen-l10n`.
3. **الحالات الأربع الإلزامية لكل واجهة:** (Loading, Empty, Error, Success).

---

## 2. التعديلات المطلوبة على قاعدة البيانات (Database Schema & RPCs)

### أ) ملف هجرة جديد: `supabase/migrations/0091_add_exam_pdf_attachment.sql`
1. **تعديل جدول `public.exams`:**
   ```sql
   ALTER TABLE public.exams 
   ADD COLUMN IF NOT EXISTS pdf_file_id uuid REFERENCES public.files(id) ON DELETE SET NULL;
   ```
2. **تحديث دالة `public.get_exam_details(p_exam_id uuid)`:**
   * تضمين بيانات الملف المرفق في الـ JSON المُعاد للمدرس وللطالب:
     * `pdf_file_id`: معرف الملف.
     * `pdf_file_name`: اسم الملف الأصلي (من جدول `files`).
     * `pdf_file_size`: حجم الملف.
     * `pdf_storage_path`: المسار في التخزين (`storage_path`).
     * `pdf_url`: رابط التحميل المؤقت الموقّع أو المسار المعتمد.

---

## 3. طبقة النطاق والبيانات (Domain & Data Layer)

### أ) تحديث الكيانات والـ Models:
1. **`ExamEntity` في [`lib/features/exams/domain/entities/exam_entity.dart`](file:///c:/Users/KimoStore/StudioProjects/edu_saas/lib/features/exams/domain/entities/exam_entity.dart):**
   * إضافة الحقول:
     ```dart
     final String? pdfFileId;
     final String? pdfFileName;
     final int? pdfFileSize;
     final String? pdfStoragePath;
     final String? pdfUrl;
     ```
   * تحديث الـ `props` و `copyWith`.
2. **`ExamModel` في [`lib/features/exams/data/models/exam_model.dart`](file:///c:/Users/KimoStore/StudioProjects/edu_saas/lib/features/exams/data/models/exam_model.dart):**
   * قراءة الحقول الجديدة من الـ JSON في `fromJson` و `toJson`.

### ب) مصادر البيانات والمستودع:
* في [`exams_remote_datasource.dart`](file:///c:/Users/KimoStore/StudioProjects/edu_saas/lib/features/exams/data/datasources/exams_remote_datasource.dart):
  * عند إنشاء أو تعديل امتحان (`createExam` / `updateExam`)، دعم تمرير `pdfFileId` (أو رفع ملف PDF جديد وتخزينه في جدول `files` كما في قسم المحتوى).

---

## 4. واجهة المدرس: إنشاء وتعديل الاختبار (`CreateExamPage`)

المسار: [`lib/features/exams/presentation/pages/create_exam_page.dart`](file:///c:/Users/KimoStore/StudioProjects/edu_saas/lib/features/exams/presentation/pages/create_exam_page.dart)

### أ) كارت إرفاق الـ PDF (Attached PDF Card):
* إضافة قسم اختياري أنيق في إعدادات الاختبار:
  * زر **"إرفاق كراسة أسئلة (PDF)"** يتيح:
    1. رفع ملف PDF من الجهاز عبر `file_picker`.
    2. أو اختيار ملف موجود مسبقاً من مكتبة الملفات/المذكرات.
  * إظهار تفاصيل الملف بعد إرفاقه (اسم الملف، الحجم) مع زر لمعاينته وزر لحذفه.

### ب) زر المولد السريع لورقة الإجابة (Quick Bubble Sheet Generator):
* في حالة رفع ملف PDF للامتحان، لا يحتاج المدرس لكتابة نص لكل سؤال.
* زر سحري: **"توليد ورقة إجابة سريعة (Generate Bubble Sheet)"**:
  * يسأل المدرس عن عدد الأسئلة (مثلاً: 20 أو 40 سؤالاً)، وعدد الخيارات (4: A, B, C, D).
  * يقوم الـ Cubit بإنشاء الأسئلة تلقائياً بنص بسيط: "سؤال 1"، "سؤال 2"... وتحديد النقاط، ليقوم المدرس فقط بتعليم الإجابة الصحيحة لكل سؤال في ثوانٍ معدودة.

---

## 5. واجهة الطالب: أداء الاختبار بدون مخالفات (`ExamTakingPage`)

المسار: [`lib/features/exams/presentation/pages/exam_taking_page.dart`](file:///c:/Users/KimoStore/StudioProjects/edu_saas/lib/features/exams/presentation/pages/exam_taking_page.dart)

### أ) للشاشات الكبيرة (Desktop / Laptop / Tablet Landscape > 900px):
* تفعيل نظام **الشاشة المقسمة (Split View / Side-by-Side)**:
  * **الجانب الأيمن (55% من العرض):** عارض الـ PDF المدمج بالكامل مع أدوات (تكبير / تصغير / تنقل بين الصفحات) وعلامة مائية أمنية خفيفة.
  * **الجانب الأيسر (45% من العرض):** كروت الأسئلة وورقة الإجابة وخيارات الاختيار والتنقل ومؤقت الامتحان.
  * كلاهما داخل نفس الشاشة والـ Scaffold دون أي فقدان للتركيز.

### ب) للشاشات الصغيرة (Mobile / Portrait < 900px):
* زر عائم أو شريط مثبت أعلى الشاشة: `📄 كراسة الامتحان (PDF)` مع مؤشر رقم السؤال الحالي.
* عند الضغط عليه، يتم إظهار الـ PDF كـ **In-App Overlay Widget** يغطي الشاشة بسلاسة مع زر عائم للعودة لورقة الإجابة:
  * يتم ذلك داخل نفس شجرة الـ Widgets في Flutter دون استدعاء أي نوافذ خارجية.
  * لا يطلق الـ Browser أي حدث `visibilitychange` أو `blur` إطلاقاً، وتظل درجة الأمان 100%.

---

## 6. واجهة مراجعة النتيجة بعد التسليم (`ExamResultPage`)

المسار: [`lib/features/exams/presentation/pages/exam_result_page.dart`](file:///c:/Users/KimoStore/StudioProjects/edu_saas/lib/features/exams/presentation/pages/exam_result_page.dart)
* إذا كان الاختبار يحتوي على PDF، يظهر زر اختياري في شاشة المراجعة: `📄 مراجعة كراسة الامتحان والأسئلة (PDF)` لتمكين الطالب من مراجعة أخطائه على نفس ورقة الأسئلة الأصلية.

---

## 7. ملفات الترجمة المطلوبة (Localization Keys)

يجب إضافة المفاتيح التالية في كل من:
- [`lib/core/localization/app_en.arb`](file:///c:/Users/KimoStore/StudioProjects/edu_saas/lib/core/localization/app_en.arb)
- [`lib/core/localization/app_ar.arb`](file:///c:/Users/KimoStore/StudioProjects/edu_saas/lib/core/localization/app_ar.arb)

```json
"attachedExamPdf": "Attached Exam Booklet (PDF)",
"attachedExamPdfDesc": "Attach a PDF question booklet for students to view securely while solving",
"attachPdfFile": "Attach PDF Booklet",
"removeAttachedPdf": "Remove PDF",
"pdfAttachedSuccess": "PDF booklet attached successfully",
"quickBubbleSheetGenerator": "Quick Bubble Sheet Generator",
"quickBubbleSheetPrompt": "Generate answer sheets quickly for your PDF exam",
"numberOfQuestions": "Number of Questions",
"generateQuestions": "Generate Questions",
"viewExamBooklet": "View Exam Booklet (PDF)",
"hideExamBooklet": "Back to Questions",
"examPdfLoading": "Loading exam booklet..."
```

---

## 8. خطوات التنفيذ والتحقق للوكيل القادم (Execution Checklist)

- [ ] **الخطوة 1:** إنشاء وتطبيق Migration `0091_add_exam_pdf_attachment.sql` لتحديث جدول `exams` ودالة `get_exam_details`.
- [ ] **الخطوة 2:** تحديث `ExamEntity` و `ExamModel` لدعم حقول الـ PDF.
- [ ] **الخطوة 3:** إضافة مفاتيح التعريب في `app_en.arb` و `app_ar.arb` وتشغيل `flutter gen-l10n`.
- [ ] **الخطوة 4:** تحديث `CreateExamPage` و `ExamsCubit` لإتاحة رفع/إرفاق ملف PDF وزر التوليد السريع لورقة الإجابة.
- [ ] **الخطوة 5:** تحديث `ExamTakingPage` لدعم العرض المدمج داخل التطبيق (Split View للشاشات الكبيرة + In-App Overlay للشاشات الصغيرة) مع المحافظة التامة على قيود الـ Anti-Cheat.
- [ ] **الخطوة 6:** تشغيل الفحوصات الإلزامية:
  * `flutter analyze` (يجب أن ينتهي بصفر أخطاء).
  * `flutter test test/features/exams` (يجب أن تنجح كافة الاختبارات).
