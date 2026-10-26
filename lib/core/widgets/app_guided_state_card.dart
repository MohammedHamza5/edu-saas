import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';
import 'app_card.dart';

enum GuidedStateVariant { info, warning, success, neutral }

/// 🧭 AppGuidedStateCard — Dignified Academic Guided State Presentation Card.
///
/// Eliminates confusing blank screens, silent dead-ends, and unhandled boundary
/// states across exams, lectures, assignments, and onboarding.
class AppGuidedStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final GuidedStateVariant variant;
  final Widget? detailsBox;
  final String? primaryActionText;
  final IconData? primaryActionIcon;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionText;
  final IconData? secondaryActionIcon;
  final VoidCallback? onSecondaryAction;
  final bool isCompact;

  const AppGuidedStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.variant = GuidedStateVariant.info,
    this.detailsBox,
    this.primaryActionText,
    this.primaryActionIcon,
    this.onPrimaryAction,
    this.secondaryActionText,
    this.secondaryActionIcon,
    this.onSecondaryAction,
    this.isCompact = false,
  });

  Color _tintColor() {
    switch (variant) {
      case GuidedStateVariant.success:
        return AppColors.success;
      case GuidedStateVariant.warning:
        return AppColors.warning;
      case GuidedStateVariant.info:
        return AppColors.primary;
      case GuidedStateVariant.neutral:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tint = _tintColor();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: AppCard(
            padding: EdgeInsets.all(isCompact ? AppSpacing.s16 : AppSpacing.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(isCompact ? AppSpacing.s12 : AppSpacing.s16),
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: tint, size: isCompact ? 36 : 48),
                ),
                SizedBox(height: isCompact ? AppSpacing.s12 : AppSpacing.s16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isCompact ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  ),
                ),
                if (detailsBox != null) ...[
                  const SizedBox(height: AppSpacing.s16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF27272A) : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.border,
                      ),
                    ),
                    child: detailsBox!,
                  ),
                ],
                if (onPrimaryAction != null || onSecondaryAction != null) ...[
                  SizedBox(height: isCompact ? AppSpacing.s16 : AppSpacing.s24),
                  if (onPrimaryAction != null && primaryActionText != null) ...[
                    AppButton(
                      text: primaryActionText!,
                      icon: primaryActionIcon,
                      onPressed: onPrimaryAction,
                      variant: AppButtonVariant.primary,
                    ),
                  ],
                  if (onSecondaryAction != null && secondaryActionText != null) ...[
                    const SizedBox(height: AppSpacing.s10),
                    AppButton(
                      text: secondaryActionText!,
                      icon: secondaryActionIcon,
                      onPressed: onSecondaryAction,
                      variant: AppButtonVariant.secondary,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
