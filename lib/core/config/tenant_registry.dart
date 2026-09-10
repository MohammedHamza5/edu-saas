import 'dart:ui';
import '../theme/tenant_branding.dart';

/// Central registry of configured teacher profiles & organizations.
///
/// When onboarding a new teacher, register their [TenantBranding] here
/// or link to their Supabase tenant UUID so the platform instantly
/// adapts to their custom visual identity and academic curriculum.
class TenantRegistry {
  TenantRegistry._();

  /// Premier Tenant: Dr. Antounios Ashraf — Exclusive American Math Platform
  static final TenantBranding drAntouniosBranding = TenantBranding.fromPrimary(
    tenantId: 'd3b07384-d113-460b-8d14-04666f77ecfa',
    brandName: 'منصة د. أنطونيوس أشرف',
    teacherName: 'د. أنطونيوس أشرف',
    subjectTitle: 'رياضيات النظام الأمريكي • SAT · EST · ACT',
    academicTrack: 'النظام الأمريكي • Grade 10-12',
    tagline: 'Concept • Speed • Strategy • Accuracy (Target 800)',
    welcomeMessage: 'مرحباً بك في منصة د. أنطونيوس أشرف الخاصة برياضيات الدبلومة الأمريكية',
    primaryColor: const Color(0xFF1E3A8A), // Deep Academic Navy/Indigo
    secondaryColor: const Color(0xFF2563EB), // Royal Mathematical Blue
    accentGlow: const Color(0xFF38BDF8), // Electric Cyan highlight for SAT precision
    signatureSymbol: '∑',
    supportPhone: '+201000000000',
    supportEmail: 'dr.antounios@math-academy.com',
  );

  /// Default Platform Branding (Set to Dr. Antounios Ashraf)
  static TenantBranding get defaultBranding => drAntouniosBranding;

  /// Map of registered tenants by UUID / identifier
  static final Map<String, TenantBranding> _registeredTenants = {
    'default': drAntouniosBranding,
    'd3b07384-d113-460b-8d14-04666f77ecfa': drAntouniosBranding,
    'teacher-1-slot': drAntouniosBranding,
  };

  /// Registers or updates a teacher branding in the runtime registry
  static void register(TenantBranding branding) {
    _registeredTenants[branding.tenantId] = branding;
  }

  /// Resolves the branding for a tenant ID, falling back to default
  static TenantBranding resolve(String? tenantId) {
    if (tenantId == null || tenantId.isEmpty) {
      return defaultBranding;
    }
    return _registeredTenants[tenantId] ?? defaultBranding;
  }
}
