# دليل إدارة البيئات والنشر السحابي (Staging vs Production)
> **EduSaaS Multi-Tenant Cloud Environments & Release Engineering Runbook**  
> توثيق شامل للبيئتين، الربط السحابي، ودورة حياة رفع التعديلات (من التجارب إلى الإنتاج).

---

## 1. خريطة البيئات السحابية (Environments Architecture)

تم فصل المنصة سحابياً إلى بيئتين مستقلتين تماماً على مستوى الاستضافة (Firebase Hosting) وقاعدة البيانات (Supabase Multi-Tenancy):

```
                                  ┌───────────────────────────────────────────────┐
                                  │             Google Firebase Hosting           │
                                  └──────────────────────┬────────────────────────┘
                                                         │
                        ┌────────────────────────────────┴───────────────────────────────┐
                        ▼                                                                ▼
         [بيئة التجارب - STAGING]                                         [بيئة الإنتاج - PRODUCTION]
         Site: antounios-test                                            Site: antounios
         URL: https://antounios-test.web.app                             URL: https://antounios.edsentre.com
         Hostinger DNS: غير مرتبط بالدومين الرسمي                         Hostinger CNAME: antounios -> antounios.web.app
         Database Tenant: Sandbox Demo (11111111-...)                     Database Tenant: Dr. Antounios (ea5caf8b-...)
         الهدف: تجربة التعديلات والامتحانات بأمان                         الهدف: المنصة الحقيقية المستقرة للمدرس وطلابه
```

---

## 2. جدول مقارنة تفصيلي بين البيئتين

| وجه المقارنة | 🧪 بيئة التجارب (Testing / Staging) | 🎓 بيئة الإنتاج الرسمية (Production) |
|---|---|---|
| **الرابط المباشر (URL)** | `https://antounios-test.web.app` | `https://antounios.edsentre.com` |
| **اسم الموقع على Firebase** | `antounios-test` | `antounios` |
| **الهدف في `firebase.json`** | `hosting:test` | `hosting:prod` |
| **الربط مع Hostinger** | سيرفر سحابي مباشر على نطاق Google | دومين خاص مرتبط عبر سجل CNAME رسمي |
| **المستأجر في قاعدة البيانات** | `11111111-1111-1111-1111-111111111111` | `ea5caf8b-112f-4044-b9ad-798d5ab025c3` |
| **اسم الأكاديمية في الواجهة** | `Elite American Math Academy` | `منصة د. أنطونيوس أشرف` |
| **المستخدمون والبيانات** | حسابات تجريبية، طلاب وهميون للتجربة | د. أنطونيوس أشرف (`antounios@edsentre.com`) + طلابه الحقيقيون فقط |
| **حالة البيانات** | بيانات ديناميكية للتجارب والحذف | نظيفة 100% (Clean Slate) - لا بيانات تجريبية |

---

## 3. دورة حياة رفع التعديلات (Deployment Lifecycle)

> ⚠️ **قاعدة ذهبية:** لا يتم رفع أي تعديل إلى بيئة الإنتاج (`prod`) مباشرة أبداً. التعديلات تتبع دائماً المسار المكون من 4 خطوات:

```
[1. التعديل البرمجي] ──> [2. الفحص والبناء] ──> [3. النشر على Staging والفحص الحي] ──> [4. النشر على Production]
```

### الخطوة 1: إجراء التعديل البرمجي والتأكد من الجودة
بعد إجراء أي تعديلات في الكود المصدري، نقوم بالتحقق الآلي من الكود وخلوه من أي أخطاء:
```bash
flutter analyze
flutter test
```

### الخطوة 2: بناء حزمة الويب للإنتاج (Production Web Bundle)
```bash
flutter build web --release
```

### الخطوة 3: الرفع أولاً على بيئة التجارب (Testing)
نقوم برفع النسخة الجديدة إلى سيرفر التجارب فقط دون لمس المنصة الحقيقية:
```bash
npx firebase-tools deploy --only hosting:test
```
* **رابط المعاينة والتجربة:** `https://antounios-test.web.app`
* **إجراءات التحقق:**
  1. فتح الرابط وتجربة الشاشات أو الميزات الجديدة.
  2. تسجيل الدخول بحساب تجريبي وفحص استجابة الواجهة.
  3. التأكد من عدم وجود أي أخطاء في الكونسول (Console Errors).

### الخطوة 4: الرفع النهائي على بيئة الإنتاج الرسمية (Production)
بمجرد التأكد من نجاح التجربة 100% ورضاك التام عن التعديل، يتم إطلاق التحديث رسمياً لدكتور أنطونيوس وطلابه:
```bash
npx firebase-tools deploy --only hosting:prod
```
* **الرابط الرسمي المباشر:** `https://antounios.edsentre.com`

---

## 4. إعدادات البنية التحتية المسجلة (Configuration Reference)

### أ) ملف `firebase.json` (التهيئة ثنائية الأهداف)
تم ضبط الاستضافة لدعم Target مستقل لكل بيئة مع قواعد الكاش والأمان نفسها:
```json
{
  "hosting": [
    {
      "target": "prod",
      "public": "build/web",
      "rewrites": [{ "source": "**", "destination": "/index.html" }]
    },
    {
      "target": "test",
      "public": "build/web",
      "rewrites": [{ "source": "**", "destination": "/index.html" }]
    }
  ]
}
```

### ب) ملف `.firebaserc` (ربط الأهداف بالمواقع)
```json
{
  "projects": {
    "default": "ed-sentre"
  },
  "targets": {
    "ed-sentre": {
      "hosting": {
        "prod": ["antounios"],
        "test": ["antounios-test"]
      }
    }
  }
}
```

### ج) إعدادات DNS في Hostinger لـ `edsentre.com`
| النوع (Type) | الاسم (Name) | المحتوى / القيمة (Points to) | TTL | الغرض |
|---|---|---|---|---|
| **CNAME** | `antounios` | `antounios.web.app` | `300` (أو 14400) | توجيه الزوار إلى سيرفر البروداكشن |
| **TXT** | `@` | `"hosting-site-edsentre"` | `14400` | إثبات ملكية الدومين لـ Google Firebase |

---

## 5. بيانات حساب د. أنطونيوس أشرف الرسمية (Production Credentials)

* **الرابط المباشر:** [https://antounios.edsentre.com](https://antounios.edsentre.com)
* **صفحة الدخول:** [https://antounios.edsentre.com/login](https://antounios.edsentre.com/login)
* **البريد الإلكتروني:** `antounios@edsentre.com`
* **كلمة المرور الافتراضية:** `teacher123`
* **رابط تسجيل الطلاب التلقائي:** [https://antounios.edsentre.com/register-student](https://antounios.edsentre.com/register-student)
  *(يقوم تلقائياً بربط أي طالب يسجل بحساب دكتور أنطونيوس حصرياً)*

---

## 6. جدول الأوامر السريعة (Quick Command Cheat-Sheet)

| المهمة | الأمر البرمجي (في Terminal المشروع) |
|---|---|
| **فحص الكود والتحليل** | `flutter analyze` |
| **بناء التطبيق للويب** | `flutter build web --release` |
| **النشر على موقع التجارب (Test)** | `npx firebase-tools deploy --only hosting:test` |
| **النشر على موقع الإنتاج (Prod)** | `npx firebase-tools deploy --only hosting:prod` |
| **النشر على البيئتين معاً** | `npx firebase-tools deploy --only hosting` |
| **حفظ التغييرات في Git** | `git add . ; git commit -m "feat: your message" ; git push origin main` |
