import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/exam_entity.dart';

/// Status badge displayed on top of the ExamCard, reflecting published/draft state for teachers
/// and completed/in-progress/available status for students.
class ExamCardStatusBadge extends StatelessWidget {
  final ExamEntity exam;
  final bool isTeacher;
  final VoidCallback? onPublish;

  const ExamCardStatusBadge({
    super.key,
    required this.exam,
    required this.isTeacher,
    this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    if (isTeacher) {
      final isPublished = exam.isPublished;
      final badgeContent = Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: (isPublished ? AppColors.success : AppColors.warning)
              .withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isPublished) ...[
              const Icon(
                Icons.cloud_upload_outlined,
                size: 11,
                color: AppColors.warning,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              isPublished
                  ? context.l10n.publishedBadge
                  : context.l10n.draftBadge,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isPublished ? AppColors.success : AppColors.warning,
              ),
            ),
          ],
        ),
      );

      if (!isPublished && onPublish != null) {
        return InkWell(
          onTap: onPublish,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          child: Tooltip(
            message: context.l10n.publishCurrentDraftAction,
            child: badgeContent,
          ),
        );
      }

      return badgeContent;
    }

    // Student Status Badge
    final attempt = exam.myLatestAttempt;
    final displayScore = exam.myBestScore ?? attempt?.score;
    if (exam.isFullyCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 13,
              color: AppColors.success,
            ),
            const SizedBox(width: 4),
            Text(
              displayScore != null
                  ? '${context.l10n.examCompletedCheck} ($displayScore/${exam.maxScore})'
                  : context.l10n.examCompletedCheck,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      );
    }

    if (exam.hasActiveAttempt ||
        (attempt != null && attempt.isInProgress && !exam.isFullyCompleted)) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.hourglass_top_rounded,
              size: 12,
              color: AppColors.warning,
            ),
            const SizedBox(width: 4),
            Text(
              context.l10n.attemptStatusInProgress,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.rocket_launch_outlined,
            size: 12,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            context.l10n.availableToStart,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
