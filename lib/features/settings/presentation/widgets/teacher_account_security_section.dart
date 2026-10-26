import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/config/tenant_resolver.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import 'settings_section_card.dart';

/// Section for Teacher Account and Security preferences
/// (Profile metadata, password reset trigger, and session sign-out).
class TeacherAccountSecuritySection extends StatelessWidget {
  const TeacherAccountSecuritySection({super.key});

  void _showPasswordResetDialog(BuildContext context) {
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
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
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
    final l10n = context.l10n;
    final currentUser = SupabaseService.currentUser;

    return SettingsSectionCard(
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
                      currentUser?.userMetadata?['full_name'] as String? ??
                          TenantResolver.resolveBranding().teacherName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentUser?.email ??
                          (TenantResolver.resolveBranding().supportEmail ?? ''),
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
                onPressed: () => _showPasswordResetDialog(context),
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
                icon: const Icon(
                  Icons.logout_rounded,
                  size: 18,
                  color: AppColors.error,
                ),
                label: Text(
                  l10n.settingsSignOutBtn,
                  style: const TextStyle(color: AppColors.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.4),
                  ),
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
    );
  }
}
