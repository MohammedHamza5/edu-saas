import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/tenant_registry.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/tenant_theme_cubit.dart';
import '../../../../core/widgets/academic_auth_scaffold.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/language_switcher_button.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../domain/entities/user_entity.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthCubit>().login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final branding = (() {
      try {
        return context.watch<TenantThemeCubit>().state;
      } catch (_) {
        return TenantRegistry.defaultBranding;
      }
    })();

    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          final targetRoute = switch (state.user.role) {
            UserRole.teacher => AppRoutes.teacherDashboard,
            UserRole.parent => AppRoutes.parentDashboard,
            UserRole.student => AppRoutes.studentDashboard,
          };
          context.go(targetRoute);
        } else if (state is AuthPendingApproval) {
          context.go(AppRoutes.studentPending, extra: state.user.fullName);
        } else if (state is AuthTenantSuspended) {
          context.go(AppRoutes.tenantSuspended);
        } else if (state is AuthError) {
          AppFeedback.showError(context, state.failure ?? state.message);
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return AcademicAuthScaffold(
          maxWidth: 460,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Language Switcher at Top ────────────────────────────────
                const Align(
                  alignment: AlignmentDirectional.topEnd,
                  child: LanguageSwitcherButton(compact: true),
                ),
                const SizedBox(height: AppSpacing.s8),

                // ── 1. Brand Emblem ──────────────────────────────────────────
                const Center(
                  child: AppLogo.hero(
                    size: 80,
                    withGlow: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),

                // ── 2. Academic Track Badge ──────────────────────────────────
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: branding.primaryColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                      border: Border.all(
                        color: branding.primaryColor.withValues(alpha: 0.45),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981), // Emerald indicator
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            branding.localizedAcademicTrack(context),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: branding.primaryLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),

                // ── 3. Brand Title & Welcoming Subtitle ────────────────────────
                Text(
                  branding.localizedBrandName(context),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  branding.localizedWelcomeMessage(context),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.s28),

                // ── 4. Email Field ───────────────────────────────────────────
                AppTextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  labelText: context.l10n.emailLabel,
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  validator: (val) {
                    if (val == null || !val.contains('@')) {
                      return context.l10n.pleaseEnterValidEmail;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s16),

                // ── 5. Password Field ────────────────────────────────────────
                AppTextField(
                  controller: _passwordController,
                  isPassword: true,
                  labelText: context.l10n.passwordLabel,
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  validator: (val) {
                    if (val == null || val.length < 6) {
                      return context.l10n.pleaseEnterPasswordMin;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s24),

                // ── 6. Primary Login Button ──────────────────────────────────
                AppButton(
                  text: context.l10n.loginButton,
                  isLoading: isLoading,
                  onPressed: _handleLogin,
                ),
                const SizedBox(height: AppSpacing.s20),

                // ── 7. Register Navigation Link ──────────────────────────────
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      context.l10n.newStudentCohortPrompt,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      style: TextButton.styleFrom(
                        enabledMouseCursor: SystemMouseCursors.click,
                      ),
                      onPressed: () => context.go(AppRoutes.registerStudent),
                      child: Text(
                        context.l10n.registerNewStudentLink,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: branding.primaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),

                // ── 8. Security Badge Note ───────────────────────────────────
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        size: 13,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          context.l10n.secureAcademicEncrypted,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
