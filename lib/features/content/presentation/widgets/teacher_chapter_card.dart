import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/content_entity.dart';
import 'course_lesson_tile.dart';

/// Card representing a chapter and its contained lectures in the Teacher Content Library.
class TeacherChapterCard extends StatelessWidget {
  final ChapterEntity chapter;
  final int chapterNumber;
  final List<ContentEntity> chapterLessons;
  final List<ChapterEntity> allChapters;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onAnalytics;
  final VoidCallback onAddLesson;
  final VoidCallback onToggleVisibility;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(ContentEntity lesson) onOpenEditLesson;
  final void Function(int fromIndex, int toIndex) onReorderLesson;
  final void Function(ContentEntity lesson) onMoveLessonToChapter;
  final void Function(ContentEntity lesson) onLessonAnalytics;
  final void Function(ContentEntity lesson) onDeleteLesson;
  final void Function(ContentEntity lesson) onToggleLessonVisibility;

  const TeacherChapterCard({
    super.key,
    required this.chapter,
    required this.chapterNumber,
    required this.chapterLessons,
    required this.allChapters,
    required this.isCollapsed,
    required this.onToggleCollapse,
    this.onMoveUp,
    this.onMoveDown,
    required this.onAnalytics,
    required this.onAddLesson,
    required this.onToggleVisibility,
    required this.onEdit,
    required this.onDelete,
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
      margin: const EdgeInsets.only(bottom: AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Chapter Header Bar (Clickable for quick expand/collapse)
          InkWell(
            onTap: onToggleCollapse,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.6),
                border: Border(
                  bottom: isCollapsed
                      ? BorderSide.none
                      : const BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                children: [
                  // Chapter Number Badge
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMedium),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        chapterNumber.toString().padLeft(2, '0'),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),

                  // Chapter Title & Counter
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chapter.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            fontSize: 15.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                l10n.chapterLessonsCount(chapterLessons.length),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: (chapter.isPublished
                                        ? AppColors.success
                                        : AppColors.warning)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: (chapter.isPublished
                                          ? AppColors.success
                                          : AppColors.warning)
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    chapter.isPublished
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                    size: 11,
                                    color: chapter.isPublished
                                        ? AppColors.success
                                        : AppColors.warning,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    chapter.isPublished
                                        ? l10n.chapterVisibilityPublished
                                        : l10n.chapterVisibilityDraft,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: chapter.isPublished
                                          ? AppColors.success
                                          : AppColors.warning,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),

                  // Actions: Move Chapter Up / Down
                  IconButton(
                    icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                    tooltip: l10n.moveChapterUp,
                    visualDensity: VisualDensity.compact,
                    onPressed: onMoveUp,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                    tooltip: l10n.moveChapterDown,
                    visualDensity: VisualDensity.compact,
                    onPressed: onMoveDown,
                  ),
                  const SizedBox(width: 2),

                  // Actions: Chapter Analytics
                  IconButton(
                    icon: const Icon(
                      Icons.analytics_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    tooltip: l10n.chapterAnalytics,
                    visualDensity: VisualDensity.compact,
                    onPressed: onAnalytics,
                  ),
                  const SizedBox(width: 2),

                  // Actions: Add lecture to chapter
                  if (MediaQuery.of(context).size.width < 680)
                    IconButton(
                      onPressed: onAddLesson,
                      tooltip: l10n.addLectureToChapter,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.08),
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: onAddLesson,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(
                        l10n.addLectureToChapter,
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  const SizedBox(width: AppSpacing.s4),

                  // Chapter Options Menu
                  PopupMenuButton<String>(
                    tooltip: l10n.more,
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'toggle_visibility',
                        child: Row(
                          children: [
                            Icon(
                              chapter.isPublished
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: chapter.isPublished
                                  ? AppColors.warning
                                  : AppColors.success,
                              size: 18,
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            Text(
                              chapter.isPublished
                                  ? l10n.hideChapterAction
                                  : l10n.publishChapterAction,
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.edit_note_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            Text(l10n.editChapterTitle),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.error,
                              size: 18,
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            Text(
                              l10n.deleteChapterTitle,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (val) {
                      if (val == 'toggle_visibility') {
                        onToggleVisibility();
                      } else if (val == 'edit') {
                        onEdit();
                      } else if (val == 'delete') {
                        onDelete();
                      }
                    },
                  ),

                  // Expand/Collapse Chevron Indicator
                  IconButton(
                    icon: Icon(
                      isCollapsed
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                    tooltip: isCollapsed
                        ? l10n.expandAllChapters
                        : l10n.collapseAllChapters,
                    onPressed: onToggleCollapse,
                  ),
                ],
              ),
            ),
          ),

          // Chapter Body with Animated CrossFade Accordion
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: chapterLessons.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.s24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.folder_open_rounded,
                            size: 36,
                            color: AppColors.textMuted.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          Text(
                            l10n.emptyChapterPlaceholder,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          TextButton.icon(
                            onPressed: onAddLesson,
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: Text(l10n.emptyChapterTeacherAction),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s8,
                      horizontal: AppSpacing.s8,
                    ),
                    itemCount: chapterLessons.length,
                    itemBuilder: (context, idx) {
                      final lesson = chapterLessons[idx];
                      return CourseLessonTile(
                        key: ValueKey('chap_lesson_${lesson.id}'),
                        content: lesson,
                        index: idx,
                        isSelected: false,
                        onTap: () => onOpenEditLesson(lesson),
                        lessonTitle: lesson.title,
                        hasPdf: lesson.file != null,
                        quizTitle: lesson.associatedExamTitle,
                        canMoveUp: idx > 0,
                        canMoveDown: idx < chapterLessons.length - 1,
                        onMoveUp: () => onReorderLesson(idx, idx - 1),
                        onMoveDown: () => onReorderLesson(idx, idx + 2),
                        onMoveToChapter: () => onMoveLessonToChapter(lesson),
                        onViewAnalytics: () => onLessonAnalytics(lesson),
                        onEdit: () => onOpenEditLesson(lesson),
                        onDelete: () => onDeleteLesson(lesson),
                        onToggleVisibility: () =>
                            onToggleLessonVisibility(lesson),
                      );
                    },
                  ),
            crossFadeState: isCollapsed
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}
