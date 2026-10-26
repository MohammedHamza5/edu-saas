import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../content/domain/entities/content_entity.dart';
import '../../../content/domain/entities/lesson_assignment_entity.dart';

/// Navigation bar providing Previous / Next controls and current syllabus progress
/// between sequential course lessons.
class VideoSequentialNavigationBar extends StatelessWidget {
  const VideoSequentialNavigationBar({
    super.key,
    required this.courseLessons,
    required this.currentVideoId,
    this.lessonIndex,
    this.totalLessons,
    this.onOpenDrawer,
    required this.onOpenLesson,
  });

  final List<LessonAssignmentEntity> courseLessons;
  final String currentVideoId;
  final int? lessonIndex;
  final int? totalLessons;
  final VoidCallback? onOpenDrawer;
  final void Function(
    LessonAssignmentEntity lesson,
    int index,
    int totalCount,
  ) onOpenLesson;

  @override
  Widget build(BuildContext context) {
    if (courseLessons.isEmpty && lessonIndex == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final currentIndex = courseLessons.isNotEmpty
        ? courseLessons.indexWhere((l) => l.contentId == currentVideoId)
        : (lessonIndex != null ? lessonIndex! - 1 : -1);

    final totalCount = courseLessons.isNotEmpty
        ? courseLessons.length
        : (totalLessons ?? 1);
    final displayIndex = (currentIndex >= 0
        ? currentIndex + 1
        : (lessonIndex ?? 1));

    final prevLesson =
        currentIndex > 0 ? courseLessons[currentIndex - 1] : null;
    final nextLesson =
        (currentIndex >= 0 && currentIndex < courseLessons.length - 1)
        ? (courseLessons[currentIndex + 1].type == ContentType.video &&
           courseLessons[currentIndex + 1].contentId != currentVideoId
              ? courseLessons[currentIndex + 1]
              : null)
        : null;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.s12, bottom: AppSpacing.s8),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withAlpha(50),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border.withAlpha(60)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous Lesson Button
          if (prevLesson != null)
            TextButton.icon(
              onPressed: () =>
                  onOpenLesson(prevLesson, displayIndex - 1, totalCount),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: Text(context.l10n.previousLessonAction),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            )
          else
            const SizedBox(width: 80),

          // Middle: "Lesson X of Y" + View syllabus button
          InkWell(
            onTap: courseLessons.isNotEmpty ? onOpenDrawer : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.lessonXofY(displayIndex, totalCount),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  if (courseLessons.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.format_list_bulleted_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Next Lesson Button
          if (nextLesson != null)
            TextButton.icon(
              onPressed: () =>
                  onOpenLesson(nextLesson, displayIndex + 1, totalCount),
              icon: Icon(
                nextLesson.isLocked
                    ? Icons.lock_outline_rounded
                    : Icons.arrow_forward_rounded,
                size: 16,
                color: nextLesson.isLocked
                    ? AppColors.textMuted
                    : AppColors.primary,
              ),
              label: Text(
                context.l10n.nextLessonAction,
                style: TextStyle(
                  color: nextLesson.isLocked
                      ? AppColors.textMuted
                      : AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            )
          else
            const SizedBox(width: 80),
        ],
      ),
    );
  }
}
