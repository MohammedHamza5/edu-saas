import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/content_entity.dart';
import 'teacher_chapter_card.dart';
import 'teacher_general_lessons_container.dart';

/// Full scrollable syllabus view rendering sequential chapters, unassigned general lessons,
/// reordering, and empty state handling.
class TeacherCourseSyllabusView extends StatelessWidget {
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final List<ChapterEntity> chapters;
  final List<ContentEntity> lessons;
  final Set<String> collapsedChapterIds;
  final bool isLoadingMore;
  final VoidCallback onAddLesson;
  final void Function(String chapterId) onToggleChapterCollapse;
  final void Function(int currentIndex, int delta) onMoveChapter;
  final void Function(ChapterEntity chapter, List<ContentEntity> chapterLessons)
      onChapterAnalytics;
  final void Function({String? chapterId}) onAddLessonToChapter;
  final void Function(ChapterEntity chapter) onToggleChapterVisibility;
  final void Function(ChapterEntity chapter) onEditChapter;
  final void Function(ChapterEntity chapter) onDeleteChapter;
  final void Function(ContentEntity lesson) onOpenEditLesson;
  final void Function(List<ContentEntity> chapterLessons, int fromIdx, int toIdx)
      onReorderLesson;
  final void Function(ContentEntity lesson) onMoveLessonToChapter;
  final void Function(ContentEntity lesson) onLessonAnalytics;
  final void Function(ContentEntity lesson) onDeleteLesson;
  final void Function(ContentEntity lesson) onToggleLessonVisibility;

  const TeacherCourseSyllabusView({
    super.key,
    required this.scrollController,
    required this.onRefresh,
    required this.chapters,
    required this.lessons,
    required this.collapsedChapterIds,
    required this.isLoadingMore,
    required this.onAddLesson,
    required this.onToggleChapterCollapse,
    required this.onMoveChapter,
    required this.onChapterAnalytics,
    required this.onAddLessonToChapter,
    required this.onToggleChapterVisibility,
    required this.onEditChapter,
    required this.onDeleteChapter,
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

    final generalLessons = lessons
        .where((l) =>
            l.chapterId == null || !chapters.any((c) => c.id == l.chapterId))
        .toList();
    final isCourseEmpty = chapters.isEmpty && generalLessons.isEmpty;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (isCourseEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: AppEmptyView(
                    message: l10n.courseBuilderEmptyTitle,
                    subtitle: l10n.courseBuilderEmptySubtitle,
                    icon: Icons.view_timeline_outlined,
                    actionText: l10n.addLessonButton,
                    onAction: onAddLesson,
                  ),
                ),
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.only(
                top: AppSpacing.s8,
                bottom: 96,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // 1. Chapters in sequence
                  for (int chIdx = 0; chIdx < chapters.length; chIdx++) ...[
                    () {
                      final ch = chapters[chIdx];
                      final chLessons =
                          lessons.where((l) => l.chapterId == ch.id).toList();
                      final canMoveUp = chIdx > 0;
                      final canMoveDown = chIdx < chapters.length - 1;

                      return TeacherChapterCard(
                        chapter: ch,
                        chapterNumber: chIdx + 1,
                        chapterLessons: chLessons,
                        allChapters: chapters,
                        isCollapsed: collapsedChapterIds.contains(ch.id),
                        onToggleCollapse: () => onToggleChapterCollapse(ch.id),
                        onMoveUp:
                            canMoveUp ? () => onMoveChapter(chIdx, -1) : null,
                        onMoveDown:
                            canMoveDown ? () => onMoveChapter(chIdx, 1) : null,
                        onAnalytics: () => onChapterAnalytics(ch, chLessons),
                        onAddLesson: () =>
                            onAddLessonToChapter(chapterId: ch.id),
                        onToggleVisibility: () => onToggleChapterVisibility(ch),
                        onEdit: () => onEditChapter(ch),
                        onDelete: () => onDeleteChapter(ch),
                        onOpenEditLesson: onOpenEditLesson,
                        onReorderLesson: (fromIdx, toIdx) =>
                            onReorderLesson(chLessons, fromIdx, toIdx),
                        onMoveLessonToChapter: onMoveLessonToChapter,
                        onLessonAnalytics: onLessonAnalytics,
                        onDeleteLesson: onDeleteLesson,
                        onToggleLessonVisibility: onToggleLessonVisibility,
                      );
                    }(),
                  ],

                  // 2. Unassigned General Lessons
                  if (generalLessons.isNotEmpty)
                    TeacherGeneralLessonsContainer(
                      generalLessons: generalLessons,
                      allChapters: chapters,
                      onOpenEditLesson: onOpenEditLesson,
                      onReorderLesson: (fromIdx, toIdx) =>
                          onReorderLesson(generalLessons, fromIdx, toIdx),
                      onMoveLessonToChapter: onMoveLessonToChapter,
                      onLessonAnalytics: onLessonAnalytics,
                      onDeleteLesson: onDeleteLesson,
                      onToggleLessonVisibility: onToggleLessonVisibility,
                    ),

                  // 3. Loading More Footer Indicator
                  if (isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.s16),
                      child: Center(
                        child: AppLoadingView.compact(size: 24),
                      ),
                    ),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
