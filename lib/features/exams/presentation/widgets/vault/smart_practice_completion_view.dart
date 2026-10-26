import 'package:flutter/material.dart';
import 'package:edu_saas/core/extensions/localized_context_extension.dart';
import 'package:edu_saas/core/theme/app_colors.dart';
import 'package:edu_saas/core/theme/app_spacing.dart';
import 'package:edu_saas/core/widgets/app_button.dart';
import 'package:edu_saas/core/widgets/app_card.dart';

class SmartPracticeCompletionView extends StatelessWidget {
  final int totalReviewed;
  final VoidCallback onFinish;

  const SmartPracticeCompletionView({
    super.key,
    required this.totalReviewed,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                  ),
                  child: const Center(
                    child: Text('🎉', style: TextStyle(fontSize: 34)),
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
                Text(
                  context.l10n.practiceCompleteTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  context.l10n.practiceCompleteSubtitle(totalReviewed),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.s20),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: AppSpacing.s10),
                      Expanded(
                        child: Text(
                          context.l10n.practiceCompletedDueNotice,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s24),
                AppButton(
                  text: context.l10n.backToVaultAction,
                  icon: Icons.check_circle_rounded,
                  onPressed: onFinish,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
