# FLUTTER_RULES.md — الدليل المرجعي لمعايير فلاتر والأمان المؤسسي (Flutter Enterprise & Security Standard)
## منصة SaaS التعليمية White-Label (V1)

> هذا الملف يحدد المعايير المعمارية والأمنية الإلزامية لبناء تطبيقات فلاتر بمستوى إنتاجي رفيع (Production-Grade). يهدف إلى تحقيق أقصى درجات الأمان ضد الاختراقات وفق إرشادات **OWASP Mobile Application Security (MASVS)**، مع ضمان أداء 60/120 FPS بدون أي تسريب للذاكرة (Zero Memory Leaks).

---

## 1. الأمان المؤسسي الصارم (OWASP Mobile Security Compliance)

### أ) تخزين البيانات الحساسة وإدارة التوكنات (Secure Credential Storage)
- **المبدأ:** ممنوع قطعياً تخزين أي رمز مصادقة (Access Token / Refresh Token) أو بيانات مستخدم شخصية (PII) في `SharedPreferences` أو على هيئة نصوص عادية.
- **التنفيذ الإلزامي:**
  - يتم تخزين جميع التوكنات حصراً عبر `FlutterSecureStorage`.
  - على Android: تفعيل تشفير المفاتيح عبر Hardware-backed Android Keystore:
    ```dart
    AndroidOptions _getAndroidOptions() => const AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    );
    ```
  - على iOS: ضبط خيار الـ Keychain ليشترط فتح الجهاز للوصول للتوكن:
    ```dart
    IOSOptions _getIOSOptions() => const IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    );
    ```
- **حذف البيانات عند الخروج (Secure Purge):**
  عند تسجيل الخروج (`logout`)، يتم تفريغ الـ Secure Storage ومسح أي كاش في الذاكرة لمنع تسريب الجلسات السابقة.

### ب) أمان الشبكة والاتصالات (Network & Transport Security)
1. **قفل قنوات الاتصال المكشوفة (No Cleartext Traffic):**
   - يمنع استخدام بروتوكول `http://` في جميع البيئات (HTTPS حصراً).
   - في Android: ضبط `android:usesCleartextTraffic="false"` في `AndroidManifest.xml`.
2. **المعالج المتزامن لتجديد التوكنات (Token Refresh Mutex):**
   - لتفادي حدوث Race Conditions عند انتهاء التوكن وطلب 5 مكالمات API في نفس اللحظة: يجب أن يحتوي Network Interceptor على قفل (Mutex/Completer) بحيث يتم استدعاء تجديد التوكن مرة واحدة فقط، وتنتظر باقي الطلبات التوكن الجديد.
3. **عدم تسجيل البيانات الحساسة (No Sensitive Logging in Production):**
   - يمنع استخدام `print()` في أي مكان في المشروع.
   - استخدام مسجل أمني لا يطبع الـ Headers أو الـ Tokens أو البيانات الحساسة، ويُعطل الطباعة بالكامل في وضع الإنتاج (`kReleaseMode`).

### ج) حماية الكود المصدري والهندسة العكسية (Code Obfuscation & Binary Hardening)
- عند بناء الحزم الإنتاجية (Release Builds) للعميل أو المتجر، يجب إلزامياً تفعيل إخفاء معالم الكود وعزل معلومات التنقيح:
  ```bash
  flutter build appbundle --obfuscate --split-debug-info=./build/symbols
  flutter build web --release
  ```

### د) قاعدة العميل غير الموثوق (Untrusted Client Doctrine)
- فلاتر هو مجرد واجهة عرض (Display Layer).
- أي فحص للصلاحيات (`isTeacher`, `isApproved`, `isAdmin`) يتم داخل الـ UI هو لأغراض تحسين تجربة المستخدم فقط (UX Convenience).
- **السلطة الحقيقية للأمان تعود حصراً لقاعدة البيانات عبر RLS والـ Edge Functions.** لا يتم حساب درجات الامتحانات، أو اعتماد الطلاب، أو تفويض تشغيل الفيديو من كود فلاتر نهائياً.

---

## 2. معمارية الواجهة النظيفة وإدارة الحالة (Cubit Enterprise Architecture)

