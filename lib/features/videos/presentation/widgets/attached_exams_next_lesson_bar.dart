import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../content/domain/entities/lesson_assignment_entity.dart';

/// Navigation banner at bottom of attached exams allowing sequential continuation to next lesson
class AttachedExamsNextLessonBar extends StatelessWidget {
  final LessonAssignmentEntity nextLesson;
  final int nextLessonIndex;
  final int totalLessonsCount;
  final void Function(
    LessonAssignmentEntity lesson,
    int displayIndex,
    int totalCount,
  ) onOpenLesson;
  final VoidCallback? onReviewLesson;

  const AttachedExamsNextLessonBar({
    super.key,
    required this.nextLesson,
    required this.nextLessonIndex,
    required this.totalLessonsCount,
    required this.onOpenLesson,
    this.onReviewLesson,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.s6),
        Text(
          l10n.nextLessonLabel(nextLesson.title),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        ElevatedButton.icon(
          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
          label: Text(l10n.continueToNextLessonAction),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.s12,
              horizontal: AppSpacing.s16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            ),
          ),
          onPressed: () => onOpenLesson(
            nextLesson,
            nextLessonIndex,
            totalLessonsCount,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.replay_rounded, size: 16),
          label: Text(l10n.reviewLessonAction),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.s10,
              horizontal: AppSpacing.s16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            ),
          ),
          onPressed: onReviewLesson,
        ),
      ],
    );
  }
}
