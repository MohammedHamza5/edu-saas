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
    tenantId: 'ea5caf8b-112f-4044-b9ad-798d5ab025c3',
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
    videoProvider: 'bunny',
  );

  /// Default Platform Branding (Set to Dr. Antounios Ashraf)
  static TenantBranding get defaultBranding => drAntouniosBranding;

  /// Map of registered tenants by UUID / identifier / domain
  static final Map<String, TenantBranding> _registeredTenants = {
    'default': drAntouniosBranding,
    'ea5caf8b-112f-4044-b9ad-798d5ab025c3': drAntouniosBranding,
    'd3b07384-d113-460b-8d14-04666f77ecfa': drAntouniosBranding,
    // Demo & Sandbox Environment Branding (Live Platform Showcase)
    '11111111-1111-1111-1111-111111111111': TenantBranding.fromPrimary(
      tenantId: '11111111-1111-1111-1111-111111111111',
      brandName: 'منصة رياضيات الدبلومة الأمريكية',
      brandNameEn: 'American Math Academic Platform',
      teacherName: 'معلم تجريبي (معاينة المنصة)',
      teacherNameEn: 'Demo Teacher (Platform Preview)',
      subjectTitle: 'Digital SAT • ACT • EST Math',
      subjectTitleEn: 'Digital SAT • ACT • EST Math',
      academicTrack: 'النظام الأمريكي • Digital SAT • ACT • EST',
      academicTrackEn: 'American Curriculum • SAT • ACT • EST',
      tagline: 'Better Scores • Bigger Dreams • Bluebook Parity',
      taglineEn: 'Better Scores • Bigger Dreams • Bluebook Parity',
      welcomeMessage: 'مرحباً بك في المنصة التعليمية لـ American Math',
      welcomeMessageEn: 'Welcome to the American Math Platform',
      primaryColor: const Color(0xFF6366F1), // Luminous Indigo 500
      secondaryColor: const Color(0xFF38BDF8), // Electric Cyan 400
      accentGlow: const Color(0xFF38BDF8),
      signatureSymbol: '∑',
      logoAsset: null, // Pure mathematical branding, zero Dr. Antounios assets
      supportPhone: '+201515088953',
      supportEmail: 'demo@edsentre.com',
      videoProvider: 'bunny',
    ),
    'demo': TenantBranding.fromPrimary(
      tenantId: '11111111-1111-1111-1111-111111111111',
      brandName: 'منصة رياضيات الدبلومة الأمريكية',
      brandNameEn: 'American Math Academic Platform',
      teacherName: 'معلم تجريبي (معاينة المنصة)',
      teacherNameEn: 'Demo Teacher (Platform Preview)',
      subjectTitle: 'Digital SAT • ACT • EST Math',
      subjectTitleEn: 'Digital SAT • ACT • EST Math',
      academicTrack: 'النظام الأمريكي • Digital SAT • ACT • EST',
      academicTrackEn: 'American Curriculum • SAT • ACT • EST',
      tagline: 'Better Scores • Bigger Dreams • Bluebook Parity',
      taglineEn: 'Better Scores • Bigger Dreams • Bluebook Parity',
      welcomeMessage: 'مرحباً بك في المنصة التعليمية لـ American Math',
      welcomeMessageEn: 'Welcome to the American Math Platform',
      primaryColor: const Color(0xFF6366F1),
      secondaryColor: const Color(0xFF38BDF8),
      accentGlow: const Color(0xFF38BDF8),
      signatureSymbol: '∑',
      logoAsset: null, // Pure mathematical branding
      supportPhone: '+201515088953',
      supportEmail: 'demo@edsentre.com',
      videoProvider: 'bunny',
    ),
    'demo.edsentre.com': TenantBranding.fromPrimary(
      tenantId: '11111111-1111-1111-1111-111111111111',
      brandName: 'منصة رياضيات الدبلومة الأمريكية',
      brandNameEn: 'American Math Academic Platform',
      teacherName: 'معلم تجريبي (معاينة المنصة)',
      teacherNameEn: 'Demo Teacher (Platform Preview)',
      subjectTitle: 'Digital SAT • ACT • EST Math',
      subjectTitleEn: 'Digital SAT • ACT • EST Math',
      academicTrack: 'النظام الأمريكي • Digital SAT • ACT • EST',
      academicTrackEn: 'American Curriculum • SAT • ACT • EST',
      tagline: 'Better Scores • Bigger Dreams • Bluebook Parity',
      taglineEn: 'Better Scores • Bigger Dreams • Bluebook Parity',
      welcomeMessage: 'مرحباً بك في المنصة التعليمية لـ American Math',
      welcomeMessageEn: 'Welcome to the American Math Platform',
      primaryColor: const Color(0xFF6366F1),
      secondaryColor: const Color(0xFF38BDF8),
      accentGlow: const Color(0xFF38BDF8),
      signatureSymbol: '∑',
      logoAsset: null, // Pure mathematical branding
      supportPhone: '+201515088953',
      supportEmail: 'demo@edsentre.com',
      videoProvider: 'bunny',
    ),
    'teacher-1-slot': drAntouniosBranding,
    'antounios': drAntouniosBranding,
    'antounios.edsentre.com': drAntouniosBranding,
    'antounios.web.app': drAntouniosBranding,
    'edsentre.com': drAntouniosBranding,
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
