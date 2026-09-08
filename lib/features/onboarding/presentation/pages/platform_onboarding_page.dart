import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/provision_tenant_params.dart';
import '../cubit/onboarding_cubit.dart';
import '../cubit/onboarding_state.dart';

class PlatformOnboardingPage extends StatefulWidget {
  const PlatformOnboardingPage({super.key});

  @override
  State<PlatformOnboardingPage> createState() => _PlatformOnboardingPageState();
}

class _PlatformOnboardingPageState extends State<PlatformOnboardingPage> {
  final _formKey = GlobalKey<FormState>();

  // Tenant Controllers
  final _tenantNameController = TextEditingController();
  final _tenantEmailController = TextEditingController();
  final _tenantPhoneController = TextEditingController();
  final _logoUrlController = TextEditingController();

  // Teacher Controllers
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
      tenantEmail: _tenantEmailController.text.trim().isNotEmpty
          ? _tenantEmailController.text.trim()
          : null,
      tenantPhone: _tenantPhoneController.text.trim().isNotEmpty
          ? _tenantPhoneController.text.trim()
          : null,
      logoUrl: _logoUrlController.text.trim().isNotEmpty
          ? _logoUrlController.text.trim()
          : null,
      teacherFullName: _teacherNameController.text.trim(),
      teacherEmail: _teacherEmailController.text.trim(),
      teacherPassword: _teacherPasswordController.text,
      teacherPhone: _teacherPhoneController.text.trim().isNotEmpty
          ? _teacherPhoneController.text.trim()
          : null,
    );

    context.read<OnboardingCubit>().provisionTenant(params);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تهيئة مركز تعليمي جديد'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(AppRouter.login),
        ),
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
                const Text(
                  'تمت تهيئة المركز وحساب المعلم بنجاح!',
                  style: TextStyle(
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
                      _buildInfoRow('اسم المركز:', tenant.name),
                      const SizedBox(height: AppSpacing.s8),
                      _buildInfoRow('معرّف المركز (Tenant ID):', tenant.id),
                      const SizedBox(height: AppSpacing.s8),
                      _buildInfoRow('المعلم المسؤول:', teacher.fullName),
                      const SizedBox(height: AppSpacing.s8),
                      _buildInfoRow('البريد الإلكتروني:', teacher.email),
                      const SizedBox(height: AppSpacing.s8),
                      _buildInfoRow('الحالة:', 'نشط وجاهز للعمل'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s24),
                AppButton(
                  text: 'الانتقال لتسجيل الدخول كمعلم',
                  onPressed: () => context.go(AppRouter.login),
                ),
                const SizedBox(height: AppSpacing.s12),
                TextButton(
                  onPressed: () =>
                      context.read<OnboardingCubit>().reset(),
                  child: const Text('تهيئة مركز تعليمي آخر'),
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
                              'بيانات المركز التعليمي (Tenant)',
                              style: AppTypography.textTheme.headlineSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppTextField(
                        controller: _tenantNameController,
                        labelText: 'اسم المركز أو الأكاديمية *',
                        hintText: 'مثال: أكاديمية النور للرياضيات',
                        prefixIcon: const Icon(Icons.school_outlined),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'يرجى إدخال اسم المركز التعليمي';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppTextField(
                        controller: _tenantEmailController,
                        labelText: 'البريد الإلكتروني للمركز (اختياري)',
                        hintText: 'info@academy.edu',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppTextField(
                        controller: _tenantPhoneController,
                        labelText: 'رقم هاتف المركز (اختياري)',
                        hintText: '01000000000',
                        keyboardType: TextInputType.phone,
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppTextField(
                        controller: _logoUrlController,
                        labelText: 'رابط الشعار Logo URL (اختياري)',
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
                      const Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primaryLight,
                            child: Icon(Icons.person_outline_rounded,
                                color: AppColors.primary, size: 20),
                          ),
                          SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: Text(
                              'بيانات حساب المعلم الأول',
                              style: TextStyle(
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
                        labelText: 'الاسم الكامل للمعلم *',
                        hintText: 'د. أحمد المنشاوي',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'يرجى إدخال اسم المعلم';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppTextField(
                        controller: _teacherEmailController,
                        labelText: 'البريد الإلكتروني لتسجيل الدخول *',
                        hintText: 'teacher@academy.edu',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(Icons.alternate_email_rounded),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'يرجى إدخال البريد الإلكتروني';
                          }
                          if (!val.contains('@')) {
                            return 'يرجى إدخال بريد إلكتروني صحيح';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppTextField(
                        controller: _teacherPasswordController,
                        labelText: 'كلمة المرور *',
                        hintText: '••••••••',
                        isPassword: true,
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        validator: (val) {
                          if (val == null || val.length < 6) {
                            return 'كلمة المرور يجب ألا تقل عن 6 أحرف';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppTextField(
                        controller: _teacherPhoneController,
                        labelText: 'رقم هاتف المعلم (اختياري)',
                        hintText: '01012345678',
                        keyboardType: TextInputType.phone,
                        prefixIcon: const Icon(Icons.smartphone_rounded),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.s24),

                AppButton(
                  text: 'إنشاء وتهيئة المركز التعليمي',
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
