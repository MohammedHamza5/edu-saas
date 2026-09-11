# 📱 الدليل الشامل لمهندس التجاوب وتعدد الشاشات (Responsive Master Playbook)
## منصة SaaS التعليمية White-Label (V1)

> **وثيقة مرجعية دائمة لمهندس الريسبونسف والـ UI/UX**  
> **الإصدار:** 1.0 · **التاريخ:** سبتمبر 2026  
> **الهدف:** توحيد وتطبيق معايير التجاوب الشامل (All-Device Responsiveness) لمنصة الويب وتطبيقات الموبايل عبر كل أحجام الشاشات (الهواتف الذكية بجميع أشكالها، الأجهزة اللوحية، الحواسيب المحمولة، والشاشات المكتبية والعملاقة 4K) بدقة هندسية وجمالية أكاديمية راقية.

---

## 🧭 فهرس المحتويات
1. [ميثاق المهمة ونطاق التخصص المباشر](#1-ميثاق-المهمة-ونطاق-التخصص-المباشر)
2. [الفهم المعماري الشامل للمشروع (Architecture & Design DNA)](#2-الفهم-المعماري-الشامل-للمشروع-architecture--design-dna)
3. [مصفوفة الأجهزة وفئات الشاشات المعتمدة (Breakpoints Matrix)](#3-مصفوفة-الأجهزة-وفئات-الشاشات-المعتمدة-breakpoints-matrix)
4. [هندسة التجاوب الأساسية (Responsive Architecture & Core Primitives)](#4-هندسة-التجاوب-الأساسية-responsive-architecture--core-primitives)
5. [أنماط التكيف للهياكل والتنقل (Adaptive Navigation & Layout Shells)](#5-أنماط-التكيف-للهياكل-والتنقل-adaptive-navigation--layout-shells)
6. [تدقيق الشاشات الحالية ونقاط القصور المرصودة (Current Screens Audit)](#6-تدقيق-الشاشات-الحالية-ونقاط-القصور-المرصودة-current-screens-audit)
7. [معايير التكيف للمكونات الدقيقة (Micro-Components Responsive Standards)](#7-معايير-التكيف-للمكونات-الدقيقة-micro-components-responsive-standards)
8. [التعامل مع الحالات الحرجة والحواف (Edge Cases & Device Quirks)](#8-التعامل-مع-الحالات-الحرجة-والحواف-edge-cases--device-quirks)
9. [خارطة طريق التنفيذ والتحسين التدريجي (Execution Roadmap)](#9-خارطة-طريق-التنفيذ-والتحسين-التدريجي-execution-roadmap)
10. [قائمة التحقق الإلزامية قبل الاعتماد (Responsive DoD Checklist)](#10-قائمة-التحقق-الإلزامية-قبل-الاعتماد-responsive-dod-checklist)

---

## 1. ميثاق المهمة ونطاق التخصص المباشر

### 🎯 الهدف المحوري
بصفتي المهندس المسؤول حصرياً عن **الريسبونسف وتجربة العرض عبر الأجهزة (Responsive & Cross-Device Specialist)**، فإن تركيزي الكامل مع المستخدم ينصب على:
- تحويل المنصة من مجرد واجهات تعمل على شاشة الموبايل الافتراضية إلى **تطبيق ويب وسحابي رائد متجاوب 100%**.
- جعل الموقع يظهر بمظهر المنصات العالمية (Stripe / Linear / Notion / Coursera) عند فتحه على شاشات اللابتوب والديسكتوب والشاشات فائقة العرض (Ultra-wide).
- تقديم تجربة استخدام طبيعية ومريحة وخالية من أي تشوهات أو تداخلات على الهواتف بجميع قياساتها (بدءاً من الشاشات الصغيرة جداً 320px وحتى الهواتف الكبيرة وذوات الشاشات القابلة للطي Foldables).
- دعم الأجهزة اللوحية (Tablets) في الوضعين: الأفقي (Landscape) والرأسي (Portrait) وتقسيم الشاشة (Split-Screen View).

### 🔒 الثوابت الصارمة لستاك المشروع (Zero-Bloat Rule)
1. **لا حزم خارجية إضافية للريسبونسف:** ممنوع إدخال مكتبات مثل `responsive_framework` أو `sizer` أو `screen_util` لتفادي كسر الستاك المقفول للمشروع وزيادة حجم الحزمة. سنعتمد 100% على قدرات فلاتر الأصلية النقية: `LayoutBuilder`, `MediaQuery`, `BoxConstraints`, `Flex`, `Wrap`, `CustomMultiChildLayout`.
2. **عدم المساس بالبنية الأمنية أو منطق الـ Cubit:** تخصصنا هو طبقة العرض والـ Presentation / UI فقط؛ لا تعديل في عقود الدوال أو سياسات RLS أو استدعاءات الـ Backend.
3. **دعم الاتجاهين (RTL & LTR) كأصل دستوري:** استخدام `EdgeInsetsDirectional` و `AlignmentDirectional` وعدم افتراض أي اتجاه يسار/يمين ثابت.
4. **الالتزام بنظام التوكنات (Design Tokens Only):** لا ألوان يدوية `Color(0xFF...)`، ولا هوامش عشوائية، بل استخدام `Theme.of(context).colorScheme` و `AppSpacing` و `AppTypography` و `MathTokens`.

---

## 2. الفهم المعماري الشامل للمشروع (Architecture & Design DNA)

### 📌 طبيعة المنتج
- **White-label Multi-Tenant Education SaaS:** منصة تعليمية مستقلة للمدرسين المتخصصين في النظام الأمريكي (SAT, EST, ACT, Basics, Advanced).
- **العزل المطلق (Multi-Tenancy):** كل مدرس يمثل Tenant معزول بالكامل برمجياً وأمنياً عبر Supabase RLS.
- **الأدوار الثلاثة المنفصلة:**
  1. **المعلم (Teacher):** لوحة تحكم وإدارة كاملة للمجموعات، الطلاب، كشوف الحضور، المحتوى والواجبات والامتحانات والإعلانات.
  2. **الطالب (Student):** بوابة دراسية لتصفح المحتوى المصرح به، تسليم الواجبات، خوض الامتحانات الذرية، ومتابعة الحضور والدرجات.
  3. **ولي الأمر (Parent):** بوابة متابعة وقراءة فقط لتقارير وإحصائيات أبنائه المرتبطين به دون تفاصيل الحلول أو أوراق الامتحانات.

### 🎨 الهوية البصرية: "Modern Mathematical Academic SaaS"
- **الانطباع العام:** منصة أكاديمية هندسية رصينة وليست لوحة تحكم شركات جافة، وليست تطبيق أطفال كرتوني.
- **الألوان الأساسية:**
  - `AppColors.primary`: الأزرق الرياضي الهادئ Deep Indigo (`0xFF5B4FE0`).
  - `AppColors.background`: أوف وايت دافئ وناعم (`0xFFF8FAFC`).
  - `AppColors.surface`: أبيض ناصع (`0xFFFFFFFF`).
  - `AppColors.textPrimary`: كحلي فحمي داكن (`0xFF0F172A`).
  - `AppColors.textSecondary`: رمادي رصين متزن (`0xFF64748B`).
  - `AppColors.border`: حدود خفيفة واضحة (`0xFFE2E8F0`).
- **اللغة الرمزية (Math Tokens):** رموز هندسية ورياضية خافتة في الخلفيات والأيقونات (`∑`, `π`, `√x`, `f(x)`).
- **الأرقام كأبطال بصريين (Hero Metrics):** نسب مئوية بارزة (`85%`، `10 Students`، `18/20`) مستخدمة خطوطاً هندسية ثقيلة وأوزان واضحة.
- **الوضع الحالي:** `Light Theme` فقط في V1 (جاهز للتحول لـ Dark Mode مستقبلاً دون المساس بالـ Tokens).

---

## 3. مصفوفة الأجهزة وفئات الشاشات المعتمدة (Breakpoints Matrix)

لتغطية جميع الأجهزة بكفاءة متناهية، نعتمد تقسيم الشاشات القياسي التالي:

| فئة الشاشة (Device Class) | المدى العرضي (Width) | أمثلة الأجهزة المستهدفة | استراتيجية التخطيط والتنقل (Layout Strategy) |
|---|---|---|---|
| **Compact - Mobile Small** | `< 360px` | iPhone SE (1st gen), Galaxy A10s, هاتف مضغوط | عمود واحد، تصغير الهوامش إلى `s12`، عناصر مكدسة رأسياً، استبدال الصفوف الضيقة بقوائم. |
| **Compact - Mobile Standard** | `360px - 599px` | iPhone 12..16, Samsung Galaxy S21..S24, Pixel | عمود رئيسي واحد، `BottomNavigationBar` أو شريط سفلي متكيف، بطاقات كاملة العرض مع هوامش `s16`، `ModalBottomSheet` للخيارات. |
| **Medium - Tablet / Foldable** | `600px - 839px` | iPad Mini, Galaxy Fold (مفتوح), تابلت رأسي | شبكة من عمودين (2-Column Grid)، `NavigationRail` جانبي مدمج (Icons only)، حوارات منبثقة ذات حجم متوسط. |
| **Expanded - Desktop / Laptop** | `840px - 1199px` | iPad Pro أفقي، لابتوب 13 بوصة، أجهزة Surface | شريط تنقل جانبي موسع مع عناوين (`NavigationRail` مع تسميات)، شبكة 2-3 أعمدة، هوامش `s24`، حاويات محددة الحجم. |
| **Large - Desktop Standard** | `1200px - 1599px` | شاشات الحواسيب المكتبية 1080p، لابتوب 15-16 بوصة | `Permanent Sidebar` ثابت، شبكة 3-4 أعمدة، لوحات رئيسية وتقسيم Master-Detail، أقصى عرض للمحتوى `1280px` في المنتصف. |
| **Extra Large - 4K / Ultrawide**| `≥ 1600px` | شاشات العرض 2K/4K، الشاشات العريضة 21:9 | تحديد أقصى عرض للمحتوى بـ `1440px` أو `1600px` مع توسيط تلقائي (`Center`) لمنع تشتت العين والامتداد غير المريح للنصوص. |

---

## 4. هندسة التجاوب الأساسية (Responsive Architecture & Core Primitives)

لتحقيق الكود الأنظف والأكثر استدامة، سنقوم ببناء أدوات أساسية داخل `lib/core/` تدعم المشروع بالكامل دون تكرار:

### أ) أداة تعريف الفئات `DeviceScreenType`
```dart
enum DeviceScreenType {
  compactMobile,    // < 600
  mediumTablet,     // 600 - 839
  expandedDesktop,  // 840 - 1199
  largeDesktop,     // >= 1200
}
```

### ب) ملحقات السياق السريعة (Context Extensions)
إتاحة دوال مساعدة سهلة الاستخدام داخل أي `Widget`:
```dart
extension ResponsiveContextX on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  Orientation get orientation => MediaQuery.orientationOf(this);

  bool get isMobile => screenWidth < 600;
  bool get isTablet => screenWidth >= 600 && screenWidth < 840;
  bool get isDesktop => screenWidth >= 840;
  bool get isLargeDesktop => screenWidth >= 1200;

  // إرجاع قيمة متكيفة حسب الشاشة بسهولة
  T responsiveValue<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop && desktop != null) return desktop;
    if (isTablet && tablet != null) return tablet;
    return mobile;
  }
}
```

### ج) أداة البناء المتجاوبة `ResponsiveBuilder`
تسمح بفصل بناء الواجهة بدقة عند اختلاف التصميم الجوهري بين الموبايل والتابلت والديسكتوب:
```dart
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, BoxConstraints constraints) mobile;
  final Widget Function(BuildContext context, BoxConstraints constraints)? tablet;
  final Widget Function(BuildContext context, BoxConstraints constraints)? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 840 && desktop != null) {
          return desktop!(context, constraints);
        }
        if (constraints.maxWidth >= 600 && tablet != null) {
          return tablet!(context, constraints);
        }
        return mobile(context, constraints);
      },
    );
  }
}
```

### د) حاوية المحتوى المقيدة والموسّطة `ResponsiveContainer`
تمنع تمدد الشاشات والبطاقات والحقول بشكل قبيح على المتصفح والديسكتوب:
```dart
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 1200.0,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}
```

---

## 5. أنماط التكيف للهياكل والتنقل (Adaptive Navigation & Layout Shells)

واحدة من أهم نقاط القوة للمنصات الكبرى هي تكيف نمط التنقل (Navigation) تلقائياً مع حجم الجهاز:

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Mobile (< 600px):                                        │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ AppBar (Title + Notifications + Profile)                │ │
│ ├─────────────────────────────────────────────────────────┤ │
│ │                                                         │ │
│ │ Body Content (Single Column Scrollable)                 │ │
│ │                                                         │ │
│ ├─────────────────────────────────────────────────────────┤ │
│ │ BottomNavigationBar (3-4 Core Actions)                  │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ 2. Tablet (600px - 839px):                                  │
│ ┌──────┬──────────────────────────────────────────────────┐ │
│ │ Rail │ AppBar / Top Bar                                 │ │
│ │ (🗂) │──────────────────────────────────────────────────│ │
│ │ (👥) │ Body Content (2-Column Grid / Master View)       │ │
│ │ (📊) │                                                  │ │
│ └──────┴──────────────────────────────────────────────────┘ │
│                                                             │
│ 3. Desktop / Laptop (>= 840px):                             │
│ ┌──────────────┬──────────────────────────────────────────┐ │
│ │ Full Sidebar │ Header Bar (Search + Tenant Info + Bell) │ │
│ │ ┌──────────┐ │──────────────────────────────────────────│ │
│ │ │ Edu SaaS │ │ [Responsive Container: Max Width 1280px] │ │
│ │ ├──────────┤ │                                          │ │
│ │ │ 🗂 Groups │ │ ┌──────────┐ ┌──────────┐ ┌──────────┐   │ │
│ │ │ 👥 Pupils │ │ │ StatCard │ │ StatCard │ │ StatCard │   │ │
│ │ │ 📝 Exams │ │ └──────────┘ └──────────┘ └──────────┘   │ │
│ │ │ 📈 Stats │ │ ┌───────────────────┐ ┌──────────────┐   │ │
│ │ └──────────┘ │ │ Main Data Table   │ │ Activity Log │   │ │
│ └──────────────┴─┴───────────────────┴─┴──────────────┴───┘ │
└─────────────────────────────────────────────────────────────┘
```

### قواعد تحول التنقل:
1. **الموبايل (< 600px):** `BottomNavigationBar` أو قائمة منسدلة سريعة؛ تفريغ الشاشة للمحتوى.
2. **التابلت (600px - 839px):** `NavigationRail` أنيق ومدمج بأيقونات فقط وتلميحات (Tooltips).
3. **الديسكتوب واللابتوب (≥ 840px):** `Permanent NavigationDrawer / Sidebar` يضم شعار المنصة، الروابط مع نصوصها، ومعلومات المعلم الحالية، وزر الخروج بوضوح.

---

## 6. تدقيق الشاشات الحالية ونقاط القصور المرصودة (Current Screens Audit)

قمنا بفحص صفحات التطبيق المبنية حالياً، ورصدنا بدقة التحسينات المطلوبة لجعلها ريسبونسف بالكامل:

### 1) شاشات الدخول والمصادقة (`LoginPage`, `RegisterStudentPage`, `TenantSuspendedPage`)
- **الوضع الحالي:** تم استخدام `ConstrainedBox(maxWidth: 420)` في صفحة الدخول، وهو أمر ممتاز.
- **فرص التحسين الريسبونسف:**
  - على شاشات الديسكتوب الواسعة: يمكن تحويل صفحة الدخول إلى تصميم جانبي متطور (Split-Screen Layout): نصف الشاشة الأيمن يحتوي كارت الدخول، والنصف الأيسر يحتوي رسماً هندسياً أكاديمياً مع شعار المنصة وإحصائيات تحفيزية.
  - على الموبايل الصغير عند فتح لوحة المفاتيح: تفادي أي `RenderFlex overflow` عبر فحص `viewInsets` وتوسيد الحركة.

### 2) لوحة تحكم المعلم (`TeacherDashboardPage - T-01`)
- **الوضع الحالي:**
  - كروت الإحصائيات موضوعة داخل `Row` مقسوم بـ `Expanded`. على الشاشات فائقة الصغر (< 340px) قد يحدث ضيق نصوص.
  - على شاشات الديسكتوب (1920px): الكروت تمتد أفقياً بكامل عرض الشاشة مما يترك مساحات بيضاء هائلة وفارغة داخل الكارت.
- **الحل الريسبونسف المطلوب:**
  - تغليف المحتوى داخل `ResponsiveContainer(maxWidth: 1200)`.
  - تحويل كروت الإحصائيات وكروت الإجراءات إلى `ResponsiveGrid`:
    - الموبايل: عمود واحد أو عمودين مضغوطين.
    - التابلت: عمودان متزنان.
    - الديسكتوب: 3 أو 4 أعمدة رشيقة تعرض نظرة بانورامية شاملة.

### 3) قائمة وتفاصيل المجموعات (`GroupsListPage - T-06` & `GroupDetailPage - T-07`)
- **الوضع الحالي:** `ListView` رأسي مفرد يمتد بكامل العرض على المتصفح.
- **الحل الريسبونسف المطلوب:**
  - الموبايل: استمرار الـ `ListView` الفردي مع بطاقات مريحة للمس.
  - التابلت والديسكتوب: التحول إلى `GridView` شبكي (2 إلى 3 كروت في الصف) يظهر اسم المجموعة، مستوى المنهج، عدد الطلاب، وشارة سياسة المحتوى السابق بشكل يشبه كروت Google Classroom أو Notion.

### 4) كشف رصد الحضور (`TeacherAttendancePage - T-18`)
- **الوضع الحالي:**
  - الـ Header العلوي يحتوي `Row` به قائمة اختيار المجموعة وزر اختيار التاريخ وحفظ الكشف. على الموبايل الصغير قد يتداخل الزران.
  - جدول/قائمة الطلاب مفردة رأسياً مع راديو خيارات الحضور.
- **الحل الريسبونسف المطلوب:**
  - على الموبايل: ترتيب الفلاتر بمرونة عبر `Wrap` أو تكديس ذكي عند ضيق العرض.
  - على الديسكتوب: عرض شاشة متقدمة ذات عمودين (Master-Detail): العمود الأيمن لاختيار المجموعة والتاريخ وإحصائيات الحضور، والعمود الأيسر كجدول عريض تفاعلي يتيح رصد درجات الطلاب وحالاتهم بضغطة زر أو اختصارات لوحة المفاتيح.

### 5) مركز الإشعارات وإرسال التنبيهات (`NotificationsCenterPage`, `SendAnnouncementPage`)
- **الوضع الحالي:** قائمة بطول الشاشة؛ نموذج إرسال الإعلان يمتد بكامل العرض.
- **الحل الريسبونسف المطلوب:**
  - تقييد نموذج الإعلان بحد أقصى `maxWidth: 720px` لراحة عين المعلم أثناء كتابة الرسائل الطويلة.
  - مركز الإشعارات: حاوية مقيدة في المنتصف `maxWidth: 800px` مع إتاحة خيارات الفرز الفوري.

---

## 7. معايير التكيف للمكونات الدقيقة (Micro-Components Responsive Standards)

### أ) الأزرار وحقول الإدخال (`AppButton` & `AppTextField`)
- **Touch Target:** الحد الأدنى للارتفاع على شاشات اللمس (Mobile/Tablet) هو `48dp` لمنع أخطاء الضغط (وفقاً لمعايير Accessibility WCAG).
- **الماوس والمؤشر:** إضافة `MouseRegion` وتفعيل `SystemMouseCursors.click` للأزرار والبطاقات التفاعلية لتعطي إحساس تطبيق الويب الحقيقي.
- **الأزرار العريضة مقابل المدمجة:**
  - على الموبايل: الأزرار الأساسية (Submit / Next) تأخذ كامل العرض `double.infinity` في أسفل الشاشة أو النموذج.
  - على الديسكتوب: الزر يكون بحجم محتواه مع حد أدنى (`minimumSize: Size(160, 44)`) ومحاذاة مناسبة (إلى اليمين في RTL أو اليسار في LTR).

### ب) النوافذ المنبثقة والخيارات (Dialogs vs BottomSheets)
- **قاعدة التكيف:**
  - على **الموبايل**: استخدام `showModalBottomSheet` مع `showDragHandle: true` وزوايا علوية مستديرة، لأنها الأسهل وصولاً لإبهام المستخدم.
  - على **التابلت والديسكتوب**: استخدام `showDialog` مع `AlertDialog` محدد العرض (`maxWidth: 500px`) في منتصف الشاشة.

### ج) الجداول والبيانات (Data Tables vs List Cards)
- **الموبايل:** تحويل الصفوف إلى بطاقات رأسية مكدسة (Stacked Cards) تظهر اسم الطالب، وحالته، والزر المتاح.
- **الديسكتوب:** استخدام جداول عريضة واضحة (`DataTable` أو صفوف مخصصة) مع ترويسات ثابتة، هوامش مرتبة، وأعمدة لفرز البيانات.

### د) مقياس الخطوط وتدرج النصوص (Typography Scaling)
- تجنب استخدام أحجام خطوط عملاقة ثابتة قد تسبب قطع الكلمات على الشاشات الصغيرة.
- النصوص الرياضية والأرقام الكبيرة (`AppTypography.statFigureLarge`) يجب ضبطها بحيث تقل درجتين على الهواتف الصغيرة (`fontSize: 28` بدلاً من `36`) لتفادي تجاوز مساحة الكارت.

---

## 8. التعامل مع الحالات الحرجة والحواف (Edge Cases & Device Quirks)

### 1) المساحات الآمنة والنتوءات (Safe Area & Notches)
- دعم الشاشات ذات النتوء العلوي (Notch / Dynamic Island) وأشرطة التمرير السفلية عبر استخدام `SafeArea` المنضبط وعدم تعطيله دون حاجة.
- مراعاة الـ `viewInsets.bottom` عند فتح لوحة المفاتيح الافتراضية لمنع إخفاء أزرار الحفظ والتسليم.

### 2) الوضع الأفقي للهواتف (Mobile Landscape)
- عند تدوير الهاتف بالعرض: الارتفاع يصبح ضيقاً جداً (< 400dp).
- **الحل الإلزامي:** جعل كل الشاشات قابلة للتمرير (`SingleChildScrollView` أو `ListView`)، مع تقليص الـ AppBars الكبيرة أو جعلها تتلاشى مع السكرول.

### 3) الشاشات فائقة العرض (Ultrawide & 4K Displays)
- **المشكلة:** يمتد النموذج أو الجدول لمسافة 2560px أو 3840px مما يجعل قراءة النصوص مستحيلة ومزعجة للعين.
- **الحل الإلزامي:** تغليف أي صفحة بـ `ResponsiveContainer` يمنع تجاوز المحتوى عريضاً أكثر من `1400px` مع بقاء الخلفية ممتدة بجمالية.

### 4) السحب والتمرير بالماوس على الويب (Web Desktop Scroll Behavior)
- تفعيل سلوك التمرير الطبيعي للويب (`ScrollBehavior` يدعم مؤشر الماوس وعجلة الماوس والسحب `PointerDeviceKind.mouse, touch, trackpad`).
- إضافة أشرطة تمرير أنيقة وخفيفة (`Scrollbar`) للقوائم الطويلة في الديسكتوب.

---

## 9. خارطة طريق التنفيذ والتحسين التدريجي (Execution Roadmap)

سنعمل معاً خطوة بخطوة بالترتيب المنطقي التالي:

```text
المرحلة 1: بناء وتجهيز أدوات الريسبونسف الأساسية في lib/core
  ├── lib/core/theme/responsive_breakpoints.dart (Breakpoints Matrix)
  ├── lib/core/extensions/responsive_context_extension.dart (Context Extensions)
  ├── lib/core/widgets/responsive_builder.dart (Layout Builder Helper)
  ├── lib/core/widgets/responsive_container.dart (Max-width & Centering Wrapper)
  └── lib/core/widgets/responsive_grid.dart (Dynamic Multi-column Grid)

المرحلة 2: هياكل التكيف والتنقل الموحد (Adaptive Shells)
  ├── AdaptiveNavigationScaffold (BottomBar على الموبايل ↔ NavigationRail على التابلت ↔ Sidebar على الديسكتوب)
  └── تكيف قوالب المعلم والطالب وولي الأمر

المرحلة 3: تجاوب الشاشات المكتملة حالياً (Current Pages Refactoring)
  ├── كروت ولوحة تحكم المعلم (Teacher Dashboard T-01)
  ├── قائمة وتفاصيل المجموعات (Groups T-06 & T-07)
  ├── كشف رصد الحضور التفاعلي (Teacher Attendance T-18)
  ├── مركز الإشعارات وإرسال الإعلانات (Notifications S-11 & T-21)
  └── شاشات الدخول والانتظار (Auth S-02, S-07, S-08)

المرحلة 4: تدقيق باقي الشاشات فور اكتمالها (Future Pages Alignment)
  ├── شاشات إدارة ومراجعة الطلاب (Students List & 360 Profile)
  ├── مشغل الفيديو المتكيف (Video Player مع نسب 16:9 واستجابة لحجم الشاشة)
  ├── واجهة أداء الامتحانات (Exam Taking مع مؤقت ثابت وعرض متجاوب للأسئلة)
  └── بوابة ولي الأمر ولوحة المتابعة

المرحلة 5: فحص الجودة والاختبارات الشاملة (Verification Matrix)
  ├── اختبارات Widget آلية على 5 أحجام شاشات مختلفة
  └── فحص Web Build وتشغيله الفعلي على دقات متعددة
```

---

## 10. قائمة التحقق الإلزامية قبل الاعتماد (Responsive DoD Checklist)

قبل اعتبار أي شاشة مكتملة ومتجاوبة 100%، يجب التحقق من البنود التالية:

- [ ] **Mobile Extra Small (320px - 360px):** لا يوجد أي تداخل أفقي (No Horizontal Overflow / Zero Pixels Overflow).
- [ ] **Mobile Standard (375px - 430px):** النصوص منسقة، الأزرار واضحة وبارزة، ومسافة اللمس ≥ 48dp.
- [ ] **Tablet Portrait (768px):** استخدام مساحة الشاشة الإضافية بعمودين متوازنين بدلاً من فراغ أبيض شاسع.
- [ ] **Tablet Landscape (1024px):** شريط تنقل مناسب وتوزيع كروت شبكي أنيق.
- [ ] **Desktop (1440px / 1920px):** وجود شريط تنقل دائم، المحتوى محدد داخل أقصى عرض مريح للعين (`maxWidth: 1200-1400px`) ومتمركز.
- [ ] **اتجاه RTL و LTR:** كل الهوامش والمحاذاة عبر `Directional` وخالية من التعارض.
- [ ] **لوحة المفاتيح:** لا تحدث أي أخطاء `Bottom Overflow` عند ظهور كيبورد الكتابة في النماذج.
- [ ] **مؤشر الماوس على الويب:** كل العناصر التفاعلية تظهر مؤشر اليد (`cursor: pointer`) وحركات خفيفة متجاوبة.

---

> 🎯 **الخلاصة الميدانية:**  
> هذا الملف هو مرجعنا التكتيكي الصارم. كل سطر برمجي سنكتبه أو نعدله في الشاشات سيكون محكوماً بهذه المعايير لنضمن أن تخرج منصة **Edu SaaS** بأعلى درجات الاحترافية والتألق الرقمي على أي جهاز في العالم.
