import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Custom Design Tokens for "Modern Mathematical Academic SaaS"
/// Accessible via `Theme.of(context).extension<MathTokens>()`
@immutable
class MathTokens extends ThemeExtension<MathTokens> {
  final Color cardBorderColor;
  final Color gridLineColor;
  final double formulaSymbolOpacity;
  final Color statisticHighlightColor;
  final Color badgeActiveBackground;
  final Color badgeActiveForeground;
  final Color badgePendingBackground;
  final Color badgePendingForeground;
  final Color badgeSuspendedBackground;
  final Color badgeSuspendedForeground;

  // Premium UI tokens
  final List<BoxShadow> cardShadowSoft;
  final List<BoxShadow> cardShadowElevated;
  final List<BoxShadow> cardShadowPremium;
  final LinearGradient sidebarGradient;
  final LinearGradient primaryButtonGradient;
  final LinearGradient accentGradient;
  final Color sidebarSelectedGlow;
  final Color mathSymbolColor;

  const MathTokens({
    required this.cardBorderColor,
    required this.gridLineColor,
    required this.formulaSymbolOpacity,
    required this.statisticHighlightColor,
    required this.badgeActiveBackground,
    required this.badgeActiveForeground,
    required this.badgePendingBackground,
    required this.badgePendingForeground,
    required this.badgeSuspendedBackground,
    required this.badgeSuspendedForeground,
    required this.cardShadowSoft,
    required this.cardShadowElevated,
    required this.cardShadowPremium,
    required this.sidebarGradient,
    required this.primaryButtonGradient,
    required this.accentGradient,
    required this.sidebarSelectedGlow,
    required this.mathSymbolColor,
  });

