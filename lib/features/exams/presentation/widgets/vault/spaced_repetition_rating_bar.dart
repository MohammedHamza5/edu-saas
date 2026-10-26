import 'package:flutter/material.dart';
import 'package:edu_saas/core/extensions/localized_context_extension.dart';
import 'package:edu_saas/core/theme/app_colors.dart';
import 'package:edu_saas/core/theme/app_spacing.dart';
import 'package:edu_saas/features/exams/domain/entities/question_difficulty_rating.dart';

class SpacedRepetitionRatingBar extends StatelessWidget {
  final ValueChanged<QuestionDifficultyRating> onRate;
  final VoidCallback onToggleMastered;
  final bool isMastered;

  const SpacedRepetitionRatingBar({
    super.key,
    required this.onRate,
    required this.onToggleMastered,
    required this.isMastered,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.l10n.rateDifficultyPrompt,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            InkWell(
              onTap: onToggleMastered,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isMastered ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                      size: 15,
                      color: isMastered ? AppColors.success : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.l10n.masteredBadge,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isMastered ? AppColors.success : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            Expanded(
              child: _RatingButton(
                title: context.l10n.rateHard1Day,
                color: AppColors.error,
                icon: Icons.repeat_one_rounded,
                onTap: () => onRate(QuestionDifficultyRating.hard),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: _RatingButton(
                title: context.l10n.rateMedium3Days,
                color: AppColors.warning,
                icon: Icons.update_rounded,
                onTap: () => onRate(QuestionDifficultyRating.medium),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: _RatingButton(
                title: context.l10n.rateEasy6Days,
                color: AppColors.success,
                icon: Icons.done_all_rounded,
                onTap: () => onRate(QuestionDifficultyRating.easy),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RatingButton extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _RatingButton({
    required this.title,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s10, horizontal: AppSpacing.s6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
