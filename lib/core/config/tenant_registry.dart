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
    brandNameEn: 'Dr. Antounios Ashraf Platform',
    teacherName: 'د. أنطونيوس أشرف',
    teacherNameEn: 'Dr. Antounios Ashraf',
    subjectTitle: 'SAT • ACT • EST • MORE',
    subjectTitleEn: 'SAT • ACT • EST • MORE',
    academicTrack: 'النظام الأمريكي • Grade 10-12',
    academicTrackEn: 'American Curriculum • Grade 10-12',
    tagline: 'Better Scores Bigger Dreams (EST. 2026)',
    taglineEn: 'Better Scores Bigger Dreams (EST. 2026)',
    welcomeMessage: 'مرحباً بك في منصة د. أنطونيوس أشرف',
    primaryColor: const Color(0xFF6366F1), // Luminous Indigo 500
    secondaryColor: const Color(0xFF38BDF8), // Electric Cyan 400
    accentGlow: const Color(0xFF38BDF8), // Electric Cyan highlight
    signatureSymbol: '∑',
    logoAsset: 'assets/images/dr_antounios_logo.png',
    supportPhone: '+201000000000',
    supportEmail: 'contact@antounios.edsentre.com',
  );

  /// Default Platform Branding (Set to Dr. Antounios Ashraf)
  static TenantBranding get defaultBranding => drAntouniosBranding;

  /// Map of registered tenants by UUID / identifier / domain
  static final Map<String, TenantBranding> _registeredTenants = {
    'default': drAntouniosBranding,
    'd3b07384-d113-460b-8d14-04666f77ecfa': drAntouniosBranding,
    'teacher-1-slot': drAntouniosBranding,
    'antounios': drAntouniosBranding,
    'antounios.edsentre.com': drAntouniosBranding,
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
