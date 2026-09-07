import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n != null ? l10n.loginTitle : 'Login'),
      ),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            final targetRoute = switch (state.user.role) {
              UserRole.teacher => AppRouter.teacherDashboard,
              UserRole.parent => AppRouter.parentDashboard,
              UserRole.student => AppRouter.studentDashboard,
            };
            context.go(targetRoute);
          } else if (state is AuthPendingApproval) {
            context.go(AppRouter.studentPending, extra: state.user.fullName);
          } else if (state is AuthTenantSuspended) {
            context.go(AppRouter.tenantSuspended);
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.s24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              '∑',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        Text(
                          l10n != null ? l10n.loginTitle : 'تسجيل الدخول',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s24),
                        AppTextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          labelText: l10n != null ? l10n.emailLabel : 'البريد الإلكتروني',
                          prefixIcon: const Icon(Icons.email_outlined, size: 20),
                          validator: (val) {
                            if (val == null || !val.contains('@')) {
                              return 'يرجى إدخال بريد إلكتروني صحيح';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        AppTextField(
                          controller: _passwordController,
                          isPassword: true,
                          labelText: l10n != null ? l10n.passwordLabel : 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          validator: (val) {
                            if (val == null || val.length < 6) {
                              return 'يرجى إدخال كلمة المرور (6 أحرف على الأقل)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.s24),
                        AppButton(
                          text: l10n != null ? l10n.loginButton : 'دخول',
                          isLoading: isLoading,
                          onPressed: _handleLogin,
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        TextButton(
                          onPressed: () {
                            context.go(AppRouter.registerStudent);
                          },
                          child: const Text('طالب جديد؟ أنشئ حسابك الآن'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
