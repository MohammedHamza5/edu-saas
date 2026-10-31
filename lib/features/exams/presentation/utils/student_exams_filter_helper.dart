import '../../domain/entities/exam_entity.dart';
import '../../domain/entities/exam_folder_entity.dart';
import '../widgets/student_exams_overview_hub.dart';

/// Computed student exams data summary including folders, category counts, and filter results.
class StudentExamsDataSummary {
  final List<ExamEntity> allExams;
  final List<ExamFolderEntity> studentFolders;
  final int uncategorizedCount;
  final List<ExamEntity> filteredExams;
  final List<ExamEntity> folderScopedExams;

  const StudentExamsDataSummary({
    required this.allExams,
    required this.studentFolders,
    required this.uncategorizedCount,
    required this.filteredExams,
    required this.folderScopedExams,
  });
}

/// Helper class for filtering exams, identifying lecture quizzes, and computing folder metrics.
class StudentExamsFilterHelper {
  StudentExamsFilterHelper._();

  /// Determines whether an exam is an embedded lesson quiz or standalone assessment.
  static bool isLessonQuiz(ExamEntity exam) {
    if (exam.isLectureExam) return true;
    if (exam.linkedLessonId != null && exam.linkedLessonId!.isNotEmpty) {
      return true;
    }
    final lower = exam.title.toLowerCase();
    return lower.contains('كويز') ||
        lower.contains('quiz') ||
        lower.contains('درس') ||
        lower.contains('محاضرة') ||
        lower.contains('lesson');
  }

  /// Computes all folders, uncategorized counts, and filtered exams based on search and tab.
  static StudentExamsDataSummary computeSummary({
    required List<ExamEntity> rawExams,
    String? selectedFolderId,
    required StudentExamFilter activeFilter,
    String searchQuery = '',
  }) {
    final allExams = rawExams.where((e) => !isLessonQuiz(e)).toList();

    final Map<String, ExamFolderEntity> folderMap = {};
    for (final exam in allExams) {
      if (exam.folderId != null && exam.folderId!.trim().isNotEmpty) {
        final fid = exam.folderId!.trim();
        if (!folderMap.containsKey(fid)) {
          folderMap[fid] = ExamFolderEntity(
            id: fid,
            tenantId: exam.tenantId,
            groupId: exam.groupId,
            name: exam.folderName ?? '',
            color: exam.folderColor ?? '#5B4FE0',
            examCount: 1,
            createdAt: exam.createdAt,
            updatedAt: exam.updatedAt,
          );
        } else {
          final existing = folderMap[fid]!;
          folderMap[fid] = existing.copyWith(
            examCount: existing.examCount + 1,
          );
        }
      }
    }
    final studentFolders = folderMap.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final uncategorizedCount = allExams
        .where((e) => e.folderId == null || e.folderId!.trim().isEmpty)
        .length;

    final folderScopedExams = selectedFolderId == null
        ? allExams
        : selectedFolderId == 'uncategorized'
            ? allExams
                .where((e) => e.folderId == null || e.folderId!.trim().isEmpty)
                .toList()
            : allExams.where((e) => e.folderId == selectedFolderId).toList();

    List<ExamEntity> filtered = allExams;
    if (selectedFolderId != null) {
      if (selectedFolderId == 'uncategorized') {
        filtered = filtered
            .where((e) => e.folderId == null || e.folderId!.trim().isEmpty)
            .toList();
      } else {
        filtered =
            filtered.where((e) => e.folderId == selectedFolderId).toList();
      }
    }

    switch (activeFilter) {
      case StudentExamFilter.all:
        break;
      case StudentExamFilter.available:
        filtered = filtered
            .where((e) =>
                !e.hasAttempted || (!e.isFullyCompleted && !e.hasActiveAttempt))
            .toList();
        break;
      case StudentExamFilter.inProgress:
        filtered = filtered.where((e) => e.hasActiveAttempt).toList();
        break;
      case StudentExamFilter.completed:
        filtered = filtered.where((e) => e.isFullyCompleted).toList();
        break;
    }

    final query = searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((e) {
        final title = e.title.toLowerCase();
        final group = (e.groupName ?? '').toLowerCase();
        final folder = (e.folderName ?? '').toLowerCase();
        return title.contains(query) ||
            group.contains(query) ||
            folder.contains(query);
      }).toList();
    }

    return StudentExamsDataSummary(
      allExams: allExams,
      studentFolders: studentFolders,
      uncategorizedCount: uncategorizedCount,
      filteredExams: filtered,
      folderScopedExams: folderScopedExams,
    );
  }
}
