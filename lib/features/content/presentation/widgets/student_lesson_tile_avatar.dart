import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/content_entity.dart';

/// Station avatar representing sequential lesson number, completed checkmark, or locked icon.
class StudentLessonTileAvatar extends StatelessWidget {
  final bool isCompleted;
  final bool isLocked;
  final int index;
  final double videoProgressPercentage;

  const StudentLessonTileAvatar({
    super.key,
    required this.isCompleted,
    required this.isLocked,
    required this.index,
    required this.videoProgressPercentage,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompleted) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.success.withAlpha(25),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.success.withAlpha(90),
            width: 1.5,
          ),
        ),
        child: const Icon(
          Icons.check_rounded,
          color: AppColors.success,
          size: 20,
        ),
      );
    }

    if (isLocked) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.error.withAlpha(20),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.error.withAlpha(70), width: 1.5),
        ),
        child: const Icon(Icons.lock_rounded, color: AppColors.error, size: 18),
      );
    }

    final hasProgress = videoProgressPercentage > 0;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(hasProgress ? 25 : 12),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withAlpha(hasProgress ? 120 : 60),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          index.toString().padLeft(2, '0'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// Circular fast action button (play, replay, quiz, or lock indicator).
class StudentLessonActionButton extends StatelessWidget {
  final bool isLocked;
  final bool isCompleted;
  final bool isQuizReady;
  final ContentType contentType;

  const StudentLessonActionButton({
    super.key,
    required this.isLocked,
    required this.isCompleted,
    required this.isQuizReady,
    required this.contentType,
  });

  @override
  Widget build(BuildContext context) {
    if (isLocked) {
      return Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: AppColors.surfaceVariant,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.lock_rounded,
          size: 15,
          color: AppColors.textMuted,
        ),
      );
    }

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: isCompleted
            ? AppColors.surfaceVariant
            : AppColors.primary.withAlpha(20),
        shape: BoxShape.circle,
        border: Border.all(
          color: isCompleted
              ? AppColors.border
              : AppColors.primary.withAlpha(70),
        ),
      ),
      child: Icon(
        isCompleted
            ? Icons.replay_rounded
            : (contentType == ContentType.exam || isQuizReady)
                ? Icons.quiz_rounded
                : Icons.play_arrow_rounded,
        size: isCompleted ? 16 : 18,
        color: isCompleted ? AppColors.textSecondary : AppColors.primary,
      ),
    );
  }
}
