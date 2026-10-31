import 'package:flutter/material.dart';
import '../../../../../core/extensions/localized_context_extension.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_card.dart';
import '../../../../../core/widgets/app_text_field.dart';

class StudentSecuritySection extends StatefulWidget {
  final bool isChangingPassword;
  final Future<void> Function({required String newPassword}) onChangePassword;

  const StudentSecuritySection({
    super.key,
    required this.isChangingPassword,
    required this.onChangePassword,
  });

  @override
  State<StudentSecuritySection> createState() => _StudentSecuritySectionState();
}

class _StudentSecuritySectionState extends State<StudentSecuritySection> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.onChangePassword(newPassword: _passwordController.text.trim());
    if (mounted) {
      _passwordController.clear();
      _confirmPasswordController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      variant: AppCardVariant.standard,
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppColors.primaryLight,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.studentSecurityTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.studentSecuritySubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            const Divider(color: AppColors.border),
            const SizedBox(height: AppSpacing.s16),

            // New Password
            AppTextField(
              controller: _passwordController,
              label: context.l10n.studentNewPasswordLabel,
              isPassword: true,
              prefixIcon: const Icon(
                Icons.lock_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return context.l10n.studentPasswordRequired;
                }
                if (val.trim().length < 6) {
                  return context.l10n.studentPasswordTooShort;
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.s16),

            // Confirm New Password
            AppTextField(
              controller: _confirmPasswordController,
              label: context.l10n.studentConfirmPasswordLabel,
              isPassword: true,
              prefixIcon: const Icon(
                Icons.lock_clock_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return context.l10n.studentPasswordRequired;
                }
                if (val.trim() != _passwordController.text.trim()) {
                  return context.l10n.studentPasswordMismatch;
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.s24),

            // Action Button
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AppButton(
                text: context.l10n.studentChangePasswordBtn,
                icon: Icons.key_rounded,
                isLoading: widget.isChangingPassword,
                onPressed: widget.isChangingPassword ? null : _handleSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
