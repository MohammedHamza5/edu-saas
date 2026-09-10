import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Immutable model representing the visual, academic, and brand identity
/// of an individual Teacher / Organization (Tenant) on the platform.
class TenantBranding extends Equatable {
  final String tenantId;
  final String brandName;
  final String teacherName;
  final String subjectTitle;
  final String academicTrack;
  final String tagline;
  final String welcomeMessage;
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

  const TenantBranding({
    required this.tenantId,
    required this.brandName,
    required this.teacherName,
    required this.subjectTitle,
    required this.academicTrack,
    required this.tagline,
    required this.welcomeMessage,
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
  });

  /// Default baseline identity (Deep Indigo Academic SAT theme)
  factory TenantBranding.defaultAcademic() {
    return const TenantBranding(
      tenantId: 'default',
      brandName: 'EduSaaS',
      teacherName: 'المدرس الرئيسي',
      subjectTitle: 'Mathematics • SAT / EST / ACT',
      academicTrack: 'نظام أمريكي',
      tagline: 'منصة التعليم والرياضيات المتقدمة',
      welcomeMessage: 'مرحباً بك في منصتك الأكاديمية الخاصة',
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
    required String teacherName,
    required String subjectTitle,
    required String academicTrack,
    required String tagline,
    required Color primaryColor,
    String? welcomeMessage,
    String? signatureSymbol,
    Color? secondaryColor,
    Color? accentGlow,
    String? logoUrl,
    String? logoAsset,
    String? avatarUrl,
    String? supportPhone,
    String? supportEmail,
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
      teacherName: teacherName,
      subjectTitle: subjectTitle,
      academicTrack: academicTrack,
      tagline: tagline,
      welcomeMessage: welcomeMessage ?? 'مرحباً بك في منصة $brandName التعليمية',
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
    );
  }

  TenantBranding copyWith({
    String? tenantId,
    String? brandName,
    String? teacherName,
    String? subjectTitle,
    String? academicTrack,
    String? tagline,
    String? welcomeMessage,
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
  }) {
    return TenantBranding(
      tenantId: tenantId ?? this.tenantId,
      brandName: brandName ?? this.brandName,
      teacherName: teacherName ?? this.teacherName,
      subjectTitle: subjectTitle ?? this.subjectTitle,
      academicTrack: academicTrack ?? this.academicTrack,
      tagline: tagline ?? this.tagline,
      welcomeMessage: welcomeMessage ?? this.welcomeMessage,
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
    );
  }

  @override
  List<Object?> get props => [
        tenantId,
        brandName,
        teacherName,
        subjectTitle,
        academicTrack,
        tagline,
        welcomeMessage,
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
      ];
}
