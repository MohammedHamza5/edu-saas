import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';
import 'math_tokens.dart';
import 'tenant_branding.dart';

class AppTheme {
  AppTheme._();

  /// Default baseline theme
  static ThemeData get lightTheme => fromBranding(TenantBranding.defaultAcademic());

  /// Builds a bespoke, high-performance [ThemeData] and [MathTokens] customized
  /// to the specific teacher / tenant's visual branding.
  static ThemeData fromBranding(TenantBranding branding) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: branding.primaryColor,
      primary: branding.primaryColor,
      surface: AppColors.surface,
      error: AppColors.error,
      brightness: Brightness.dark,
    );

    final dynamicMathTokens = MathTokens(
      cardBorderColor: const Color(0xFF1E293B),
      gridLineColor: const Color(0xFF1E293B),
      formulaSymbolOpacity: 0.08,
      statisticHighlightColor: branding.primaryColor,
      badgeActiveBackground: const Color(0xFF064E3B),
      badgeActiveForeground: const Color(0xFF34D399),
      badgePendingBackground: const Color(0xFF78350F),
      badgePendingForeground: const Color(0xFFFBBF24),
      badgeSuspendedBackground: const Color(0xFF7F1D1D),
      badgeSuspendedForeground: const Color(0xFFF87171),
      cardShadowSoft: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
      cardShadowElevated: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 20,
          offset: const Offset(0, 6),
          spreadRadius: -2,
        ),
        BoxShadow(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.06),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
      cardShadowPremium: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 32,
          offset: const Offset(0, 12),
          spreadRadius: -4,
        ),
        BoxShadow(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.14),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
      sidebarGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [branding.primaryColor, branding.primaryDark],
      ),
      primaryButtonGradient: LinearGradient(
        begin: AlignmentDirectional.centerStart,
        end: AlignmentDirectional.centerEnd,
        colors: [branding.gradientStart, branding.gradientEnd],
      ),
      accentGradient: LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [branding.secondaryColor, branding.gradientEnd],
      ),
      sidebarSelectedGlow: branding.accentGlow.withValues(alpha: 0.24),
      mathSymbolColor: branding.primaryLight.withValues(alpha: 0.40),
    );

    return ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: AppTypography.fontFamilyFallback,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: AppTypography.textTheme,
      extensions: <ThemeExtension<dynamic>>[
        dynamicMathTokens,
      ],
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.shadowSoft,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
      cardColor: AppColors.surfaceElevated,
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceElevated,
        modalBackgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLarge)),
          side: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        textStyle: const TextStyle(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          enabledMouseCursor: SystemMouseCursors.click,
          disabledMouseCursor: SystemMouseCursors.basic,
          backgroundColor: branding.primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          enabledMouseCursor: SystemMouseCursors.click,
          disabledMouseCursor: SystemMouseCursors.basic,
          foregroundColor: branding.primaryColor,
          minimumSize: const Size(64, 48),
          side: const BorderSide(color: AppColors.border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          enabledMouseCursor: SystemMouseCursors.click,
          disabledMouseCursor: SystemMouseCursors.basic,
          foregroundColor: branding.primaryColor,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          enabledMouseCursor: SystemMouseCursors.click,
          disabledMouseCursor: SystemMouseCursors.basic,
          backgroundColor: branding.primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          enabledMouseCursor: SystemMouseCursors.click,
          disabledMouseCursor: SystemMouseCursors.basic,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          borderSide: BorderSide(color: branding.primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
        floatingLabelStyle: TextStyle(
          color: branding.primaryColor,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        shadowColor: AppColors.shadowSoft,
        surfaceTintColor: Colors.transparent,
        indicatorColor: branding.primaryColor.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: branding.primaryColor,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.normal,
            color: AppColors.textSecondary,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        indicatorColor: branding.primaryColor.withValues(alpha: 0.12),
        selectedLabelTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: branding.primaryColor,
        ),
        unselectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          side: const BorderSide(color: AppColors.border),
        ),
        labelStyle: const TextStyle(fontSize: 12),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s4,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(),
      tabBarTheme: const TabBarThemeData(
        mouseCursor: WidgetStateMouseCursor.clickable,
      ),
      listTileTheme: const ListTileThemeData(
        mouseCursor: WidgetStateMouseCursor.clickable,
      ),
      segmentedButtonTheme: const SegmentedButtonThemeData(
        style: ButtonStyle(
          mouseCursor: WidgetStateMouseCursor.clickable,
        ),
      ),
    );
  }
}
