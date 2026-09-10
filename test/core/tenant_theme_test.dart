import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/config/tenant_registry.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/core/theme/math_tokens.dart';
import 'package:edu_saas/core/theme/tenant_branding.dart';
import 'package:edu_saas/core/theme/tenant_theme_cubit.dart';

void main() {
  group('TenantBranding & Dynamic Theming Tests', () {
    test('defaultAcademic provides expected baseline brand properties', () {
      final branding = TenantBranding.defaultAcademic();

      expect(branding.tenantId, 'default');
      expect(branding.brandName, 'EduSaaS');
      expect(branding.signatureSymbol, '∑');
      expect(branding.primaryColor, isA<Color>());
      expect(branding.gradientStart, isA<Color>());
      expect(branding.gradientEnd, isA<Color>());
    });

    test('fromPrimary generates harmonious gradients and shades', () {
      const customPrimary = Color(0xFF059669); // Emerald Green
      final branding = TenantBranding.fromPrimary(
        tenantId: 'teacher-green',
        brandName: 'أكاديمية النخبة للرياضيات',
        teacherName: 'د. أحمد النجار',
        subjectTitle: 'Calculus & SAT',
        academicTrack: 'نظام أمريكي',
        tagline: 'القمة تبدأ من هنا',
        primaryColor: customPrimary,
        signatureSymbol: '∫',
      );

      expect(branding.tenantId, 'teacher-green');
      expect(branding.brandName, 'أكاديمية النخبة للرياضيات');
      expect(branding.signatureSymbol, '∫');
      expect(branding.primaryColor, customPrimary);
      expect(branding.gradientStart, customPrimary);
      expect(branding.primaryDark, isNot(equals(customPrimary)));
      expect(branding.primaryLight, isNot(equals(customPrimary)));
    });

    test('TenantRegistry resolves registered tenants and falls back to default', () {
      final defaultTenant = TenantRegistry.resolve('default');
      expect(defaultTenant.brandName, 'منصة د. أنطونيوس أشرف');
      expect(defaultTenant.teacherName, 'د. أنطونيوس أشرف');

      final unknownTenant = TenantRegistry.resolve('unknown-uuid-123');
      expect(unknownTenant.brandName, 'منصة د. أنطونيوس أشرف');

      final teacherOne = TenantRegistry.resolve('teacher-1-slot');
      expect(teacherOne.teacherName, 'د. أنطونيوس أشرف');
    });

    test('AppTheme.fromBranding correctly embeds dynamic MathTokens', () {
      const customPrimary = Color(0xFF7C3AED); // Royal Purple
      final branding = TenantBranding.fromPrimary(
        tenantId: 'teacher-purple',
        brandName: 'Purple Academy',
        teacherName: 'Dr. Purple',
        subjectTitle: 'Pure Math',
        academicTrack: 'SAT',
        tagline: 'Excellence',
        primaryColor: customPrimary,
      );

      final theme = AppTheme.fromBranding(branding);
      expect(theme.colorScheme.primary, customPrimary);

      final mathTokens = theme.extension<MathTokens>();
      expect(mathTokens, isNotNull);
      expect(mathTokens!.statisticHighlightColor, customPrimary);
      expect(mathTokens.primaryButtonGradient.colors.first, customPrimary);
    });

    test('TenantThemeCubit updates state and resolves tenants dynamically', () {
      final cubit = TenantThemeCubit();
      expect(cubit.state.brandName, 'منصة د. أنطونيوس أشرف');

      final customBranding = TenantBranding.fromPrimary(
        tenantId: 'custom-id',
        brandName: 'Custom Center',
        teacherName: 'Teacher X',
        subjectTitle: 'EST Math',
        academicTrack: 'EST',
        tagline: 'Success',
        primaryColor: const Color(0xFFDC2626), // Crimson
      );

      cubit.setBranding(customBranding);
      expect(cubit.state.tenantId, 'custom-id');
      expect(cubit.state.brandName, 'Custom Center');
      expect(cubit.state.primaryColor, const Color(0xFFDC2626));

      cubit.resetToDefault();
      expect(cubit.state.brandName, 'منصة د. أنطونيوس أشرف');
    });
  });
}
