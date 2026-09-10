import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/language_switcher_button.dart';
import '../../domain/entities/provision_tenant_params.dart';
import '../cubit/onboarding_cubit.dart';
import '../cubit/onboarding_state.dart';

class PlatformOnboardingPage extends StatelessWidget {
  const PlatformOnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      context.read<OnboardingCubit>();
      return const _PlatformOnboardingView();
    } catch (_) {
      return BlocProvider<OnboardingCubit>(
        create: (_) => InjectionContainer.createOnboardingCubit(),
        child: const _PlatformOnboardingView(),
      );
    }
  }
}

class _PlatformOnboardingView extends StatefulWidget {
  const _PlatformOnboardingView();

  @override
  State<_PlatformOnboardingView> createState() => _PlatformOnboardingViewState();
}

class _PlatformOnboardingViewState extends State<_PlatformOnboardingView> {
  final _formKey = GlobalKey<FormState>();

  final _tenantNameController = TextEditingController();
  final _tenantEmailController = TextEditingController();
  final _tenantPhoneController = TextEditingController();
  final _logoUrlController = TextEditingController();

  final _teacherNameController = TextEditingController();
  final _teacherEmailController = TextEditingController();
  final _teacherPasswordController = TextEditingController();
  final _teacherPhoneController = TextEditingController();

  @override
  void dispose() {
    _tenantNameController.dispose();
    _tenantEmailController.dispose();
    _tenantPhoneController.dispose();
    _logoUrlController.dispose();
    _teacherNameController.dispose();
    _teacherEmailController.dispose();
    _teacherPasswordController.dispose();
    _teacherPhoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final params = ProvisionTenantParams(
      tenantName: _tenantNameController.text.trim(),
      tenantEmail: _tenantEmailController.text.trim().isEmpty
          ? null
          : _tenantEmailController.text.trim(),
      tenantPhone: _tenantPhoneController.text.trim().isEmpty
          ? null
          : _tenantPhoneController.text.trim(),
      logoUrl: _logoUrlController.text.trim().isEmpty
          ? null
          : _logoUrlController.text.trim(),
      teacherFullName: _teacherNameController.text.trim(),
      teacherEmail: _teacherEmailController.text.trim(),
      teacherPassword: _teacherPasswordController.text,
      teacherPhone: _teacherPhoneController.text.trim().isEmpty
          ? null
          : _teacherPhoneController.text.trim(),
    );

    context.read<OnboardingCubit>().provisionTenant(params);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.provisionNewCenter),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(AppRouter.login),
        ),
        actions: const [
          LanguageSwitcherButton(compact: true),
          SizedBox(width: AppSpacing.s8),
        ],
      ),
      body: BlocConsumer<OnboardingCubit, OnboardingState>(
        listener: (context, state) {
          if (state is OnboardingError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is OnboardingLoading) {
            return AppLoadingView(message: state.message);
          }

          if (state is OnboardingSuccess) {
            return _buildSuccessView(context, state);
          }

          return _buildFormView(context, state);
        },
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context, OnboardingSuccess state) {
    final tenant = state.result.tenant;
    final teacher = state.result.teacher;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.success.withValues(alpha: 0.12),
                  child: const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 44),
                ),
                const SizedBox(height: AppSpacing.s16),
                Text(
                  context.l10n.centerProvisionedSuccess,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s16),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMedium),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(context.l10n.centerNameLabel2, tenant.name),
                      const SizedBox(height: AppSpacing.s8),
                      _buildInfoRow(context.l10n.tenantIdLabel, tenant.id),
                      const SizedBox(height: AppSpacing.s8),
                      _buildInfoRow(context.l10n.leadTeacherLabel, teacher.fullName),
                      const SizedBox(height: AppSpacing.s8),
                      _buildInfoRow(context.l10n.emailLabel, teacher.email),
                      const SizedBox(height: AppSpacing.s8),
                      _buildInfoRow(context.l10n.status, context.l10n.activeAndReadyStatus),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s24),
                AppButton(
                  text: context.l10n.goToTeacherLogin,
                  onPressed: () => context.go(AppRouter.login),
                ),
                const SizedBox(height: AppSpacing.s12),
                TextButton(
                  onPressed: () =>
                      context.read<OnboardingCubit>().reset(),
                  child: Text(context.l10n.provisionAnotherCenter),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormView(BuildContext context, OnboardingState state) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state is OnboardingError) ...[
                  AppErrorView(
                    message: state.message,
                    onRetry: _submit,
                  ),
                  const SizedBox(height: AppSpacing.s16),
                ],

                // Section 1: Tenant Information
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primaryLight,
                            child: Icon(Icons.business_rounded,
                                color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: Text(
                              context.l10n.centerDataHeader,
                              style: AppTypography.textTheme.headlineSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppTextField(
                        controller: _tenantNameController,
                        labelText: context.l10n.centerNameRequired,
                        hintText: context.l10n.tenantNameHint,
                        prefixIcon: const Icon(Icons.school_outlined),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return context.l10n.centerNameRequiredError;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppTextField(
                        controller: _tenantEmailController,
                        labelText: context.l10n.centerEmailOptional,
                        hintText: 'info@academy.edu',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppTextField(
                        controller: _tenantPhoneController,
                        labelText: context.l10n.centerPhoneOptional,
                        hintText: '01000000000',
                        keyboardType: TextInputType.phone,
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppTextField(
                        controller: _logoUrlController,
                        labelText: context.l10n.centerLogoUrlOptional,
                        hintText: 'https://example.com/logo.png',
                        prefixIcon: const Icon(Icons.image_outlined),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.s20),

                // Section 2: Teacher Credentials
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primaryLight,
                            child: Icon(Icons.person_outline_rounded,
                                color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: Text(
                              context.l10n.leadTeacherDataHeader,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppTextField(
                        controller: _teacherNameController,
                        labelText: context.l10n.leadTeacherNameRequired,
                        hintText: context.l10n.teacherNameHint,
                        prefixIcon: const Icon(Icons.badge_outlined),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return context.l10n.leadTeacherNameRequiredError;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppTextField(
                        controller: _teacherEmailController,
                        labelText: context.l10n.leadTeacherEmailRequired,
                        hintText: 'teacher@academy.edu',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(Icons.alternate_email_rounded),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return context.l10n.leadTeacherEmailRequiredError;
                          }
                          if (!val.contains('@')) {
                            return context.l10n.pleaseEnterValidEmail;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppTextField(
                        controller: _teacherPasswordController,
                        labelText: context.l10n.leadTeacherPasswordRequired,
                        hintText: '••••••••',
                        isPassword: true,
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        validator: (val) {
                          if (val == null || val.length < 6) {
                            return context.l10n.leadTeacherPasswordRequiredError;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppTextField(
                        controller: _teacherPhoneController,
                        labelText: context.l10n.leadTeacherPhoneOptional,
                        hintText: '01012345678',
                        keyboardType: TextInputType.phone,
                        prefixIcon: const Icon(Icons.smartphone_rounded),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.s24),

                AppButton(
                  text: context.l10n.createAndProvisionCenter,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
