# DART_RULES.md — الدليل المرجعي الصارم لمعايير لغة Dart (Dart 3.x Enterprise Standard)
## منصة SaaS التعليمية White-Label (V1)

> هذا الملف هو الدستور البرمجي للغة Dart في المشروع. صُمم وفق أحدث مواصفات **Dart 3.8+** الرسمية، بهدف بناء كود على أعلى معايير الشركات العالمية (Google, Stripe, Uber)، خالي تماماً من الأخطاء العشوائية، محصن ضد Null-safety issues، وقابل للعرض في أقوى المقابلات التقنية لشركات الـ Big Tech.

---

## 1. ميزات Dart 3.x الحديثة (إلزامية في كل سطر كود)

### أ) الفئات المحكمة (Sealed Classes) لتمثيل الحالات والنتائج
**المبدأ:** ممنوع استخدام الوراثة المفتوحة للحالات (States) أو النتائج (Results). يجب استخدام `sealed class` لتمكين التحقق الشامل وقت التصريف (Exhaustive Compile-time Checking).

```dart
// ✅ الطريقة المعتمدة لتمثيل النتائج (Functional Result Pattern)
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is FailureResult<T>;

  R when<R>({
    required R Function(T data) onSuccess,
    required R Function(Failure failure) onFailure,
  }) => switch (this) {
    Success(:final data) => onSuccess(data),
    FailureResult(:final failure) => onFailure(failure),
  };
}

final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

final class FailureResult<T> extends Result<T> {
  final Failure failure;
  const FailureResult(this.failure);
}
```

### ب) تعبيرات Switch ونمط المطابقة (Pattern Matching & Switch Expressions)
**المبدأ:** استخدم `switch` كتعبير (Expression) يُرجع قيمة مباشرة دون الحاجة لـ `break` أو متغيرات مؤقتة قابلة للتغيير (`var` mutable).

```dart
// ✅ استخدام التعبير الشامل (Exhaustive Switch Expression)
final statusColor = switch (state) {
  AuthStateLoading() => AppColors.primaryLight,
  AuthStateAuthenticated(:final user) when user.isActive => AppColors.success,
  AuthStateAuthenticated() => AppColors.warning,
  AuthStateUnauthenticated() || AuthStateError() => AppColors.error,
};

// ❌ ممنوع: استخدام if-else المتداخلة أو switch الكلاسيكية مع break
```

### ج) السجلات ومخرجات التوابع المتعددة (Records & Multiple Returns)
**المبدأ:** لا تنشئ فئة جديدة (Class) فقط لتمرير قيمتين معاً لمرة واحدة. استخدم `Records` المطبوعة بنوع صارم.

```dart
// ✅ إرجاع زوج قيم بأسماء واضحة وبدون كلاس وهمي
({int totalQuestions, int correctAnswers, double scorePercent}) calculateScore(Exam exam) {
  // منطق الحساب...
  return (totalQuestions: 20, correctAnswers: 18, scorePercent: 90.0);
}

// تفكيك السجل (Destructuring) عند الاستلام
final (:totalQuestions, :scorePercent, correctAnswers: _) = calculateScore(exam);
```

### د) معدّلات الفئات (Class Modifiers) لضبط عقود التصميم
- `sealed`: للهياكل محددة الأطراف (States / Results / Events).
- `final`: لأي كلاس لا يجب وراثته (Entities, DTOs, Value Objects).
- `interface`: لأي عقد (Repository Contract) يُسمح فقط بتنفيذه (`implements`) ويُمنع وراثته (`extends`).
- `base`: عند الحاجة لبناء وراثة تلزم المشتقات بالحفاظ على سلوك الفئة الأساسية.

---

## 2. سلامة الأنواع والصرامة (Sound Type System & Null Safety)

1. **ممنوع الـ `dynamic` و `Object?`:**
   - أي استخدام لـ `dynamic` يعتبر فشل في مراجعة الكود (Code Review Failure).
   - استبدله دائماً بـ Generics المحددة بدقة `<T>`, `<T extends Equatable>`.
2. **قاعدة الـ Bang Operator (`!`):**
   - يُحظر استخدام `!` (Force Unwrap) إلا في حالة واحدة: بعد فحص صريح داخل نفس الدالة أو عبر `assert` واضح، والأفضل استخدام مطابقة الأنماط (Pattern Matching):
   ```dart
   // ✅ الطريقة الآمنة
   if (nullableUser case final user?) {
     user.displayName; // مضمون غير null
   }
   ```
3. **الثبات المطلق (Immutability):**
   - جميع حقول الكلاسات (`final`) بدون استثناء.
   - جميع المنشئات (`const`) حيثما أمكن لتمكين المحرك من حفظها في الـ Canonical Memory.
   - تعديل الكائنات يتم حصراً عبر دوال `copyWith`.

---

## 3. المعالجة الاحترافية للأخطاء والاستثناءات (Defensive Engineering)

1. **الطبقات التحتية (DataSources):**
   - تحول استثناءات السيرفر أو الشبكة إلى فئات `Failure` محددة ولا تترك استثناءات عشوائية تتسرب.
2. **طبقة المستودعات (Repositories):**
   - تعيد دائماً `Future<Result<T>>` أو `Result<T>` ولا ترمي `throw` إلى الـ Cubit.
3. **الحماية من الـ Silenced Exceptions:**
   - ممنوع إطلاقاً استخدام `catch (e) {}` فارغ. أي خطأ يُلتقط يجب تسجيله ومعالجته أو تمريره كـ `Failure`.

---

## 4. الذاكرة والعمليات غير المتزامنة (Async & Concurrency)

1. **Unawaited Futures:**
   - أي عملية `Future` لا يُنتظر اكتمالها عمداً يجب تغليفها بـ `unawaited(myAsyncOperation());` لتوثيق القصد وتفادي تحذيرات المحلل.
2. **عزل العمليات الثقيلة (Isolates & `compute`):**
   - أي عملية حسابية معقدة (مثل فك تشفير كمية ضخمة من JSON أو معالجة صور وملفات) يجب أن تُنفذ خارج الـ Main Thread باستخدام `compute()` أو `Isolate.run()` لمنع سقوط الـ FPS.
3. **إلغاء الاشتراكات (StreamSubscriptions):**
   - أي `StreamSubscription` يُفتح يجب حفظه وإلغاؤه فوراً في دالة `close()` أو `dispose()`.

---

## 5. مصفوفة التدقيق السريع قبل الاعتماد (Dart Pre-Commit Checklist)
- [ ] هل جميع الملفات تُكتب بـ `snake_case` والكلاسات بـ `PascalCase`؟
- [ ] هل تم فحص الكود بـ `dart analyze` الصارم ولم يظهر أي تحذير؟
- [ ] هل جميع الكلاسات غير القابلة للوراثة معرّفة بـ `final` أو `sealed`؟
- [ ] هل تم تجنب الـ `dynamic` والـ Force unwrap `!`؟
- [ ] هل تم تطبيق `const` على جميع الـ Constructors الممكنة؟
