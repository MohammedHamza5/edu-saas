# Responsive Playbook & Architecture Directive
> Canonical Reference: `docs/RESPONSIVE_MASTER_PLAYBOOK.md`  
> Date: 2026-09-08 · Scope: Multi-Device Responsiveness (Mobile, Tablet, Desktop, 4K)

## القرار المعماري والتوجيه الدائم للريسبونسف:
1. **التركيز الحصري والكامل:** جعل منصة Edu SaaS تعمل وتتكيف 100% على كافة الأجهزة (Mobile Small 320px، Mobile Standard 375-430px، Foldables 700px، Tablets 768-1024px، Laptops 1280-1440px، و Desktops/4K 1920px+).
2. **الستاك المقفول (Zero External Bloat):** استخدام قدرات فلاتر الأصلية (`LayoutBuilder`, `MediaQuery`, `BoxConstraints`, `Flex`, `Wrap`) بدون أي باكدجات خارجية إضافية.
3. **التوكنات واللغات:** الالتزام الصارم بـ `Theme.of(context)`, `AppSpacing`, `AppTypography`، مع الدعم الكامل لـ RTL/LTR باستخدام `EdgeInsetsDirectional` و `AlignmentDirectional`.
4. **المرجع المفصل:** تم توثيق كامل المخططات، فئات الـ Breakpoints، معايير المكونات، وخطوات التنفيذ داخل الملف المرجعي:  
   `docs/RESPONSIVE_MASTER_PLAYBOOK.md`.
