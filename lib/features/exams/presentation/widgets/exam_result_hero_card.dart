import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';

/// Grade tier presentation model for academic performance classification
class ExamGradeTier {
  final String label;
  final Color color;
  final IconData icon;
  final String badgeText;

  const ExamGradeTier({
    required this.label,
    required this.color,
    required this.icon,
    required this.badgeText,
  });

  /// Factory computing the grade tier based on percentage and pass criteria
  static ExamGradeTier fromPercentage(
    BuildContext context, {
    required double percentage,
    required bool isPassed,
  }) {
    if (percentage >= 90) {
      return ExamGradeTier(
        label: context.l10n.performanceGradeExcellent,
        color: AppColors.success,
        icon: Icons.military_tech_rounded,
        badgeText: '90%+',
      );
    } else if (percentage >= 80) {
      return const ExamGradeTier(
        label: 'Very Good',
        color: Color(0xFF2563EB),
        icon: Icons.star_rounded,
        badgeText: '80%+',
      );
    } else if (percentage >= 70) {
      return const ExamGradeTier(
        label: 'Good',
        color: Color(0xFF0D9488),
        icon: Icons.thumb_up_alt_rounded,
        badgeText: '70%+',
      );
    } else if (isPassed) {
      return ExamGradeTier(
        label: context.l10n.performanceGradePass,
        color: AppColors.success,
        icon: Icons.check_circle_rounded,
        badgeText: 'PASS',
      );
    } else {
      return ExamGradeTier(
        label: context.l10n.performanceGradeNeedsImprovement,
        color: AppColors.error,
        icon: Icons.trending_up_rounded,
        badgeText: 'RETRY',
      );
    }
  }
}

/// Hero performance and verdict card displaying score, percentage, pass/fail state,
/// and grade tier badge.
class ExamResultHeroCard extends StatelessWidget {
  final String examTitle;
  final int score;
  final int maxScore;
  final double percentage;
  final bool isPassed;
  final int? passingScore;
  final ExamGradeTier? customGradeTier;

  const ExamResultHeroCard({
    super.key,
    required this.examTitle,
    required this.score,
    required this.maxScore,
    required this.percentage,
    required this.isPassed,
    this.passingScore,
    this.customGradeTier,
  });

  @override
  Widget build(BuildContext context) {
    final gradeTier = customGradeTier ??
        ExamGradeTier.fromPercentage(
          context,
          percentage: percentage,
          isPassed: isPassed,
        );

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        children: [
          // Top Icon & Grade Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: AppSpacing.s6,
                ),
                decoration: BoxDecoration(
                  color: gradeTier.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                    color: gradeTier.color.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      gradeTier.icon,
                      color: gradeTier.color,
                      size: 16,
                    ),
                    const SizedBox(width: AppSpacing.s6),
                    Text(
                      gradeTier.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: gradeTier.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),

          // Verdict Title
          Text(
            isPassed
                ? context.l10n.congratulationsPassed
                : context.l10n.sorryNotPassed,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: isPassed ? AppColors.success : AppColors.error,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),

          Text(
            examTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: AppSpacing.s20),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.s20),

          // Prominent Academic Score Typography
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  color: isPassed ? AppColors.success : AppColors.error,
                ),
              ),
              Text(
                ' / $maxScore',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.s4),

          // Percentage & Pass Status
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s4,
            ),
            decoration: BoxDecoration(
              color: (isPassed ? AppColors.success : AppColors.error)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            ),
            child: Text(
              context.l10n.percentageLabel(
                percentage.toStringAsFixed(1),
              ),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isPassed ? AppColors.success : AppColors.error,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.s16),

          // Linear Passing Indicator Bar
          if (passingScore != null) ...[
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (maxScore > 0 ? (score / maxScore) : 0.0)
                        .clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isPassed ? AppColors.success : AppColors.error,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.requiredPassingScore(
                        passingScore!,
                        maxScore,
                      ),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      context.l10n.passingThresholdLabel(
                        ((passingScore! / maxScore) * 100).round(),
                      ),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isPassed ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.s16),

          // Subtitle message (Guidance & next steps)
          Text(
            isPassed
                ? context.l10n.examPassedSubtitle
                : context.l10n.examFailedSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
