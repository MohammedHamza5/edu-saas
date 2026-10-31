import 'package:flutter/material.dart';

import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/content_entity.dart';
import 'teacher_course_overview_section.dart';
import 'teacher_course_syllabus_view.dart';

/// Coordinator widget displaying the active course overview header and syllabus list.
class TeacherCourseLoadedView extends StatelessWidget {
  final String? selectedGroupName;
  final List<ContentEntity> lessons;
  final List<ChapterEntity> chapters;
  final Set<String> collapsedChapterIds;
  final bool isLoadingMore;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final Future<void> Function({String? chapterId}) onAddLesson;
  final void Function(String chapterId) onToggleChapterCollapse;
  final VoidCallback onToggleAllChaptersCollapse;
  final void Function(int idx, int delta) onMoveChapter;
  final void Function(ChapterEntity chapter, List<ContentEntity> chapterLessons)
      onChapterAnalytics;
  final Future<void> Function(ChapterEntity chapter) onToggleChapterVisibility;
  final Future<void> Function(ChapterEntity chapter) onEditChapter;
  final Future<void> Function(ChapterEntity chapter) onDeleteChapter;
  final Future<void> Function(ContentEntity lesson) onOpenEditLesson;
  final Future<void> Function(
    List<ContentEntity> chapterLessons,
    int oldIndex,
    int newIndex,
  ) onReorderLesson;
  final Future<void> Function(ContentEntity lesson) onMoveLessonToChapter;
  final Future<void> Function(ContentEntity lesson) onLessonAnalytics;
  final Future<void> Function(ContentEntity lesson) onDeleteLesson;
  final Future<void> Function(ContentEntity lesson) onToggleLessonVisibility;
  final Future<void> Function(bool isPublished) onBulkVisibility;
  final VoidCallback onOpenGroupAnalytics;
  final VoidCallback onAddNewChapter;

  const TeacherCourseLoadedView({
    super.key,
    required this.selectedGroupName,
    required this.lessons,
    required this.chapters,
    required this.collapsedChapterIds,
    required this.isLoadingMore,
    required this.scrollController,
    required this.onRefresh,
    required this.onAddLesson,
    required this.onToggleChapterCollapse,
    required this.onToggleAllChaptersCollapse,
    required this.onMoveChapter,
    required this.onChapterAnalytics,
    required this.onToggleChapterVisibility,
    required this.onEditChapter,
    required this.onDeleteChapter,
    required this.onOpenEditLesson,
    required this.onReorderLesson,
    required this.onMoveLessonToChapter,
    required this.onLessonAnalytics,
    required this.onDeleteLesson,
    required this.onToggleLessonVisibility,
    required this.onBulkVisibility,
    required this.onOpenGroupAnalytics,
    required this.onAddNewChapter,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Course Overview Banner Card
        TeacherCourseOverviewSection(
          selectedGroupName: selectedGroupName,
          lessons: lessons,
          chapters: chapters,
          isAllCollapsed: collapsedChapterIds.length >= chapters.length,
          onToggleAllChaptersCollapse: onToggleAllChaptersCollapse,
          onBulkVisibility: onBulkVisibility,
          onOpenGroupAnalytics: onOpenGroupAnalytics,
          onAddNewChapter: onAddNewChapter,
          onAddLesson: onAddLesson,
        ),

        // 2. Syllabus View
        Expanded(
          child: TeacherCourseSyllabusView(
            scrollController: scrollController,
            onRefresh: onRefresh,
            chapters: chapters,
            lessons: lessons,
            collapsedChapterIds: collapsedChapterIds,
            isLoadingMore: isLoadingMore,
            onAddLesson: onAddLesson,
            onToggleChapterCollapse: onToggleChapterCollapse,
            onMoveChapter: onMoveChapter,
            onChapterAnalytics: onChapterAnalytics,
            onAddLessonToChapter: onAddLesson,
            onToggleChapterVisibility: onToggleChapterVisibility,
            onEditChapter: onEditChapter,
            onDeleteChapter: onDeleteChapter,
            onOpenEditLesson: onOpenEditLesson,
            onReorderLesson: onReorderLesson,
            onMoveLessonToChapter: onMoveLessonToChapter,
            onLessonAnalytics: onLessonAnalytics,
            onDeleteLesson: onDeleteLesson,
            onToggleLessonVisibility: onToggleLessonVisibility,
          ),
        ),
      ],
    );
  }
}
