import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/lesson_assignment_entity.dart';
import 'student_lesson_tile.dart';

class StudentChapterAccordionCard extends StatelessWidget {
  final String? chapterId;
  final String chapterTitle;
  final int chapterIndex;
  final List<LessonAssignmentEntity> lessons;
  final int globalStartIndex;
  final bool isExpanded;
  final VoidCallback onToggle;
  final bool isRoadmapMode;
  final void Function(LessonAssignmentEntity lesson, int globalIndex)
      onLessonTap;
  final void Function(LessonAssignmentEntity lesson)? onOpenHandout;
  final void Function(LessonAssignmentEntity lesson)? onTakeQuiz;

  const StudentChapterAccordionCard({
    super.key,
    required this.chapterId,
    required this.chapterTitle,
    required this.chapterIndex,
    required this.lessons,
    required this.globalStartIndex,
    required this.isExpanded,
    required this.onToggle,
    this.isRoadmapMode = true,
    required this.onLessonTap,
    this.onOpenHandout,
    this.onTakeQuiz,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final totalLessons = lessons.length;
    final completedLessons = lessons
        .where(
          (l) =>
              l.isEffectivelyCompleted ||
              (l.hasWatched90Percent &&
                  (!l.hasLessonExam || l.examPassed)),
        )
        .length;

    final isAllCompleted = totalLessons > 0 && completedLessons == totalLessons;
    final isAllLocked = totalLessons > 0 && lessons.every((l) => l.isLocked);
    final isInProgress = !isAllCompleted && !isAllLocked;
    final progressFraction =
        totalLessons > 0 ? (completedLessons / totalLessons) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(
          color: isExpanded
              ? AppColors.primary.withAlpha(80)
              : AppColors.border,
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isExpanded
                ? AppColors.primary.withAlpha(20)
                : AppColors.shadowSoft,
            blurRadius: isExpanded ? 12 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header (Tappable Accordion Bar) ─────────────────────────────
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      // Chapter Icon / Number Badge
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isAllCompleted
                              ? AppColors.success.withAlpha(25)
                              : isAllLocked
                                  ? AppColors.surfaceVariant
                                  : AppColors.primary.withAlpha(25),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMedium),
                        ),
                        child: Center(
                          child: isAllCompleted
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.success,
                                  size: 22,
                                )
                              : isAllLocked
                                  ? const Icon(
                                      Icons.lock_rounded,
                                      color: AppColors.textMuted,
                                      size: 20,
                                    )
                                  : Text(
                                      '$chapterIndex',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
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
                              chapterTitle,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontSize: 15.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  l10n.chapterLessonsCount(totalLessons),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                if (totalLessons > 0) ...[
                                  const Text(
                                    '  •  ',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    l10n.chapterCompletedLessons(
                                      completedLessons,
                                      totalLessons,
                                    ),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isAllCompleted
                                          ? AppColors.success
                                          : AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),

                      // Status Badge
                      _buildStatusChip(
                        context,
                        isAllCompleted: isAllCompleted,
                        isAllLocked: isAllLocked,
                        isInProgress: isInProgress,
                      ),
                      const SizedBox(width: AppSpacing.s8),

                      // Expand/Collapse Chevron
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textSecondary,
                          size: 24,
                        ),
                      ),
                    ],
                  ),

                  // Progress Bar across chapter
                  if (totalLessons > 0) ...[
                    const SizedBox(height: AppSpacing.s12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progressFraction,
                        minHeight: 4,
                        backgroundColor:
                            AppColors.surfaceVariant.withAlpha(120),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isAllCompleted
                              ? AppColors.success
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Expanded Content (Lessons in this Chapter) ───────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: isExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.border,
                      ),
                      if (isAllLocked)
                        Container(
                          margin: const EdgeInsets.all(AppSpacing.s12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s12,
                            vertical: AppSpacing.s10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withAlpha(20),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusMedium),
                            border: Border.all(
                              color: AppColors.warning.withAlpha(60),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.lock_clock_rounded,
                                size: 18,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Expanded(
                                child: Text(
                                  l10n.chapterLockedMessage,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(
                          top: AppSpacing.s8,
                          bottom: AppSpacing.s12,
                        ),
                        itemCount: lessons.length,
                        itemBuilder: (context, lessonIndex) {
                          final item = lessons[lessonIndex];
                          final globalIndex = globalStartIndex + lessonIndex;
                          return StudentLessonTile(
                            key: ValueKey('chap_lesson_${item.contentId}'),
                            content: item.toContentEntity(),
                            lesson: item,
                            index: globalIndex,
                            isLast: lessonIndex == lessons.length - 1,
                            isRoadmapMode: isRoadmapMode,
                            onTap: () => onLessonTap(item, globalIndex),
                            onOpenHandout: item.pdfFileId != null
                                ? () => onOpenHandout?.call(item)
                                : null,
                            onTakeQuiz: item.hasLessonExam
                                ? () => onTakeQuiz?.call(item)
                                : null,
                          );
                        },
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 240),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
    BuildContext context, {
    required bool isAllCompleted,
    required bool isAllLocked,
    required bool isInProgress,
  }) {
    final l10n = context.l10n;

    if (isAllCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.success.withAlpha(25),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        child: Text(
          l10n.chapterCompletedBadge,
          style: const TextStyle(
            color: AppColors.success,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      );
    }

    if (isAllLocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        child: Text(
          l10n.chapterLockedBadge,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(25),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        l10n.chapterInProgressBadge,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}
