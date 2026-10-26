import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/exam_entity.dart';

/// Metrics component for student exam cards displaying:
/// 1. Solved questions progress bar & completion percentage.
/// 2. Clean unified metadata bar (Duration, Max Score, Passing Score).
class ExamCardStudentMetrics extends StatelessWidget {
  final ExamEntity exam;
  final Color themeColor;

  const ExamCardStudentMetrics({
    super.key,
    required this.exam,
    required this.themeColor,
  });

  Widget _buildQuestionsProgress(BuildContext context) {
    final total = exam.totalQuestions;
    final solved = exam.solvedQuestionsCount;
    final progress = exam.completionProgress;
    final isCompleted = exam.isFullyCompleted;
    final isInProgress = exam.hasActiveAttempt;

    final Color progressColor = isCompleted
        ? AppColors.success
        : (isInProgress
            ? AppColors.warning
            : Theme.of(context).colorScheme.primary);

    final String progressText = isCompleted
        ? (total > 0 && solved >= total
            ? context.l10n.examQuestionsAllSolved(total)
            : context.l10n.examQuestionsSolvedProgress(solved, total))
        : (isInProgress
            ? context.l10n.examQuestionsSolvedProgress(solved, total)
            : context.l10n.examNotStartedYet(total));

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: progressColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: progressColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      isCompleted
                          ? Icons.check_circle_rounded
                          : (isInProgress
                              ? Icons.pending_actions_rounded
                              : Icons.quiz_outlined),
                      size: 15,
                      color: progressColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        progressText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: progressColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: progressColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s10,
        vertical: AppSpacing.s6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // 1. Duration
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 13,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  exam.isUntimed
                      ? context.l10n.unlimitedTime
                      : context.l10n.minutesDuration(exam.durationMinutes),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            Container(width: 1, height: 12, color: AppColors.border),
            // 2. Max Score
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.grade_outlined,
                  size: 13,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  context.l10n.scorePoints(exam.maxScore),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            if (exam.passingScore != null) ...[
              Container(width: 1, height: 12, color: AppColors.border),
              // 3. Passing Score
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_outlined,
                    size: 13,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${context.l10n.passingScoreLabel}: ${exam.passingScore}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Questions progress bar & counters
        _buildQuestionsProgress(context),
        const SizedBox(height: AppSpacing.s8),

        // Clean unified meta metrics bar (Questions • Duration • Score)
        _buildMetaBar(context),
      ],
    );
  }
}
