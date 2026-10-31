import '../../domain/entities/content_entity.dart';
import '../../domain/entities/lesson_assignment_entity.dart';

/// Computed progress and filtered lessons data for the Student Content Feed.
class StudentContentProgressSummary {
  final List<LessonAssignmentEntity> allPublished;
  final List<LessonAssignmentEntity> filteredItems;
  final LessonAssignmentEntity? nextLesson;
  final int? nextLessonIndex;
  final int completedCount;
  final int totalCount;
  final int overallPercentage;

  const StudentContentProgressSummary({
    required this.allPublished,
    required this.filteredItems,
    this.nextLesson,
    this.nextLessonIndex,
    required this.completedCount,
    required this.totalCount,
    required this.overallPercentage,
  });
}

/// Helper to compute next lessons, completion rates, and filter by query/type.
class StudentContentFilterHelper {
  StudentContentFilterHelper._();

  static StudentContentProgressSummary calculate({
    required List<LessonAssignmentEntity> lessons,
    ContentType? selectedTypeFilter,
    String searchQuery = '',
  }) {
    final videoLectures =
        lessons.where((i) => i.type == ContentType.video).toList();
    final allPublished = videoLectures.isNotEmpty ? videoLectures : lessons;
    final completedCount =
        allPublished.where((i) => i.isEffectivelyCompleted).length;
    final totalPublishedCount = allPublished.length;
    final overallProgressPct = totalPublishedCount > 0
        ? ((completedCount / totalPublishedCount) * 100).toInt()
        : 0;

    LessonAssignmentEntity? nextLesson;
    int? nextLessonIndex;
    for (int i = 0; i < allPublished.length; i++) {
      final it = allPublished[i];
      if (!it.isEffectivelyCompleted && !it.isLocked) {
        nextLesson = it;
        nextLessonIndex = i + 1;
        break;
      }
    }
    if (nextLesson == null) {
      for (int i = 0; i < allPublished.length; i++) {
        final it = allPublished[i];
        if (!it.isEffectivelyCompleted) {
          nextLesson = it;
          nextLessonIndex = i + 1;
          break;
        }
      }
    }

    var items = selectedTypeFilter == null
        ? allPublished
        : allPublished.where((i) => i.type == selectedTypeFilter).toList();

    final query = searchQuery.trim();
    if (query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      items = items
          .where(
            (i) =>
                i.title.toLowerCase().contains(lowerQuery) ||
                (i.description?.toLowerCase().contains(lowerQuery) ?? false) ||
                (i.pdfFileName?.toLowerCase().contains(lowerQuery) ?? false),
          )
          .toList();
    }

    return StudentContentProgressSummary(
      allPublished: allPublished,
      filteredItems: items,
      nextLesson: nextLesson,
      nextLessonIndex: nextLessonIndex,
      completedCount: completedCount,
      totalCount: totalPublishedCount,
      overallPercentage: overallProgressPct,
    );
  }
}
