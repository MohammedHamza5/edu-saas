import 'package:flutter/material.dart';
import 'package:edu_saas/core/extensions/localized_context_extension.dart';
import 'package:edu_saas/core/theme/app_colors.dart';
import 'package:edu_saas/core/theme/app_spacing.dart';
import 'package:edu_saas/features/exams/domain/entities/saved_question_entity.dart';

class AnkiDifficultySelector extends StatelessWidget {
  final ValueChanged<QuestionDifficultyRating> onRatingSelected;

  const AnkiDifficultySelector({
    super.key,
    required this.onRatingSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.difficultyRatingTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          alignment: WrapAlignment.center,
          children: [
            _buildRatingButton(
              context,
              rating: QuestionDifficultyRating.easy,
              label: context.l10n.difficultyEasy,
              subtitle: context.l10n.difficultyEasyDesc,
              color: AppColors.success,
              icon: Icons.check_circle_outline_rounded,
            ),
            _buildRatingButton(
              context,
              rating: QuestionDifficultyRating.medium,
              label: context.l10n.difficultyMedium,
              subtitle: context.l10n.difficultyMediumDesc,
              color: AppColors.warning,
              icon: Icons.hourglass_empty_rounded,
            ),
            _buildRatingButton(
              context,
              rating: QuestionDifficultyRating.hard,
              label: context.l10n.difficultyHard,
              subtitle: context.l10n.difficultyHardDesc,
              color: AppColors.error,
              icon: Icons.replay_rounded,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingButton(
    BuildContext context, {
    required QuestionDifficultyRating rating,
    required String label,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return InkWell(
      onTap: () => onRatingSelected(rating),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      child: Container(
        constraints: const BoxConstraints(minWidth: 100, maxWidth: 140),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s10,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: AppSpacing.s4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
