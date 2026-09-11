import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary palette: Luminous Mathematical Indigo & Cyan Electric Accents
  static const Color primary = Color(0xFF6366F1); // Vibrant Indigo 500 (luminous on dark)
  static const Color primaryDark = Color(0xFF1E1B4B);
  static const Color primaryLight = Color(0xFF38BDF8); // Cyan Accent

  // Primary Gradient — used for buttons, hero banners, splash
  static const Color gradientStart = Color(0xFF312E81); // Deep Indigo
  static const Color gradientMid = Color(0xFF4338CA);   // Mid Indigo
  static const Color gradientEnd = Color(0xFF2563EB);   // Bright Electric Blue

  // Academic Background Gradient (cosmic obsidian → slate navy)
  static const Color bgGradientStart = Color(0xFF080C16); // Deep Obsidian
  static const Color bgGradientMid = Color(0xFF0B1120);   // Dark Slate Navy
  static const Color bgGradientEnd = Color(0xFF0F172A);   // Midnight Slate

  // Accent glow — used for selected states & premium highlights
  static const Color accentGlow = Color(0xFF38BDF8); // Cyan 400

  // Background & Surfaces (Dark Observatory)
  static const Color background = Color(0xFF080C16); // Deep Cosmic Obsidian Navy
  static const Color surface = Color(0xFF0F172A);    // Rich Slate Navy Glass
  static const Color surfaceVariant = Color(0xFF1E293B); // Lighter Slate Surface
  static const Color surfaceVariantDark = Color(0xFF1E293B);
  static const Color surfaceElevated = Color(0xFF111827); // Elevated Card Glass

  // Text colors (Dark Canvas Ergonomics — High Contrast AAA)
  static const Color textPrimary = Color(0xFFFFFFFF);   // High Contrast Crisp White (100% luminance)
  static const Color textSecondary = Color(0xFFE2E8F0); // Bright Slate 200 (crystal clear on dark)
  static const Color textSecondaryDark = Color(0xFFE2E8F0);
  static const Color textMuted = Color(0xFF94A3B8);     // Slate 400 (secondary helper captions)

  // Semantic borders & dividers
  static const Color border = Color(0xFF1E293B);        // Slate 800
  static const Color borderDark = Color(0xFF334155);    // Slate 700
  static const Color borderFocused = Color(0xFF38BDF8); // Cyan Glow
  static const Color borderPremium = Color(0xFF334155); // Slate 700

  // Shimmer (skeleton loading animation on dark canvas)
  static const Color shimmerBase = Color(0xFF1E293B);
  static const Color shimmerHighlight = Color(0xFF334155);

  // Premium shadow color (used in BoxShadow)
  static const Color shadowSoft = Color(0x33000000);
  static const Color shadowMedium = Color(0x4D000000);

  // Semantic Status Colors (tuned for dark backgrounds)
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFF14532D);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFF78350F);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFF7F1D1D);
  static const Color info = Color(0xFF38BDF8);
}
