import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    // Fallback timer ensures that if network check delays or fails, app moves forward
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
    }
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = l10n != null ? l10n.appTitle : 'Edu SaaS';

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is! AuthInitial && state is! AuthLoading) {
            _navigateByState(state);
          }
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '∑',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: AppSpacing.s32),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