### أ) فصل المسؤوليات الصارم (Layer Decoupling)
```text
┌─────────────────────────────────────────────────────────┐
│ Presentation Layer (Widgets / Pages)                     │
│ └── تعرض الواجهة فقط، تستمع لـ Cubit، ممنوع استدعاء API  │
├─────────────────────────────────────────────────────────┤
│ State Management (Cubit + States)                       │
│ └── تحول أحداث المستخدم إلى استدعاءات للمستودع وتغير الحالة │
├─────────────────────────────────────────────────────────┤
│ Domain Layer (Entities / Interface Contracts)           │
│ └── كود دارت نقي 100%، لا يعتمد على فلاتر أو أي Package │
├─────────────────────────────────────────────────────────┤
│ Data Layer (Models / DataSources / Repositories)        │
│ └── تتحدث مع Supabase / Dio / Storage وتحولها لـ Result │
└─────────────────────────────────────────────────────────┘
```

### ب) إعادة بناء الواجهة الذكية وعالية الأداء (Rebuild Optimization)
- **ممنوع إعادة بناء الصفحة كاملة:**
  استخدم `BlocSelector` أو `context.select` بدلاً من `BlocBuilder` العام متى ما كان الغرض تحديث جزء صغير من الواجهة (مثل زر، أو عداد).
  ```dart
  // ✅ إعادة بناء الزر فقط عند تغير حالة التحميل
  final isLoading = context.select<AuthCubit, bool>((cubit) => cubit.state is AuthLoading);
  ```
- **حفظ الشجرة عبر `const`:**
  كل Widget ثابتة يجب أن تُسبق بـ `const` لتمكين المحرك من إعادة استخدامها وتفادي إعادة رسمها في الذاكرة.

---

## 3. دورة حياة المكونات ومنع تسريب الذاكرة (Memory Management & Zero Leaks)

1. **قاعدة الـ `dispose` الإلزامية:**
   كل متحكم أو مستمع يتم إنشاؤه في `StatefulWidget` يجب إغلاقه بدون استثناء في `dispose()`:
   - `TextEditingController`
   - `ScrollController`
   - `AnimationController`
   - `FocusNode`
   - `StreamSubscription`
2. **سلامة السياق بعد العمليات غير المتزامنة (`context.mounted`):**
   - بعد أي `await`، ممنوع استخدام `context` (للتنقل أو عرض SnackBar أو قراءة Theme) دون فحص:
   ```dart
   final result = await context.read<AuthCubit>().login(email, password);
   if (!context.mounted) return;
   context.go(AppRouter.dashboard);
   ```

---

## 4. نظام التصميم والواجهات القياسية (Design System Excellence)

1. **الحالات الأربع الإلزامية في كل شاشة تجلب بيانات:**
   - **Loading:** هياكل عظمية متناسقة (Skeletons) تُشعر المستخدم بسرعة الاستجابة، وليس مجرد دائرة تحميل وحيدة في منتصف الشاشة.
   - **Empty:** أيقونة دلالية ورسالة واضحة تحفز المستخدم على الإجراء التالي.
   - **Error:** رسالة واضحة مع زر إعادة المحاولة (`Retry`) وإمكانية الإبلاغ التلقائي عن الخطأ.
   - **Success / Loaded:** عرض المحتوى بسلاسة وتناسق.
2. **منع الألوان والقياسات المباشرة (Zero Hard-coded Values):**
   - ممنوع كتابة `Color(0xFF...)` داخل أي Widget. كل لون يُؤخذ حصراً من `AppColors` أو `Theme.of(context).colorScheme`.
   - ممنوع أرقام المسافات العشوائية. كل مسافة تُؤخذ من `AppSpacing`.
3. **سهولة الوصول والتباين (Accessibility & High Contrast):**
   - مراعاة نسبة تباين لا تقل عن **4.5:1** بين النصوص والخلفيات حسب معايير WCAG AA.
   - مراعاة دعم قراء الشاشة والأحجام التلقائية للنصوص دون كسر الواجهة (`Overflow`).
4. **تعدد اللغات واتجاه العرض (RTL/LTR):**
   - جميع الواجهات تدعم العربية والإنجليزية بالتساوي من أول شاشة، وممنوع استخدام أي نص ثابت باليد داخل الـ Widgets.

---

## 5. مصفوفة التدقيق السريع للواجهات قبل الاعتماد (Flutter Pre-Commit Checklist)
- [ ] هل تم فحص `context.mounted` بعد كل `await`؟
- [ ] هل جميع الـ Controllers ملغاة بـ `dispose()`؟
- [ ] هل تم التحقق من عدم وجود أي `print()` مكشوف؟
- [ ] هل الشاشة تدعم الحالات الأربع (`Loading`, `Empty`, `Error`, `Loaded`)؟
- [ ] هل الواجهة منضبطة بـ RTL والـ Tokens الخاصة بالتصميم؟
- [ ] هل تم تجنب تكرار رسم الشاشات بالكامل باستخدام `BlocSelector`؟
