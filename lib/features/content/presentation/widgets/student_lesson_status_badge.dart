import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/content_entity.dart';
import '../../domain/entities/lesson_assignment_entity.dart';

/// Progress and access status badge for a student lesson tile.
class StudentLessonStatusBadge extends StatelessWidget {
  final bool isLocked;
  final bool isCompleted;
  final bool isQuizFailed;
  final bool isQuizReady;
  final int index;
  final LessonAssignmentEntity? lesson;
  final ContentEntity content;

  const StudentLessonStatusBadge({
    super.key,
    required this.isLocked,
    required this.isCompleted,
    required this.isQuizFailed,
    required this.isQuizReady,
    required this.index,
    this.lesson,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    if (isLocked) {
      final prevIndex = index > 1 ? index - 1 : 1;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 11,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              context.l10n.completeLessonToUnlock(prevIndex),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      );
    }

    if (isCompleted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 11,
            color: AppColors.success,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              context.l10n.statusCompleted,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      );
    }

    if (isQuizFailed) {
      final best = lesson?.examBestScore?.toInt();
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 11,
            color: AppColors.warning,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              best != null
                  ? '${context.l10n.quizNotPassedTitle} ($best%)'
                  : context.l10n.quizNotPassedTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      );
    }

    if (isQuizReady) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: AppColors.primary),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              context.l10n.lessonQuizReadyTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      );
    }

    final pct =
        (lesson?.watchedCoveragePercent ?? content.videoProgressPercentage)
            .toInt();
    if (pct > 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.timelapse_rounded,
            size: 11,
            color: AppColors.primary,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              '$pct%',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      );
    }

    // Newly unlocked or manually unlocked (shows "Available")
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.play_circle_outline_rounded,
          size: 11,
          color: AppColors.primary,
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            context.l10n.availableStatus,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
