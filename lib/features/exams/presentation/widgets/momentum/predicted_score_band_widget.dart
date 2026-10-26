import 'package:flutter/material.dart';
import 'package:edu_saas/core/extensions/localized_context_extension.dart';
import 'package:edu_saas/core/theme/app_colors.dart';
import 'package:edu_saas/core/theme/app_spacing.dart';
import 'package:edu_saas/features/exams/domain/entities/academic_momentum_entity.dart';

class PredictedScoreBandWidget extends StatelessWidget {
  final AcademicMomentumEntity momentum;

  const PredictedScoreBandWidget({
    super.key,
    required this.momentum,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final hasPrediction = momentum.hasPredictedScore;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s10,
      ),
      decoration: BoxDecoration(
        color: hasPrediction
            ? const Color(0xFF4F46E5).withValues(alpha: 0.08)
            : AppColors.surfaceVariant.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(
          color: hasPrediction
              ? const Color(0xFF4F46E5).withValues(alpha: 0.25)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s8),
            decoration: BoxDecoration(
              color: hasPrediction
                  ? const Color(0xFF4F46E5).withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            ),
            child: Icon(
              Icons.track_changes_rounded,
              size: 20,
              color: hasPrediction ? const Color(0xFF4F46E5) : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.predictedSatScoreTitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: hasPrediction ? const Color(0xFF4F46E5) : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                if (hasPrediction)
                  Text(
                    l10n.predictedSatScoreBand(
                      momentum.predictedScoreLow!,
                      momentum.predictedScoreHigh!,
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF4F46E5),
                      letterSpacing: 0.5,
                    ),
                  )
                else
                  Text(
                    l10n.predictedSatScoreNeedsMore,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
