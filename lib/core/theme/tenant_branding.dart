import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Immutable model representing the visual, academic, and brand identity
/// of an individual Teacher / Organization (Tenant) on the platform.
class TenantBranding extends Equatable {
  final String tenantId;
  final String brandName;
  final String? brandNameEn;
  final String teacherName;
  final String? teacherNameEn;
  final String subjectTitle;
  final String? subjectTitleEn;
  final String academicTrack;
  final String? academicTrackEn;
  final String tagline;
  final String? taglineEn;
  final String welcomeMessage;
  final String? welcomeMessageEn;
  final String signatureSymbol;
  final Color primaryColor;
  final Color primaryDark;
  final Color primaryLight;
  final Color secondaryColor;
  final Color gradientStart;
  final Color gradientMid;
  final Color gradientEnd;
  final Color accentGlow;
  final Color cardBorderColor;
  final String? logoUrl;
  final String? logoAsset;
  final String? avatarUrl;
  final String? supportPhone;
  final String? supportEmail;
  final String videoProvider;

  const TenantBranding({
    required this.tenantId,
    required this.brandName,
    this.brandNameEn,
    required this.teacherName,
    this.teacherNameEn,
    required this.subjectTitle,
    this.subjectTitleEn,
    required this.academicTrack,
    this.academicTrackEn,
    required this.tagline,
    this.taglineEn,
    required this.welcomeMessage,
    this.welcomeMessageEn,
    this.signatureSymbol = '∑',
    required this.primaryColor,
    required this.primaryDark,
    required this.primaryLight,
    required this.secondaryColor,
    required this.gradientStart,
    required this.gradientMid,
    required this.gradientEnd,
    required this.accentGlow,
    required this.cardBorderColor,
    this.logoUrl,
    this.logoAsset,
    this.avatarUrl,
    this.supportPhone,
    this.supportEmail,
    this.videoProvider = 'youtube',
  });

  /// Default baseline identity (Deep Indigo Academic SAT theme)
  factory TenantBranding.defaultAcademic() {
    return const TenantBranding(
      tenantId: 'default',
      brandName: 'منصة التعليم الأكاديمي',
      brandNameEn: 'EduSaaS Academic Platform',
      teacherName: 'المدرس الرئيسي',
      teacherNameEn: 'Lead Instructor',
      subjectTitle: 'النظام الأمريكي • SAT / EST / ACT',
      subjectTitleEn: 'American Curriculum • SAT / EST / ACT',
      academicTrack: 'نظام أمريكي • Grade 10-12',
      academicTrackEn: 'American High School • Grade 10-12',
      tagline: 'المنصة الأكاديمية المتقدمة',
      taglineEn: 'Advanced Education Platform',
      welcomeMessage: 'مرحباً بك في منصتك الأكاديمية الخاصة',
      welcomeMessageEn: 'Welcome to your private academic portal',
      signatureSymbol: '∑',
      primaryColor: AppColors.primary,
      primaryDark: AppColors.primaryDark,
      primaryLight: AppColors.primaryLight,
      secondaryColor: AppColors.primaryLight,
      gradientStart: AppColors.gradientStart,
      gradientMid: AppColors.gradientMid,
      gradientEnd: AppColors.gradientEnd,
      accentGlow: AppColors.accentGlow,
      cardBorderColor: AppColors.border,
    );
  }

  /// Intelligently computes harmonious shades, gradients, and glows from a primary color
  factory TenantBranding.fromPrimary({
    required String tenantId,
    required String brandName,
    String? brandNameEn,
    required String teacherName,
    String? teacherNameEn,
    required String subjectTitle,
    String? subjectTitleEn,
    required String academicTrack,
    String? academicTrackEn,
    required String tagline,
    String? taglineEn,
    required Color primaryColor,
    String? welcomeMessage,
    String? welcomeMessageEn,
    String? signatureSymbol,
    Color? secondaryColor,
    Color? accentGlow,
    String? logoUrl,
    String? logoAsset,
    String? avatarUrl,
    String? supportPhone,
    String? supportEmail,
    String videoProvider = 'youtube',
  }) {
    final hsl = HSLColor.fromColor(primaryColor);

    // Compute deeper tone for headers & dark gradients
    final primaryDark = hsl
        .withLightness((hsl.lightness * 0.75).clamp(0.12, 0.45))
        .toColor();

    // Compute lighter tone for hover & accents
    final primaryLight = hsl
        .withLightness((hsl.lightness * 1.25).clamp(0.50, 0.85))
        .toColor();

    // Mid shade for smooth gradients
    final gradientMid = Color.lerp(primaryColor, primaryLight, 0.45) ?? primaryColor;
    final gradientEnd = primaryLight;

    final effectiveSecondary = secondaryColor ?? primaryLight;
    final effectiveAccent = accentGlow ?? primaryLight;

    return TenantBranding(
      tenantId: tenantId,
      brandName: brandName,
      brandNameEn: brandNameEn,
      teacherName: teacherName,
      teacherNameEn: teacherNameEn,
      subjectTitle: subjectTitle,
      subjectTitleEn: subjectTitleEn,
      academicTrack: academicTrack,
      academicTrackEn: academicTrackEn,
      tagline: tagline,
      taglineEn: taglineEn,
      welcomeMessage: welcomeMessage ?? 'مرحباً بك في منصة $brandName التعليمية',
      welcomeMessageEn: welcomeMessageEn ?? 'Welcome to $brandNameEn Academic Platform',
      signatureSymbol: signatureSymbol ?? '∑',
      primaryColor: primaryColor,
      primaryDark: primaryDark,
      primaryLight: primaryLight,
      secondaryColor: effectiveSecondary,
      gradientStart: primaryColor,
      gradientMid: gradientMid,
      gradientEnd: gradientEnd,
      accentGlow: effectiveAccent,
      cardBorderColor: AppColors.border,
      logoUrl: logoUrl,
      logoAsset: logoAsset,
      avatarUrl: avatarUrl,
      supportPhone: supportPhone,
      supportEmail: supportEmail,
      videoProvider: videoProvider,
    );
  }

