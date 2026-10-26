import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/content_entity.dart';
import '../../domain/entities/lesson_assignment_entity.dart';
import 'student_chapter_accordion_card.dart';
import 'student_chapter_bucket.dart';
import 'student_lesson_tile.dart';

/// Renders the sequential lessons or chapter-grouped accordion sliver inside
/// the Student Content Feed CustomScrollView.
class StudentContentSliversView extends StatelessWidget {
  final List<LessonAssignmentEntity> items;
  final List<ChapterEntity> chapters;
  final bool isRoadmapMode;
  final ContentType? selectedTypeFilter;
  final String searchQuery;
  final Set<String> expandedChapterIds;
  final void Function(String key) onToggleChapter;
  final void Function(LessonAssignmentEntity item, int globalIndex, int totalCount) onLessonTap;
  final void Function(LessonAssignmentEntity item)? onOpenHandout;
  final void Function(LessonAssignmentEntity item)? onTakeQuiz;

  const StudentContentSliversView({
    super.key,
    required this.items,
    required this.chapters,
    required this.isRoadmapMode,
    required this.selectedTypeFilter,
    required this.searchQuery,
    required this.expandedChapterIds,
    required this.onToggleChapter,
    required this.onLessonTap,
    this.onOpenHandout,
    this.onTakeQuiz,
  });

  @override
  Widget build(BuildContext context) {
    final hasChapters = chapters.isNotEmpty ||
        items.any((i) => i.chapterId != null && i.chapterId!.isNotEmpty);

    if (!hasChapters) {
      return SliverPadding(
        padding: const EdgeInsets.only(
          top: AppSpacing.s4,
          bottom: 40,
        ),
        sliver: SliverList.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return StudentLessonTile(
              content: item.toContentEntity(),
              lesson: item,
              index: index + 1,
              isLast: index == items.length - 1,
              isRoadmapMode: isRoadmapMode &&
                  selectedTypeFilter == null &&
                  searchQuery.isEmpty,
              onTap: () => onLessonTap(item, index + 1, items.length),
              onOpenHandout: item.pdfFileId != null && onOpenHandout != null
                  ? () => onOpenHandout!(item)
                  : null,
              onTakeQuiz: item.hasLessonExam && onTakeQuiz != null
                  ? () => onTakeQuiz!(item)
                  : null,
            );
          },
        ),
      );
    }

    // Accordion View by Academic Chapters
    final buckets = StudentChapterBucket.buildBuckets(
      items,
      chapters,
      context,
    );

    if (buckets.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.search_off_rounded,
                  size: 48,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: AppSpacing.s12),
                Text(
                  context.l10n.noMatchingContentFound(searchQuery),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final activeKey = buckets.firstWhere(
      (b) => b.lessons.any((l) => !l.isLocked && !l.isEffectivelyCompleted),
      orElse: () => buckets.first,
    ).chapterId ?? '__general__';

    int calcGlobalIndex(int bucketIndex) {
      int count = 1;
      for (int i = 0; i < bucketIndex; i++) {
        count += buckets[i].lessons.length;
      }
      return count;
    }

    return SliverPadding(
      padding: const EdgeInsets.only(
        top: AppSpacing.s4,
        bottom: 40,
      ),
      sliver: SliverList.builder(
        itemCount: buckets.length,
        itemBuilder: (context, bIdx) {
          final bucket = buckets[bIdx];
          final key = bucket.chapterId ?? '__general__';
          final isExpanded = searchQuery.isNotEmpty ||
              (expandedChapterIds.isEmpty
                  ? key == activeKey
                  : expandedChapterIds.contains(key));

          return StudentChapterAccordionCard(
            key: ValueKey('chapter_accordion_$key'),
            chapterId: bucket.chapterId,
            chapterTitle: bucket.title,
            chapterIndex: bIdx + 1,
            lessons: bucket.lessons,
            globalStartIndex: calcGlobalIndex(bIdx),
            isExpanded: isExpanded,
            isRoadmapMode: isRoadmapMode &&
                selectedTypeFilter == null &&
                searchQuery.isEmpty,
            onToggle: () => onToggleChapter(key),
            onLessonTap: (item, globalIndex) =>
                onLessonTap(item, globalIndex, items.length),
            onOpenHandout: onOpenHandout != null
                ? (item) => onOpenHandout!(item)
                : null,
            onTakeQuiz: onTakeQuiz != null
                ? (item) => onTakeQuiz!(item)
                : null,
          );
        },
      ),
    );
  }
}
