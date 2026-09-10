import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/animated_math_background.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/math_loading_indicator.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  Timer? _fallbackTimer;
  late AnimationController _animController;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _loadingFade;

  @override
  void initState() {
    super.initState();

    // Staggered aesthetic entrance animation
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _logoScale = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
      ),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _loadingFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
      ),
    );

    _animController.forward();

    // Fallback timer if auth check is delayed
    _fallbackTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        final state = context.read<AuthCubit>().state;
        _navigateByState(state);
      }
    });
  }

  void _navigateByState(AuthState state) {
    if (!mounted) return;
    _fallbackTimer?.cancel();

    if (state is AuthAuthenticated) {
      final target = switch (state.user.role) {
        UserRole.teacher => AppRouter.teacherDashboard,
        UserRole.student => AppRouter.studentDashboard,
        UserRole.parent => AppRouter.parentDashboard,
      };
      context.go(target);
    } else if (state is AuthPendingApproval) {
      context.go(AppRouter.studentPending, extra: state.user.fullName);
    } else if (state is AuthTenantSuspended) {
      context.go(AppRouter.tenantSuspended);
    } else if (state is AuthUnauthenticated || state is AuthError) {
      context.go(AppRouter.login);
    } else {
      // If still loading or initial when fallback timer expires, safely redirect to login
      context.go(AppRouter.login);
    }
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = l10n != null ? l10n.appTitle : 'Edu SaaS';

    return Scaffold(
      backgroundColor: const Color(0xFF080C16),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is! AuthInitial && state is! AuthLoading) {
            _navigateByState(state);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Mathematical background: Animated Harmonic Wave + Coordinate Grid + Drifting formulas
            const AnimatedMathBackground(
              opacity: 0.14,
              gridColor: Color(0xFF6366F1),
              waveColor: Color(0xFF38BDF8),
              gridSpacing: 44,
              showAxes: true,
              showWave: true,
              showFormulas: true,
              showNodes: true,
            ),

            // Centered Main Content: Logo + Title + Subtitle
            Center(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mathematical Venn Diagram Logo Mark
                      FadeTransition(
                        opacity: _logoFade,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.s20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusLarge + 4,
                              ),
                              border: Border.all(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.18),
                                  blurRadius: 36,
                                  offset: const Offset(0, 10),
                                  spreadRadius: -2,
                                ),
                              ],
                            ),
                            child: const AppLogo(
                              size: 110,
                              showName: false,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s24),

                      // Title & Academic Subtitle
                      FadeTransition(
                        opacity: _titleFade,
                        child: SlideTransition(
                          position: _titleSlide,
                          child: Column(
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.s12,
                                  vertical: AppSpacing.s4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                                  border: Border.all(
                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.30),
                                  ),
                                ),
                                child: Text(
                                  l10n?.advancedMathEducationPlatform ?? 'Advanced Mathematics & Education Platform',
                                  style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Bottom Mathematical f(x) Curve Loading Indicator
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: FadeTransition(
                opacity: _loadingFade,
                child: Center(
                  child: MathLoadingIndicator(
                    size: 80,
                    showAxes: true,
                    color: const Color(0xFF38BDF8),
                    textColor: const Color(0xFF94A3B8),
                    message: l10n != null ? l10n.loading : 'Loading...',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
