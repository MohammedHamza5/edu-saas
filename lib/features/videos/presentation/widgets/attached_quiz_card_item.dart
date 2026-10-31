import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../content/domain/entities/attached_lesson_exam_entity.dart';
import '../../../exams/domain/entities/exam_entity.dart';

/// Card item displaying an individual quiz attached to a video lesson
class AttachedQuizCardItem extends StatelessWidget {
  final AttachedLessonExamEntity attached;
  final ExamEntity? examDetails;
  final bool isVideoCompleted;
  final void Function(String examId) onOpenQuizResult;
  final void Function(String examId) onStartLessonQuiz;

  const AttachedQuizCardItem({
    super.key,
    required this.attached,
    required this.examDetails,
    required this.isVideoCompleted,
    required this.onOpenQuizResult,
    required this.onStartLessonQuiz,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final latestAttempt = examDetails?.myLatestAttempt;
    final passingScore =
        (examDetails?.passingScore != null && examDetails!.passingScore! > 0)
            ? examDetails!.passingScore!
            : attached.passingScore;
    final isSubmitted = latestAttempt != null && latestAttempt.isSubmitted;
    final isPassed =
        (isSubmitted && latestAttempt.isPassed(passingScore)) ||
            attached.isPassed;
    final isFailed = isSubmitted && !isPassed;
    final scorePct =
        latestAttempt?.percentage?.toInt() ?? attached.bestScore?.toInt();
    final resolvedQuestionsCount =
        (examDetails != null && examDetails!.totalQuestions > 0)
            ? examDetails!.totalQuestions
            : attached.questionsCount;
    final quizTitle = (examDetails?.title.isNotEmpty == true)
        ? examDetails!.title
        : (attached.examTitle.isNotEmpty
            ? attached.examTitle
            : l10n.associatedExamBadge);

    Color itemColor;
    if (isPassed) {
      itemColor = AppColors.success;
    } else if (isFailed) {
      itemColor = AppColors.error;
    } else if (isVideoCompleted) {
      itemColor = AppColors.primary;
    } else {
      itemColor = AppColors.textMuted;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s10),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withAlpha(25),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: itemColor.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: itemColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: Icon(
                  isPassed
                      ? Icons.verified_rounded
                      : isFailed
                          ? Icons.cancel_rounded
                          : isVideoCompleted
                              ? Icons.quiz_rounded
                              : Icons.lock_rounded,
                  size: 20,
                  color: itemColor,
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            quizTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: attached.isRequired
                                ? AppColors.error.withAlpha(20)
                                : AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusFull,
                            ),
                            border: Border.all(
                              color: attached.isRequired
                                  ? AppColors.error.withAlpha(50)
                                  : AppColors.primary.withAlpha(50),
                            ),
                          ),
                          child: Text(
                            attached.isRequired
                                ? l10n.requiredForProgression
                                : l10n.optionalPractice,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: attached.isRequired
                                  ? AppColors.error
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          resolvedQuestionsCount > 0
                              ? '$resolvedQuestionsCount ${l10n.questions} · ${l10n.passingScoreTitle}: $passingScore%'
                              : '${l10n.passingScoreTitle}: $passingScore%',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (scorePct != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '· ${l10n.quizScoreBadge(scorePct)}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isPassed
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),
          // Action button per quiz
          if (isPassed) ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.fact_check_outlined, size: 14),
              label: Text(
                l10n.viewExamResultAction,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 12,
                ),
                minimumSize: const Size.fromHeight(32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
              ),
              onPressed: () => onOpenQuizResult(attached.examId),
            ),
            if (examDetails?.allowRetake == true) ...[
              const SizedBox(height: 6),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: Text(
                  l10n.retryLessonQuizAction,
                  style: const TextStyle(fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 12,
                  ),
                  minimumSize: const Size.fromHeight(32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  ),
                ),
                onPressed: () => onStartLessonQuiz(attached.examId),
              ),
            ],
          ] else if (isFailed) ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: Text(
                l10n.retryLessonQuizAction,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 12,
                ),
                minimumSize: const Size.fromHeight(32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
              ),
              onPressed: () => onStartLessonQuiz(attached.examId),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              icon: const Icon(Icons.fact_check_outlined, size: 14),
              label: Text(
                l10n.viewExamResultAction,
                style: const TextStyle(fontSize: 11),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 12,
                ),
                minimumSize: const Size.fromHeight(32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
              ),
              onPressed: () => onOpenQuizResult(attached.examId),
            ),
          ] else ...[
            ElevatedButton.icon(
              icon: Icon(
                isVideoCompleted
                    ? Icons.play_arrow_rounded
                    : Icons.lock_outline_rounded,
                size: 14,
              ),
              label: Text(
                isVideoCompleted
                    ? l10n.takeLessonQuizAction
                    : l10n.completeVideoToUnlockQuiz,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isVideoCompleted
                    ? AppColors.primary
                    : AppColors.surfaceVariant,
                foregroundColor:
                    isVideoCompleted ? Colors.white : AppColors.textMuted,
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 12,
                ),
                minimumSize: const Size.fromHeight(32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
              ),
              onPressed: isVideoCompleted
                  ? () => onStartLessonQuiz(attached.examId)
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}
