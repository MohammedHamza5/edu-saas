import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/content_entity.dart';
import 'course_lesson_tile.dart';

/// Container displaying unassigned / general lectures that don't belong to any specific chapter.
class TeacherGeneralLessonsContainer extends StatelessWidget {
  final List<ContentEntity> generalLessons;
  final List<ChapterEntity> allChapters;
  final void Function(ContentEntity lesson) onOpenEditLesson;
  final void Function(int fromIndex, int toIndex) onReorderLesson;
  final void Function(ContentEntity lesson) onMoveLessonToChapter;
  final void Function(ContentEntity lesson) onLessonAnalytics;
  final void Function(ContentEntity lesson) onDeleteLesson;
  final void Function(ContentEntity lesson) onToggleLessonVisibility;

  const TeacherGeneralLessonsContainer({
    super.key,
    required this.generalLessons,
    required this.allChapters,
    required this.onOpenEditLesson,
    required this.onReorderLesson,
    required this.onMoveLessonToChapter,
    required this.onLessonAnalytics,
    required this.onDeleteLesson,
    required this.onToggleLessonVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(
          color: AppColors.border,
          width: 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.5),
              border: const Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMedium),
                  ),
                  child: const Icon(
                    Icons.view_agenda_outlined,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.unassignedLecturesSection,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.unassignedLecturesDesc,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    l10n.chapterLessonsCount(generalLessons.length),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.s8,
              horizontal: AppSpacing.s8,
            ),
            itemCount: generalLessons.length,
            itemBuilder: (context, idx) {
              final lesson = generalLessons[idx];
              return CourseLessonTile(
                key: ValueKey('gen_lesson_${lesson.id}'),
                content: lesson,
                index: idx,
                isSelected: false,
                onTap: () => onOpenEditLesson(lesson),
                lessonTitle: lesson.title,
                hasPdf: lesson.file != null,
                quizTitle: lesson.associatedExamTitle,
                canMoveUp: idx > 0,
                canMoveDown: idx < generalLessons.length - 1,
                onMoveUp: () => onReorderLesson(idx, idx - 1),
                onMoveDown: () => onReorderLesson(idx, idx + 2),
                onMoveToChapter: () => onMoveLessonToChapter(lesson),
                onViewAnalytics: () => onLessonAnalytics(lesson),
                onEdit: () => onOpenEditLesson(lesson),
                onDelete: () => onDeleteLesson(lesson),
                onToggleVisibility: () => onToggleLessonVisibility(lesson),
              );
            },
          ),
        ],
      ),
    );
  }
}