  /// Localized Brand Name based on active BuildContext locale
  String localizedBrandName(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    final isAr = locale?.languageCode == 'ar';
    return isAr ? brandName : (brandNameEn ?? brandName);
  }

  /// Localized Teacher Name based on active BuildContext locale
  String localizedTeacherName(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    final isAr = locale?.languageCode == 'ar';
    return isAr ? teacherName : (teacherNameEn ?? teacherName);
  }

  /// Localized Academic Track based on active BuildContext locale
  String localizedAcademicTrack(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    final isAr = locale?.languageCode == 'ar';
    return isAr ? academicTrack : (academicTrackEn ?? academicTrack);
  }

  /// Localized Subject Title based on active BuildContext locale
  String localizedSubjectTitle(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    final isAr = locale?.languageCode == 'ar';
    return isAr ? subjectTitle : (subjectTitleEn ?? subjectTitle);
  }

  /// Localized Tagline based on active BuildContext locale
  String localizedTagline(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    final isAr = locale?.languageCode == 'ar';
    return isAr ? tagline : (taglineEn ?? tagline);
  }

  /// Localized Welcome Message based on active BuildContext locale
  String localizedWelcomeMessage(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    final isAr = locale?.languageCode == 'ar';
    return isAr ? welcomeMessage : (welcomeMessageEn ?? welcomeMessage);
  }

  /// Returns localized brand name for a given [Locale] (e.g. for MaterialApp title)
  String getBrandNameForLocale(Locale locale) {
    final isAr = locale.languageCode == 'ar';
    return isAr ? brandName : (brandNameEn ?? brandName);
  }

  TenantBranding copyWith({
    String? tenantId,
    String? brandName,
    String? brandNameEn,
    String? teacherName,
    String? teacherNameEn,
    String? subjectTitle,
    String? subjectTitleEn,
    String? academicTrack,
    String? academicTrackEn,
    String? tagline,
    String? taglineEn,
    String? welcomeMessage,
    String? welcomeMessageEn,
    String? signatureSymbol,
    Color? primaryColor,
    Color? primaryDark,
    Color? primaryLight,
    Color? secondaryColor,
    Color? gradientStart,
    Color? gradientMid,
    Color? gradientEnd,
    Color? accentGlow,
    Color? cardBorderColor,
    String? logoUrl,
    String? logoAsset,
    String? avatarUrl,
    String? supportPhone,
    String? supportEmail,
    String? videoProvider,
  }) {
    return TenantBranding(
      tenantId: tenantId ?? this.tenantId,
      brandName: brandName ?? this.brandName,
      brandNameEn: brandNameEn ?? this.brandNameEn,
      teacherName: teacherName ?? this.teacherName,
      teacherNameEn: teacherNameEn ?? this.teacherNameEn,
      subjectTitle: subjectTitle ?? this.subjectTitle,
      subjectTitleEn: subjectTitleEn ?? this.subjectTitleEn,
      academicTrack: academicTrack ?? this.academicTrack,
      academicTrackEn: academicTrackEn ?? this.academicTrackEn,
      tagline: tagline ?? this.tagline,
      taglineEn: taglineEn ?? this.taglineEn,
      welcomeMessage: welcomeMessage ?? this.welcomeMessage,
      welcomeMessageEn: welcomeMessageEn ?? this.welcomeMessageEn,
      signatureSymbol: signatureSymbol ?? this.signatureSymbol,
      primaryColor: primaryColor ?? this.primaryColor,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryLight: primaryLight ?? this.primaryLight,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      gradientStart: gradientStart ?? this.gradientStart,
      gradientMid: gradientMid ?? this.gradientMid,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      accentGlow: accentGlow ?? this.accentGlow,
      cardBorderColor: cardBorderColor ?? this.cardBorderColor,
      logoUrl: logoUrl ?? this.logoUrl,
      logoAsset: logoAsset ?? this.logoAsset,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      supportPhone: supportPhone ?? this.supportPhone,
      supportEmail: supportEmail ?? this.supportEmail,
      videoProvider: videoProvider ?? this.videoProvider,
    );
  }

  @override
  List<Object?> get props => [
        tenantId,
        brandName,
        brandNameEn,
        teacherName,
        teacherNameEn,
        subjectTitle,
        subjectTitleEn,
        academicTrack,
        academicTrackEn,
        tagline,
        taglineEn,
        welcomeMessage,
        welcomeMessageEn,
        signatureSymbol,
        primaryColor,
        primaryDark,
        primaryLight,
        secondaryColor,
        gradientStart,
        gradientMid,
        gradientEnd,
        accentGlow,
        cardBorderColor,
        logoUrl,
        logoAsset,
        avatarUrl,
        supportPhone,
        supportEmail,
        videoProvider,
      ];
}
