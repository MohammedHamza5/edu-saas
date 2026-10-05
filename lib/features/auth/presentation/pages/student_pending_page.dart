import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/tenant_registry.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/tenant_theme_cubit.dart';
import '../../../../core/widgets/academic_auth_scaffold.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/language_switcher_button.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class StudentPendingPage extends StatelessWidget {
  final String? studentName;

  const StudentPendingPage({super.key, this.studentName});

  @override
  Widget build(BuildContext context) {
    final branding = (() {
      try {
        return context.watch<TenantThemeCubit>().state;
      } catch (_) {
        return TenantRegistry.defaultBranding;
      }
    })();

    final effectiveName = (studentName != null && studentName!.isNotEmpty)
        ? studentName!
        : context.l10n.dearStudent;

    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.approvalConfirmedNotice),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          try {
            context.go(AppRoutes.studentDashboard);
          } catch (_) {}
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return AcademicAuthScaffold(
          maxWidth: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: AlignmentDirectional.topEnd,
                child: LanguageSwitcherButton(compact: true),
              ),
              const SizedBox(height: AppSpacing.s8),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  color: Color(0xFFFBBF24), // Vibrant amber gold
                  size: 38,
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
              Text(
                context.l10n.studentPendingTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                context.l10n.studentPendingGreeting(
                  effectiveName,
                  branding.localizedBrandName(context),
                  branding.localizedTeacherName(context),
                  branding.localizedAcademicTrack(context),
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF94A3B8),
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.s32),
              // Primary Action: Refresh and check if teacher approved the account
              AppButton(
                text: context.l10n.checkStatusButton,
                variant: AppButtonVariant.primary,
                icon: Icons.refresh_rounded,
                isFullWidth: true,
                isLoading: isLoading,
                onPressed: () async {
                  await context.read<AuthCubit>().checkAuthStatus();
                  if (context.mounted) {
                    final currentState = context.read<AuthCubit>().state;
                    if (currentState is AuthPendingApproval) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.stillPendingNotice),
                          backgroundColor: const Color(0xFFF59E0B),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: AppSpacing.s12),
              // Secondary Action: Cleanly terminate pending session and return to login
              AppButton(
                text: context.l10n.backToLogin,
                variant: AppButtonVariant.outlined,
                icon: Icons.arrow_back_rounded,
                isFullWidth: true,
                onPressed: () async {
                  await context.read<AuthCubit>().logout();
                  if (context.mounted) {
                    try {
                      context.go(AppRoutes.login);
                    } catch (_) {}
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
