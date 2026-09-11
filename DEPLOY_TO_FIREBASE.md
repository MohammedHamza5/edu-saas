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
| **حساب المدرس التجريبي** | `teacher.demo@edusaas.com` / `Teacher123456!` |

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

وإذا أردت إعادة البناء قبل الرفع:
```powershell
.\scripts\deploy_firebase.ps1 -BuildFirst
```

---

## 💻 الخيار الثالث: الأوامر اليدوية خطوة بخطوة (Terminal)
إذا أردت تنفيذ كل خطوة بنفسك في موجه الأوامر (PowerShell):

### الخطوة 1: بناء تطبيق الويب
```powershell
flutter build web --release -O4 --tree-shake-icons --pwa-strategy=offline-first --no-source-maps --dart-define-from-file=.env
```

### الخطوة 2: نسخ ترويسات الأمان والكاش (Headers)
```powershell
Copy-Item web\_headers build\web\_headers -Force
```

### الخطوة 3: تفعيل بروتوكول IPv4 لتفادي Timeout ثم الرفع
```powershell
$env:NODE_OPTIONS = "--dns-result-order=ipv4first"
firebase deploy --only hosting
```

---

## 🔄 هام جدًا: بعد الرفع وتحديث الموقع (تجاوز كاش المتصفح)
نظرًا لأن تطبيق Flutter Web يعمل كـ PWA مع Service Worker، فإن متصفح المستخدمين يحفظ الملفات مؤقتًا ليعمل بدون إنترنت. بعد رفع التحديث مباشرة:

1. **في متصفحك أثناء الاختبار:**
   - اضغط **`Ctrl + Shift + R`** أو **`Ctrl + F5`**.
   - أو افتح أدوات المطور بالضغط على **`F12`** ⬅ اضغط كليك يمين على زر تحديث الصفحة (⟳) ⬅ اختر **"Empty Cache and Hard Reload"**.
   - أو اختبر في نافذة تصفح متخفي جديدة (**Incognito Window**) عبر `Ctrl + Shift + N`.
2. **للمستخدمين العاديين والطلاب:**
   - سيتعرف المتصفح تلقائيًا على التحديث الجديد خلال ثوانٍ من فتح الموقع ويقوم بتحديث نفسه في الخلفية، لأننا جهزنا إعدادات الكاش في `firebase.json` بحيث `index.html` و `version.json` لا يتم تخزينهما مؤقتًا (`no-cache, no-store`).

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
