import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../config/tenant_registry.dart';
import '../theme/app_spacing.dart';
import '../theme/math_tokens.dart';
import '../theme/tenant_theme_cubit.dart';
import 'animated_math_background.dart';

/// Full-screen mathematical canvas with coordinate grid, faint formulas,
/// and a centered floating academic glass card for Auth flows (Login / Register).
class AcademicAuthScaffold extends StatefulWidget {
  final Widget child;
  final double maxWidth;

  const AcademicAuthScaffold({
    super.key,
    required this.child,
    this.maxWidth = 480,
  });

  @override
  State<AcademicAuthScaffold> createState() => _AcademicAuthScaffoldState();
}

class _AcademicAuthScaffoldState extends State<AcademicAuthScaffold>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutCubic,
      ),
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mathTokens =
        Theme.of(context).extension<MathTokens>() ?? MathTokens.light;

    final branding = (() {
      try {
        return context.watch<TenantThemeCubit>().state;
      } catch (_) {
        return TenantRegistry.defaultBranding;
      }
    })();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: Stack(
        children: [
          // ── 1. Deep Mathematical Blue / Indigo Canvas ─────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF080C16), // Deepest Void Blue
                    const Color(0xFF0F172A), // Mathematical Slate Navy
                    branding.primaryDark,
                    branding.primaryColor,
                  ],
                  stops: const [0.0, 0.35, 0.75, 1.0],
                ),
              ),
            ),
          ),

          // ── 2. Animated Mathematical Coordinate Grid & Formulas ─────────
          const Positioned.fill(
            child: AnimatedMathBackground(
              opacity: 0.07,
              gridSpacing: 40,
              gridColor: Colors.white,
              waveColor: Color(0xFF818CF8),
              showAxes: true,
              showFormulas: true,
              showWave: true,
              showNodes: true,
              cycleDuration: Duration(seconds: 24),
              child: SizedBox.expand(),
            ),
          ),

          // ── 3. Subtle Ambient Mathematical Glyphs ──────────────────────────
          const Positioned(
            top: -80,
            right: -60,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.05,
                child: Text(
                  '∑',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 340,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'serif',
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            bottom: -100,
            left: -80,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.04,
                child: Text(
                  'π',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 360,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'serif',
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            top: 140,
            left: 50,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.05,
                child: Text(
                  'f(x)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 80,
                    fontStyle: FontStyle.italic,
                    fontFamily: 'serif',
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            bottom: 120,
            right: 60,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.05,
                child: Text(
                  '√x',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 90,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'serif',
                  ),
                ),
              ),
            ),
          ),

          // ── 4. Centered Floating Academic Glass Card ───────────────────────
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s20,
                    vertical: AppSpacing.s28,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: widget.maxWidth),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusLarge + 6,
                          ),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.82),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusLarge + 6,
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    blurRadius: 40,
                                    offset: const Offset(0, 20),
                                    spreadRadius: -4,
                                  ),
                                  BoxShadow(
                                    color: branding.primaryColor.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 32,
                                    offset: const Offset(0, 10),
                                    spreadRadius: -2,
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  // Top Accent Indicator Line
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    height: 4,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: mathTokens.primaryButtonGradient,
                                      ),
                                    ),
                                  ),

                                  // Inner Form Content with Academic Dark Theme
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      AppSpacing.s28,
                                      AppSpacing.s32,
                                      AppSpacing.s28,
                                      AppSpacing.s28,
                                    ),
                                    child: Theme(
                                      data: Theme.of(context).copyWith(
                                        brightness: Brightness.dark,
                                        colorScheme: Theme.of(context).colorScheme.copyWith(
                                          brightness: Brightness.dark,
                                          surface: const Color(0xFF131C35),
                                          onSurface: Colors.white,
                                          primary: branding.primaryLight,
                                        ),
                                        inputDecorationTheme: InputDecorationTheme(
                                          filled: true,
                                          fillColor: const Color(0xFF1E293B).withValues(alpha: 0.7),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                                            borderSide: BorderSide(
                                              color: Colors.white.withValues(alpha: 0.15),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                                            borderSide: BorderSide(
                                              color: Colors.white.withValues(alpha: 0.15),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                                            borderSide: BorderSide(
                                              color: branding.primaryLight,
                                              width: 1.8,
                                            ),
                                          ),
                                          errorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                                            borderSide: const BorderSide(color: Color(0xFFF87171)),
                                          ),
                                          focusedErrorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFF87171),
                                              width: 1.8,
                                            ),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.s16,
                                            vertical: AppSpacing.s14,
                                          ),
                                          labelStyle: const TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 14,
                                          ),
                                          floatingLabelStyle: TextStyle(
                                            color: branding.primaryLight,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          prefixIconColor: const Color(0xFF94A3B8),
                                          suffixIconColor: const Color(0xFF94A3B8),
                                        ),
                                        textSelectionTheme: TextSelectionThemeData(
                                          cursorColor: branding.primaryLight,
                                          selectionColor: branding.primaryColor.withValues(alpha: 0.45),
                                          selectionHandleColor: branding.primaryLight,
                                        ),
                                      ),
                                      child: widget.child,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