  static const MathTokens light = MathTokens(
    cardBorderColor: AppColors.border,
    gridLineColor: Color(0xFFF1F5F9),       // Slate 100
    formulaSymbolOpacity: 0.06,              // Very subtle watermark
    statisticHighlightColor: AppColors.primary,
    badgeActiveBackground: Color(0xFFDCFCE7),
    badgeActiveForeground: Color(0xFF15803D),
    badgePendingBackground: Color(0xFFFEF3C7),
    badgePendingForeground: Color(0xFFB45309),
    badgeSuspendedBackground: Color(0xFFFEE2E2),
    badgeSuspendedForeground: Color(0xFFB91C1C),
    // ───── Premium tokens ─────
    cardShadowSoft: [
      BoxShadow(
        color: AppColors.shadowSoft,
        blurRadius: 12,
        offset: Offset(0, 4),
        spreadRadius: 0,
      ),
    ],
    cardShadowElevated: [
      BoxShadow(
        color: AppColors.shadowSoft,
        blurRadius: 20,
        offset: Offset(0, 6),
        spreadRadius: -2,
      ),
      BoxShadow(
        color: Color(0x0A000000),
        blurRadius: 6,
        offset: Offset(0, 2),
      ),
    ],
    cardShadowPremium: [
      BoxShadow(
        color: AppColors.shadowMedium,
        blurRadius: 32,
        offset: Offset(0, 12),
        spreadRadius: -4,
      ),
      BoxShadow(
        color: Color(0x0D000000),
        blurRadius: 8,
        offset: Offset(0, 4),
      ),
    ],
    sidebarGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1E3A8A), Color(0xFF172554)],
    ),
    primaryButtonGradient: LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: [AppColors.gradientStart, AppColors.gradientEnd],
    ),
    accentGradient: LinearGradient(
      begin: AlignmentDirectional.topStart,
      end: AlignmentDirectional.bottomEnd,
      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
    ),
    sidebarSelectedGlow: Color(0x331D4ED8), // Blue 24% opacity
    mathSymbolColor: Color(0xFFBFD1FF),     // Soft indigo for math symbols
  );

  @override
  MathTokens copyWith({
    Color? cardBorderColor,
    Color? gridLineColor,
    double? formulaSymbolOpacity,
    Color? statisticHighlightColor,
    Color? badgeActiveBackground,
    Color? badgeActiveForeground,
    Color? badgePendingBackground,
    Color? badgePendingForeground,
    Color? badgeSuspendedBackground,
    Color? badgeSuspendedForeground,
    List<BoxShadow>? cardShadowSoft,
    List<BoxShadow>? cardShadowElevated,
    List<BoxShadow>? cardShadowPremium,
    LinearGradient? sidebarGradient,
    LinearGradient? primaryButtonGradient,
    LinearGradient? accentGradient,
    Color? sidebarSelectedGlow,
    Color? mathSymbolColor,
  }) {
    return MathTokens(
      cardBorderColor: cardBorderColor ?? this.cardBorderColor,
      gridLineColor: gridLineColor ?? this.gridLineColor,
      formulaSymbolOpacity: formulaSymbolOpacity ?? this.formulaSymbolOpacity,
      statisticHighlightColor: statisticHighlightColor ?? this.statisticHighlightColor,
      badgeActiveBackground: badgeActiveBackground ?? this.badgeActiveBackground,
      badgeActiveForeground: badgeActiveForeground ?? this.badgeActiveForeground,
      badgePendingBackground: badgePendingBackground ?? this.badgePendingBackground,
      badgePendingForeground: badgePendingForeground ?? this.badgePendingForeground,
      badgeSuspendedBackground: badgeSuspendedBackground ?? this.badgeSuspendedBackground,
      badgeSuspendedForeground: badgeSuspendedForeground ?? this.badgeSuspendedForeground,
      cardShadowSoft: cardShadowSoft ?? this.cardShadowSoft,
      cardShadowElevated: cardShadowElevated ?? this.cardShadowElevated,
      cardShadowPremium: cardShadowPremium ?? this.cardShadowPremium,
      sidebarGradient: sidebarGradient ?? this.sidebarGradient,
      primaryButtonGradient: primaryButtonGradient ?? this.primaryButtonGradient,
      accentGradient: accentGradient ?? this.accentGradient,
      sidebarSelectedGlow: sidebarSelectedGlow ?? this.sidebarSelectedGlow,
      mathSymbolColor: mathSymbolColor ?? this.mathSymbolColor,
    );
  }

  @override
  MathTokens lerp(ThemeExtension<MathTokens>? other, double t) {
    if (other is! MathTokens) return this;
    return MathTokens(
      cardBorderColor: Color.lerp(cardBorderColor, other.cardBorderColor, t) ?? cardBorderColor,
      gridLineColor: Color.lerp(gridLineColor, other.gridLineColor, t) ?? gridLineColor,
      formulaSymbolOpacity: formulaSymbolOpacity + (other.formulaSymbolOpacity - formulaSymbolOpacity) * t,
      statisticHighlightColor: Color.lerp(statisticHighlightColor, other.statisticHighlightColor, t) ?? statisticHighlightColor,
      badgeActiveBackground: Color.lerp(badgeActiveBackground, other.badgeActiveBackground, t) ?? badgeActiveBackground,
      badgeActiveForeground: Color.lerp(badgeActiveForeground, other.badgeActiveForeground, t) ?? badgeActiveForeground,
      badgePendingBackground: Color.lerp(badgePendingBackground, other.badgePendingBackground, t) ?? badgePendingBackground,
      badgePendingForeground: Color.lerp(badgePendingForeground, other.badgePendingForeground, t) ?? badgePendingForeground,
      badgeSuspendedBackground: Color.lerp(badgeSuspendedBackground, other.badgeSuspendedBackground, t) ?? badgeSuspendedBackground,
      badgeSuspendedForeground: Color.lerp(badgeSuspendedForeground, other.badgeSuspendedForeground, t) ?? badgeSuspendedForeground,
      cardShadowSoft: t < 0.5 ? cardShadowSoft : other.cardShadowSoft,
      cardShadowElevated: t < 0.5 ? cardShadowElevated : other.cardShadowElevated,
      cardShadowPremium: t < 0.5 ? cardShadowPremium : other.cardShadowPremium,
      sidebarGradient: LinearGradient.lerp(sidebarGradient, other.sidebarGradient, t) ?? sidebarGradient,
      primaryButtonGradient: LinearGradient.lerp(primaryButtonGradient, other.primaryButtonGradient, t) ?? primaryButtonGradient,
      accentGradient: LinearGradient.lerp(accentGradient, other.accentGradient, t) ?? accentGradient,
      sidebarSelectedGlow: Color.lerp(sidebarSelectedGlow, other.sidebarSelectedGlow, t) ?? sidebarSelectedGlow,
      mathSymbolColor: Color.lerp(mathSymbolColor, other.mathSymbolColor, t) ?? mathSymbolColor,
    );
  }
}
