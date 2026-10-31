# دليل الصمود الشبكي وتجميع الويب الفائق (Network Resilience & Web Architecture Playbook)
> **EduSaaS Production Standard · وثيقة مستخلصة من الدروس المستفادة والأخطاء التشغيلية الواقعية**  
> المرجع الهندسي الإلزامي لمنع أخطاء `TypeError: Failed to fetch`، و`AuthRetryableFetchException`، وانهيار الواجهات بالخطأ الوهمي `SRV_500`.

---

## 1. جذر المشكلات الواقعية (Root Cause Case Study)

### أ) خطأ التقطيع المفرط (Micro-Chunk Deferred Over-Splitting)
- **ماذا حدث سابقاً؟**  
  تم تقسيم أكثر من 45 شاشة عبر `deferred as` و `DeferredWidget`. بالتزامن مع ترويسة كاش `no-store` لجميع ملفات الـ JS، أصبح كل انتقال بين الشاشات يستلزم طلباً خارجياً من السيرفر لجلب ملف `.part.js`.
- **لماذا انهار التطبيق؟**  
  في شبكات الإنترنت في مصر والمناطق ذات تذبذب الحزم (Packet Jitter / High Latency)، يؤدي تأخر بسيط (300ms) في الـ DNS أو الشبكة إلى رمي المتصفح لاستثناء `TypeError: Failed to fetch`، فتنهار الشاشة فوراً ويظهر الخطأ الأحمر قبل رسم شريط العنوان.
- **الحل المعتمد نهائياً (Canonical Standard):**  
  **Coarse-Grained In-Memory Role Bundling:**  
  جميع شاشات التنقل الأساسية لأدوار المستخدمين (Teacher, Student, Parent) تُدمج في الذاكرة الحية (RAM) مباشرة في ملف التوجيه [`app_router.dart`](file:///c:/Users/KimoStore/StudioProjects/edu_saas/lib/core/router/app_router.dart).  
  الانتقال بين الشاشات أصبح $O(1)$ مع **صفر طلبات شبكة خارجية لتحميل كود الشاشات**.

---

## 2. النمط المضاد: إعادة التحميل التدميرية (Destructive Mutation Reload Anti-Pattern)

### أ) المشكلة
عند قيام المستخدم بعملية (مثل إسناد مجموعة لطالب، تبديل حالة، تفعيل حساب):
1. الكود القديم يرسل الطلب للسيرفر وينجح.
2. ثم يقوم الـ Cubit بمسح الشاشة المحملة وإطلاق `emit(const StudentsLoading())`.
3. ثم يطلق 3 استعلامات ثقيلة متوازية عبر `Future.wait`.
4. إذا تعثر أي استعلام منها بسبب تذبذب الشبكة، يُطلق `emit(StudentsError(...))` فتتحول الشاشة إلى شاشة خطأ حمراء كاملة (`SRV_500`).
5. المستخدم يظن أن العملية فشلت، فيضغط "إعادة التحميل"، فيتفاجأ أن العملية تمت بنجاح في قاعدة البيانات!

### ب) القاعدة الذهبية الإلزامية: التحديث التفاؤلي الصامت (Optimistic Local State Update)
1. **لا تمسح شاشة محملة أبداً بعد عملية:**  
   ممنوع منعاً باتاً استدعاء `emit(LoadingState())` أو إعادة جلب الصفحة كاملة بعد إجراء عملية على شاشة معروضة بالفعل.
2. **تحديث الذاكرة فوراً ($O(1)$):**  
   يتم تعديل الحالة الحالية في الذاكرة فوراً وإطلاق الحالة الجديدة (`LoadedState`) قبل أو بالتزامن مع طلب الشبكة لمنح المستخدم سرعة 0ms lag.
3. **تنظيف الكاش صامتاً:**  
   يتم مسح الكاشات المعنية (`AppCache.students.clear()`) دون إعادة رسم الشاشة.
4. **التراجع الصامت عند الفشل (Graceful Rollback):**  
   إذا فشل طلب الشبكة بعد استنفاد محاولات إعادة المحاولة:
   - يتم التراجع عن التعديل في الذاكرة بإعادة الحالة السابقة (`emit(previousState)`).
   - إظهار رسالة خطأ منبثقة غير تدميرية (`AppFeedback.showError(context, ...)` / Snackbar).
   - الشاشة تظل مفتوحة ومحتفظة ببياناتها دون أي شاشة خطأ حمراء تدميرية.

---

## 3. التحصين الشبكي عبر `retryTransient`

- **كل العمليات القابلة للتكرار (Idempotent Mutations) والاستعلامات:**  
  يجب أن تُغلَّف بـ `retryTransient` في طبقة الـ `Repository`:
  ```dart
  await retryTransient(
    () => _remoteDataSource.assignStudentToGroup(
      studentId: studentId,
      groupId: groupId,
      add: add,
    ),
  );
  ```
- يتعامل `retryTransient` تلقائياً مع:
  - انقطاع الاتصال المؤقت (`SocketException`, `ClientException: Failed to fetch`).
  - أخطاء السيرفر العابرة (502 Bad Gateway, 503 Service Unavailable).
  - تذبذب شبكات المحمول المصرية وسقوط حزم البيانات المؤقت.

---

## 4. إعدادات الكاش الفائق على الاستضافة (`firebase.json` و Cloudflare)

| نوع الملف | ترويسة الكاش (Cache-Control) | الهدف والسبب |
|---|---|---|
| `index.html` & `flutter_bootstrap.js` | `no-cache, no-store, must-revalidate, max-age=0` | تحميل أحدث إصدار منشور فوراً دون بقاء أي نسخة قديمة معلقة للمستخدم. |
| `main.dart.js` & `*.wasm` | `public, max-age=3600, stale-while-revalidate=86400` | المتصفح يحفظ كود التطبيق في الذاكرة والكاش ولا يُعيد تنزيله مع كل نقرة. |
| بصمة الإصدار (Cache-Busting) | `main.dart.js?v=<build_timestamp>` | يضمن تنزيل الكود الجديد تلقائياً مع كل Deploy جديد دون الحاجة لمسح كاش المتصفح. |
