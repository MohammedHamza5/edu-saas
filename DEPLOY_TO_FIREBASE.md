# 🚀 دليل رفع وتحديث منصة EduSaaS على Firebase Hosting

> هذا الدليل يوضح لك بالخطوات العملية والمباشرة كيفية بناء ورفع أي تحديثات برمجية جديدة لموقع المنصة الحي المربوط على Firebase Hosting.

---

## 📌 معلومات الموقع الحالي (Live Credentials)
| البيان | القيمة |
|---|---|
| **الرابط المباشر (Primary URL)** | [https://antounios.web.app](https://antounios.web.app) |
| **الرابط البديل (Secondary URL)** | [https://antounios.firebaseapp.com](https://antounios.firebaseapp.com) |
| **مشروع Firebase (Project ID)** | `ed-sentre` |
| **معرف الموقع (Site ID)** | `antounios` |
| **مسار المخرجات (Public Directory)** | `build/web` |
| **حساب المدرس التجريبي** | `teacher.demo@edusaas.com` / `Teacher@2026!` |

---

## ⚡ الخيار الأول: الرفع الصاروخي التلقائي (الأسهل والموصى به دائمًا)
تم تجهيز سكريبت البناء الصاروخي [build_web_rocket.ps1](file:///c:/Users/KimoStore/StudioProjects/edu_saas/scripts/build_web_rocket.ps1) ليقوم بكل الخطوات (فحص الكود + البناء بأعلى كفاءة Level-4 + تشجير الأيقونات + حقن المتغيرات + الرفع للفيربيس):

### 1. للبناء الكامل مع الفحص والرفع:
افتح الـ PowerShell في مجلد المشروع وشغّل:
```powershell
.\scripts\build_web_rocket.ps1 -DeployFirebase
```

### 2. للبناء والرفع السريع (تخطي الفحص والاختبارات لتوفير الوقت):
```powershell
.\scripts\build_web_rocket.ps1 -SkipAnalyze -SkipTests -DeployFirebase
```

> **ماذا يفعل هذا السكريبت تلقائيًا؟**
> 1. يترجم تطبيق Flutter Web بأعلى أداء تحسين `-O4`.
> 2. يحقن مفاتيح بيئة العمل عبر `--dart-define-from-file=.env`.
> 3. يقلص حجم خطوط وأيقونات Material و Cupertino بنسبة تتجاوز 97%.
> 4. ينسخ ملف ترويسات الأمان والكاش `_headers`.
> 5. يضبط بروتوكول IPv4 تلقائيًا لتفادي أي مشاكل شبكة.
> 6. يرفع التحديث مباشرة على موقع `antounios` على Firebase.

---

## 🛠️ الخيار الثاني: استخدام سكريبت الرفع المخصص (deploy_firebase.ps1)
إذا كان مجلد `build/web` جاهزاً وتريد رفعه فوراً دون إعادة البناء:

```powershell
.\scripts\deploy_firebase.ps1
```

وإذا أردت تخطي البناء ورفع المحتوى الحالي فقط:
```powershell
.\scripts\deploy_firebase.ps1 -SkipBuild
```

---

## 💻 الخيار الثالث: الأوامر اليدوية خطوة بخطوة (Terminal)
إذا أردت تنفيذ كل خطوة بنفسك في موجه الأوامر (PowerShell):

### الخطوة 1: بناء تطبيق الويب مع الـ Cache-Busting والسرعة الصاروخية
```powershell
.\scripts\build_web_rocket.ps1
```

### الخطوة 2: تفعيل بروتوكول IPv4 ثم الرفع المباشر
```powershell
$env:NODE_OPTIONS = "--dns-result-order=ipv4first"
firebase deploy --only hosting:antounios
```

---

## 🔄 التحديثات اللحظية والتخلص التام من الكاش (Zero-Cache Debt)
تم تأمين المنصة بالكامل ضد مشاكل الكاش القديمة عبر معمارية متعددة الطبقات:
1. **لا حاجة لحذف كاش المتصفح:** يتم توليد بصمة فريدة لكل بناء تلقائيًا وحقنها في `flutter_bootstrap.js` (مثل `main.dart.js?v=20260913...`) مما يجبر المتصفح على تحميل الكود الجديد فورًا.
2. **ترويسات No-Cache صارمة:** تم ضبط `firebase.json` و `web/_headers` لمنع تخزين صفحات الـ HTML ومسارات الـ SPA في ذاكرة المتصفح.
3. **إبادة الـ Service Workers:** يتم إلغاء أي Service Worker وتفريغ الـ CacheStorage فور بدء تحميل الصفحة.
4. **للمستخدمين والطلاب:** بمجرد فتح الموقع أو عمل Refresh عادي، يظهر التحديث الجديد فورًا دون أي خطوات يدوية إضافية.

---

## 🔍 حل المشاكل الشائعة (Troubleshooting)

### 1. ظهور خطأ `Error: Failed to make request to https://firebasehosting...` أو `ETIMEDOUT`
- **السبب:** مزود الإنترنت (ISP) لديك يعلق عند محاولة اتصال Node بـ IPv6.
- **الحل:** تأكد دائمًا من كتابة الأمر التالي قبل الرفع (السكريبتات تقوم به تلقائيًا):
  ```powershell
  $env:NODE_OPTIONS = "--dns-result-order=ipv4first"
  ```

### 2. ظهور خطأ `FirebaseError: Failed to authenticate` أو طلب تسجيل الدخول
- **الحل:** أعد تسجيل الدخول في أداة Firebase CLI عبر تشغيل:
  ```powershell
  firebase login --reauth
  ```

### 3. التأكد من قائمة المواقع المتاحة في حسابك
```powershell
$env:NODE_OPTIONS = "--dns-result-order=ipv4first"
firebase hosting:sites:list
```
ستظهر لك قائمة المواقع وتتأكد أن `antounios` مفعل ومربوط.

---
*تم إعداد وتوثيق هذا الدليل لضمان استمرارية الرفع بأمان وسرعة للمنصة التعليمية.*
