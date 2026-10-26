import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';

/// Card displaying the student's exam pacing analysis (Time-per-Question Radar).
class ExamPacingRadarCard extends StatelessWidget {
  final Map<String, int> questionTimes;
  final Set<String> flaggedGuesses;
  final int totalQuestions;

  const ExamPacingRadarCard({
    super.key,
    required this.questionTimes,
    this.flaggedGuesses = const {},
    required this.totalQuestions,
  });

  @override
  Widget build(BuildContext context) {
    if (questionTimes.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);

    // Calculate metrics
    final totalSecs = questionTimes.values.fold(0, (sum, t) => sum + t);
    final avgSecs = totalQuestions > 0 ? (totalSecs / totalQuestions).round() : 0;

    int fastCount = 0;
    int normalCount = 0;
    int slowCount = 0;

    for (final secs in questionTimes.values) {
      if (secs < 60) {
        fastCount++;
      } else if (secs <= 90) {
        normalCount++;
      } else {
        slowCount++;
      }
    }

    final totalTracked = questionTimes.length;
    final fastPct = totalTracked > 0 ? fastCount / totalTracked : 0.0;
    final normalPct = totalTracked > 0 ? normalCount / totalTracked : 0.0;
    final slowPct = totalTracked > 0 ? slowCount / totalTracked : 0.0;

    return AppCard(
      variant: AppCardVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: Icon(
                  Icons.speed_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.pacingRadarTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      l10n.pacingAvgPerQuestion(avgSecs),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    if (flaggedGuesses.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.flag_outlined, size: 12, color: AppColors.warning),
                            const SizedBox(width: 4),
                            Text(
                              '${flaggedGuesses.length} ${l10n.guessFlagLabel}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),

          // Pacing distribution bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (fastPct > 0)
                    Expanded(
                      flex: (fastPct * 100).round().clamp(1, 100),
                      child: Container(color: AppColors.success),
                    ),
                  if (normalPct > 0)
                    Expanded(
                      flex: (normalPct * 100).round().clamp(1, 100),
                      child: Container(color: AppColors.primary),
                    ),
                  if (slowPct > 0)
                    Expanded(
                      flex: (slowPct * 100).round().clamp(1, 100),
                      child: Container(color: AppColors.error),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),

          // Legend Wrap
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: AppSpacing.s6,
            spacing: AppSpacing.s8,
            children: [
              _buildLegend(l10n.pacingFast, fastCount, AppColors.success),
              _buildLegend(l10n.pacingNormal, normalCount, AppColors.primary),
              _buildLegend(l10n.pacingSlow, slowCount, AppColors.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$label ($count)',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
