# UI/UX & High-Performance Interaction Directive
> Canonical Reference: `docs/UI_UX_INTERACTION_MASTER_PLAYBOOK.md`  
> Date: 2026-09-08 · Scope: UI Polish, Micro-Interactions, 60/120 FPS Performance, Zero Jank

## القرار والتوجيه الدائم لمهندس الواجهات (UI/UX Specialist):
1. **التركيز الحصري والكامل:** جعل واجهات المنصة استثنائية، عصرية وأنيقة تضاهي كبرى المنصات السحابية العالمية (Stripe / Linear / Notion) بهوية أكاديمية رياضية راقية.
2. **منع التهنيج والبطء (Zero Tolerance for Lag):**
   - حركات ميكروية سريعة وخاطفة فقط (**100ms - 280ms** عبر `Curves.easeOutCubic`).
   - ممنوع تماماً الـ Blurs الثقيلة أو الشاشات المليئة بالـ Confetti أو الحركات الكرتونية المستمرة التي تستهلك المعالج وتسبب Frame Drops.
   - عزل العناصر المتحركة دائماً بـ `RepaintBoundary`.
   - تحريك الـ `Transform` و `Opacity` فقط وتجنب الـ Layout Passes أثناء الحركة.
3. **ثبات لوحة الألوان والستاك:**
   - الحفاظ التام على ألوان التوكنات المعتمدة (`AppColors.primary = #1E3A8A / #5B4FE0` والأوف وايت للسطح والخلفية) وعدم إضافة ألوان عشوائية.
   - عدم إدخال مكتبات أنيميشن خارجية ثقيلة؛ الاعتماد بالكامل على محرك فلاتر الأصلي السريع والخفيف.
4. **المرجع المفصل:** تم توثيق كامل القواعد الهندسية والفيزيائية للشاشات الـ 57 والبوابات الثلاث في:  
   `docs/UI_UX_INTERACTION_MASTER_PLAYBOOK.md`.

## الميزات التي تم ترقيتها وإتقانها بالكامل (Completed Elite Polish):
- **Feature 08 (Groups):** `InteractiveGroupCard` مع Watermarks رياضية، رفع ميكروي `-2.5px` وScale `1.012`، عزل `RepaintBoundary`، بطاقات تفاصيل المجموعة وأعضائها. (11/11 tests pass).
- **Feature 12 (Attendance):** `AttendanceStatCard` مع مؤشر إضاءة علوي، `StudentAttendanceRowCard` بنظام Tactile Pills (`140ms`)، شريط تحضير الكل حاضر، بطاقة نسبة الالتزام بعلامة مائية `%`. (13/13 tests pass).
- **Feature 14 (Notifications):** `NotificationTile` مع شريط تمييز جانبي RTL وتدرج ناعم، `NotificationBadgeButton` بأنيميشن انبثاق لطيف، نافذة التفاصيل السفلية بمقبض سحب وتاريخ تفصيلي. (14/14 tests pass).
- **Feature 15 (Parent Portal):** `ChildSelectorBar` بأفاتار أكاديمي متدرج، `ParentAcademicOverviewCard` ببطاقات إحصائية معزولة وتفصيل أنيق لدرجات وحصص الطالب. (11/11 tests pass).
- **Dashboards:** لوحة المعلم ولوحة الطالب ولوحة ولي الأمر مع تحسينات التجاوب لكافة الشاشات (320px إلى 1920px) و0 تحذيرات في `flutter analyze`.
- **Feature 13 (Videos & Lesson Player):** حل كامل لمشكلة الشاشة السوداء بتضمين HLS decoder (`hls.min.js`) للمتصفحات، إزالة الشريط السفلي غير المستخدم، إعادة تصميم زر التشغيل والتحكم المركزي بأسلوب Frosted Glass دارك ناعم وبدون توهج نيون مزعج، إتاحة وضع ملء الشاشة الكامل (Fullscreen API) برمجياً وعبر اختصار `F`، وإعادة بناء كارد التقدم الأكاديمي بواجهة تفاعلية نظيفة (نسبة مئوية، وقت منقضي/متبقي، شريط تفاعلي دقيق، مع حذف التقسيمات الوهمية). (21/21 tests pass).

