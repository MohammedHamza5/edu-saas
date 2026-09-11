import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/tenant_registry.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/localization/locale_cubit.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/tenant_branding.dart';
import '../../../../core/theme/tenant_theme_cubit.dart';
import '../../../../core/widgets/academic_hero_banner.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';

/// صفحة إعدادات المنصة والأكاديمية للمعلم (Teacher & Academy Settings)
/// مخصصة لإدارة بيانات الأكاديمية، لغة المنصة، وبيانات حساب المعلم.
/// ملتزمة بقاعدة "ثيم أكاديمي موحد واحد فقط" دون خيارات تبديل ثيمات أو دارك مود.
class TeacherSettingsPage extends StatefulWidget {
  const TeacherSettingsPage({super.key});

  @override
  State<TeacherSettingsPage> createState() => _TeacherSettingsPageState();
}

class _TeacherSettingsPageState extends State<TeacherSettingsPage> {
  late final TextEditingController _academyNameController;
  late final TextEditingController _subjectController;
  late final TextEditingController _taglineController;
  late final TextEditingController _supportPhoneController;
  late final TextEditingController _supportEmailController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final branding = TenantRegistry.defaultBranding;

    _academyNameController = TextEditingController(text: branding.brandName);
    _subjectController = TextEditingController(text: branding.subjectTitle);
    _taglineController = TextEditingController(text: branding.tagline);
    _supportPhoneController = TextEditingController(text: branding.supportPhone ?? '');
    _supportEmailController = TextEditingController(text: branding.supportEmail ?? '');
  }

  @override
  void dispose() {
    _academyNameController.dispose();
    _subjectController.dispose();
    _taglineController.dispose();
    _supportPhoneController.dispose();
    _supportEmailController.dispose();
    super.dispose();
  }

  void _handleSaveAcademyProfile() {
    setState(() => _isSaving = true);

    final currentBranding = TenantRegistry.defaultBranding;
    final updatedBranding = TenantBranding.fromPrimary(
      tenantId: currentBranding.tenantId,
      brandName: _academyNameController.text.trim(),
      brandNameEn: currentBranding.brandNameEn,
      teacherName: currentBranding.teacherName,
      teacherNameEn: currentBranding.teacherNameEn,
      subjectTitle: _subjectController.text.trim(),
      subjectTitleEn: currentBranding.subjectTitleEn,
      academicTrack: currentBranding.academicTrack,
      academicTrackEn: currentBranding.academicTrackEn,
      tagline: _taglineController.text.trim(),
      taglineEn: currentBranding.taglineEn,
      primaryColor: currentBranding.primaryColor,
      supportPhone: _supportPhoneController.text.trim(),
      supportEmail: _supportEmailController.text.trim(),
    );

    // Register in tenant registry and update theme cubit
    TenantRegistry.register(updatedBranding);
    try {
      context.read<TenantThemeCubit>().setBranding(updatedBranding);
    } catch (_) {}

    setState(() => _isSaving = false);

    if (mounted) {
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr ? 'تم حفظ وتحديث بيانات الأكاديمية بنجاح' : 'Academy profile updated successfully',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPasswordResetDialog() {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final userEmail = SupabaseService.currentUser?.email ?? '';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock_reset_rounded, color: AppColors.primary),
            const SizedBox(width: AppSpacing.s8),
            Text(isAr ? 'تغيير كلمة المرور' : 'Change Password'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${isAr ? 'بريد الحساب' : 'Account Email'}: $userEmail',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              isAr
                  ? 'سيتم إرسال رابط تعيين كلمة المرور الجديدة إلى بريدك الإلكتروني.'
                  : 'A password reset link will be sent to your registered email address.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          AppButton(
            text: isAr ? 'إرسال الرابط' : 'Send Link',
            onPressed: () {
              Navigator.of(ctx).pop();
              if (userEmail.isNotEmpty) {
                context.read<AuthCubit>().resetPassword(userEmail);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isAr
                          ? 'تم إرسال رابط إعادة التعيين بنجاح'
                          : 'Password reset email sent successfully',
                    ),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final currentUser = SupabaseService.currentUser;
    final currentLocale = Localizations.localeOf(context);
    final isAr = currentLocale.languageCode == 'ar';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          l10n.settingsTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: isAr ? 'رجوع' : 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRouter.teacherDashboard);
            }
          },
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s20,
          vertical: AppSpacing.s16,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Academic Hero Banner
                AcademicHeroBanner(
                  title: l10n.settingsTitle,
                  subtitle: l10n.settingsSubtitle,
                  trailing: Container(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.settings_suggest_rounded,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s24),

                // 2. Section: Academy & Platform Profile
                _buildSectionCard(
                  context,
                  title: l10n.settingsAcademySection,
                  icon: Icons.school_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        label: l10n.settingsAcademyNameLabel,
                        controller: _academyNameController,
                        prefixIcon: const Icon(Icons.business_rounded, size: 20),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppTextField(
                        label: l10n.settingsSubjectLabel,
                        controller: _subjectController,
                        prefixIcon: const Icon(Icons.menu_book_rounded, size: 20),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppTextField(
                        label: l10n.settingsTaglineLabel,
                        controller: _taglineController,
                        prefixIcon: const Icon(Icons.stars_rounded, size: 20),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              label: l10n.settingsSupportPhoneLabel,
                              controller: _supportPhoneController,
                              prefixIcon: const Icon(Icons.phone_rounded, size: 20),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s16),
                          Expanded(
                            child: AppTextField(
                              label: l10n.settingsSupportEmailLabel,
                              controller: _supportEmailController,
                              prefixIcon: const Icon(Icons.email_rounded, size: 20),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s20),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: AppButton(
                          text: isAr ? 'حفظ التعديلات' : 'Save Changes',
                          icon: Icons.check_circle_outline_rounded,
                          isLoading: _isSaving,
                          onPressed: _handleSaveAcademyProfile,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s24),

                // 3. Section: Language Preference (Arabic / English)
                _buildSectionCard(
                  context,
                  title: l10n.settingsLanguageSection,
                  icon: Icons.translate_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.settingsLanguageDesc,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildLanguageOptionCard(
                              context,
                              langCode: 'ar',
                              langName: l10n.settingsLangArabic,
                              subtitle: 'العربية (من اليمين لليسار)',
                              isSelected: currentLocale.languageCode == 'ar',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s16),
                          Expanded(
                            child: _buildLanguageOptionCard(
                              context,
                              langCode: 'en',
                              langName: l10n.settingsLangEnglish,
                              subtitle: 'English (Left-to-Right)',
                              isSelected: currentLocale.languageCode == 'en',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s24),

                // 4. Section: Teacher Account & Security
                _buildSectionCard(
                  context,
                  title: l10n.settingsAccountSection,
                  icon: Icons.admin_panel_settings_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                            child: const Text(
                              '∑',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  TenantRegistry.defaultBranding.teacherName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currentUser?.email ?? (TenantRegistry.defaultBranding.supportEmail ?? ''),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s20),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: AppSpacing.s16),
                      Wrap(
                        spacing: AppSpacing.s16,
                        runSpacing: AppSpacing.s12,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _showPasswordResetDialog,
                            icon: const Icon(Icons.lock_outline_rounded, size: 18),
                            label: Text(l10n.settingsChangePasswordBtn),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.borderDark),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s16,
                                vertical: AppSpacing.s12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => context.read<AuthCubit>().logout(),
                            icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
                            label: Text(
                              l10n.settingsSignOutBtn,
                              style: const TextStyle(color: AppColors.error),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s16,
                                vertical: AppSpacing.s12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return AppCard(
      variant: AppCardVariant.standard,
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: AppSpacing.s12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          const Divider(color: AppColors.border),
          const SizedBox(height: AppSpacing.s16),
          child,
        ],
      ),
    );
  }

  Widget _buildLanguageOptionCard(
    BuildContext context, {
    required String langCode,
    required String langName,
    required String subtitle,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        context.read<LocaleCubit>().setLocale(Locale(langCode));
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderDark,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    langName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
