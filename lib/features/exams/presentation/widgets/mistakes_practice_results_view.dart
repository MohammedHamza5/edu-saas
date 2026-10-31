import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../domain/entities/mistake_entities.dart';

class MistakesPracticeResultsView extends StatelessWidget {
  final MistakePracticeResultEntity result;
  final VoidCallback onRetake;

  const MistakesPracticeResultsView({
    super.key,
    required this.result,
    required this.onRetake,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isFullyPassed = result.correctCount == result.totalQuestions;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: ResponsiveContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Result Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.s32),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                border: Border.all(
                  color: isFullyPassed
                      ? AppColors.success.withValues(alpha: 0.5)
                      : AppColors.warning.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    isFullyPassed
                        ? Icons.celebration_rounded
                        : Icons.stars_rounded,
                    size: 64,
                    color: isFullyPassed ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Text(
                    l10n.practiceResultsTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    '${result.percentage.toStringAsFixed(0)}%',
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isFullyPassed ? AppColors.success : AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    isFullyPassed
                        ? l10n.practiceSuccessSummary(
                            result.correctCount,
                            result.totalQuestions,
                          )
                        : l10n.practicePartialSummary(result.correctCount),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s24),

            // Question Details Feedback
            Text(
              l10n.examResultsTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: result.results.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.s8),
              itemBuilder: (context, index) {
                final feedback = result.results[index];
                final isCorrect = feedback.isCorrect;

                return Container(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusMedium,
                    ),
                    border: Border.all(
                      color: isCorrect
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isCorrect
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: isCorrect ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(width: AppSpacing.s16),
                      Expanded(
                        child: Text(
                          '${l10n.questionProgressLabel(index + 1, result.totalQuestions)}: ${isCorrect ? l10n.statusMastered : l10n.statusNeedsReview}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                isCorrect ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.s32),

            // Actions
            ElevatedButton.icon(
              onPressed: () => context.go(AppRoutes.studentMistakes),
              icon: const Icon(Icons.arrow_back),
              label: Text(l10n.backToMistakesBank),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
              ),
            ),
            if (!isFullyPassed) ...[
              const SizedBox(height: AppSpacing.s8),
              OutlinedButton.icon(
                onPressed: onRetake,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.retakeMistakesPractice),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s48),
          ],
        ),
      ),
    );
  }
}
