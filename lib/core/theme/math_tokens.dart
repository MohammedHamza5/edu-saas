import 'package:flutter/material.dart';

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
  });

  static const MathTokens light = MathTokens(
    cardBorderColor: Color(0xFFE2E8F0), // Slate 200
    gridLineColor: Color(0xFFF1F5F9), // Slate 100
    formulaSymbolOpacity: 0.06, // Very subtle watermark
    statisticHighlightColor: Color(0xFF1E3A8A), // Deep Indigo
    badgeActiveBackground: Color(0xFFDCFCE7), // Green 100
    badgeActiveForeground: Color(0xFF15803D), // Green 700
    badgePendingBackground: Color(0xFFFEF3C7), // Amber 100
    badgePendingForeground: Color(0xFFB45309), // Amber 700
    badgeSuspendedBackground: Color(0xFFFEE2E2), // Red 100
    badgeSuspendedForeground: Color(0xFFB91C1C), // Red 700
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
    );
  }
}
