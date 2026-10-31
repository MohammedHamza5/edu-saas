import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/cache_manager.dart';
import '../../../content/domain/entities/content_entity.dart';
import '../../../content/domain/entities/file_attachment_entity.dart';
import '../../../content/domain/entities/lesson_assignment_entity.dart';
import '../../../content/presentation/widgets/material_viewer_sheet.dart';
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_cubit.dart';

class ExamNextLessonInfo {
  final LessonAssignmentEntity nextLesson;
  final int nextLessonIndex;
  final int totalLessonsCount;

  const ExamNextLessonInfo({
    required this.nextLesson,
    required this.nextLessonIndex,
    required this.totalLessonsCount,
  });
}

class ExamResultStats {
  final int score;
  final int maxScore;
  final int? passingScore;
  final bool isPassed;
  final double percentage;
  final int totalQuestions;
  final int correctCount;
  final int incorrectCount;
  final int answeredCount;
  final int skippedCount;
  final Duration? duration;

  const ExamResultStats({
    required this.score,
    required this.maxScore,
    required this.passingScore,
    required this.isPassed,
    required this.percentage,
    required this.totalQuestions,
    required this.correctCount,
    required this.incorrectCount,
    required this.answeredCount,
    required this.skippedCount,
    required this.duration,
  });

  factory ExamResultStats.calculate({
    required ExamEntity exam,
    required ExamAttemptEntity attempt,
  }) {
    final score = attempt.score ?? 0;
    final maxScore = exam.maxScore > 0 ? exam.maxScore : 100;
    final passingScore = exam.passingScore;
    final isPassed = attempt.isPassed(passingScore);
    final percentage = attempt.percentage ??
        (maxScore > 0 ? (score / maxScore) * 100 : 0.0);

    final questions = attempt.questions;
    final answers = attempt.answers;
    final totalQuestions = questions.isNotEmpty
        ? questions.length
        : (exam.totalQuestions > 0 ? exam.totalQuestions : attempt.answeredCount);

    final correctCount = answers.where((a) => a.isCorrect == true).length;
    final incorrectCount = answers
        .where((a) => a.selectedOptionId != null && a.isCorrect == false)
        .length;
    final answeredCount =
        answers.where((a) => a.selectedOptionId != null).length;
    final skippedCount = (totalQuestions > answeredCount)
        ? (totalQuestions - answeredCount)
        : 0;
    final duration = attempt.submittedAt?.difference(attempt.startedAt);

    return ExamResultStats(
      score: score,
      maxScore: maxScore,
      passingScore: passingScore,
      isPassed: isPassed,
      percentage: percentage,
      totalQuestions: totalQuestions,
      correctCount: correctCount,
      incorrectCount: incorrectCount,
      answeredCount: answeredCount,
      skippedCount: skippedCount,
      duration: duration,
    );
  }
}

/// Coordinator isolating external calls, booklet rendering, and lesson flow transitions
/// for the exam result page.
class ExamResultCoordinator {
  const ExamResultCoordinator._();

  /// Fetches next available video lesson in group sequence for automatic course progression.
  static Future<ExamNextLessonInfo?> fetchNextLesson({
    required ExamEntity exam,
    required String? studentId,
  }) async {
    try {
      final res = await InjectionContainer.contentRepository
          .getGroupCourseProgress(
            groupId: exam.groupId,
            studentId: studentId,
          );
      if (res.isSuccess && res.dataOrNull != null) {
        final allLessons = res.dataOrNull!;
        // Filter strictly to video lectures so exams never appear as lectures
        final videoLessons = allLessons
            .where((l) => l.type == ContentType.video)
            .toList();
        if (videoLessons.isNotEmpty) {
          final cIdx = videoLessons.indexWhere(
            (l) =>
                (exam.linkedLessonId != null &&
                    l.contentId == exam.linkedLessonId) ||
                l.lessonExamId == exam.id ||
                l.attachedExams.any((e) => e.examId == exam.id),
          );
          if (cIdx >= 0 && cIdx < videoLessons.length - 1) {
            final next = videoLessons[cIdx + 1];
            if (next.contentId != exam.linkedLessonId &&
                next.lessonExamId != exam.id &&
                !next.attachedExams.any((e) => e.examId == exam.id)) {
              return ExamNextLessonInfo(
                nextLesson: next,
                nextLessonIndex: cIdx + 2,
                totalLessonsCount: videoLessons.length,
              );
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Navigates student directly to the next sequential video lecture.
  static void goToNextLesson(
    BuildContext context, {
    required LessonAssignmentEntity nextLesson,
    required ExamEntity exam,
    int? nextLessonIndex,
    int? totalLessonsCount,
    ExamsCubit? examsCubit,
  }) {
    AppCache.content.clear();
    AppCache.exams.clear();
    examsCubit?.exitExamTaking();

    final encodedTitle = nextLesson.lessonExamTitle != null
        ? Uri.encodeComponent(nextLesson.lessonExamTitle!)
        : '';
    final encodedGroupName = exam.groupName != null
        ? Uri.encodeComponent(exam.groupName!)
        : '';
    final lIdx = nextLessonIndex ?? nextLesson.sortOrder;
    final tLessons = totalLessonsCount ?? 1;

    context.go(
      '${AppRoutes.videoPlayer}?id=${nextLesson.contentId}&associatedExamId=${nextLesson.lessonExamId ?? ''}&associatedExamTitle=$encodedTitle&groupId=${exam.groupId}&groupName=$encodedGroupName&lessonIndex=$lIdx&totalLessons=$tLessons',
    );
  }

  /// Navigates student back to group content or student dashboard.
  static void goToLecturesScreen(
    BuildContext context, {
    required ExamEntity exam,
    ExamsCubit? examsCubit,
  }) {
    AppCache.content.clear();
    AppCache.exams.clear();
    examsCubit?.exitExamTaking();

    if (exam.groupId.isNotEmpty) {
      context.go('/student/groups/${exam.groupId}/content');
    } else {
      context.go(AppRoutes.studentDashboard);
    }
  }

  /// Opens the PDF booklet attached to the exam in a modal bottom sheet.
  static void openPdfBooklet(
    BuildContext context, {
    required ExamEntity exam,
  }) {
    if (!exam.hasAttachedPdf) return;
    final file = FileAttachmentEntity(
      id: exam.pdfFileId ?? '',
      tenantId: exam.tenantId,
      contentId: exam.id,
      storagePath: exam.pdfStoragePath!,
      fileName: exam.pdfFileName ?? 'exam_booklet.pdf',
      mimeType: 'application/pdf',
      fileSize: exam.pdfFileSize ?? 0,
      createdAt: DateTime.now(),
    );
    final content = ContentEntity(
      id: exam.id,
      tenantId: exam.tenantId,
      title: exam.pdfFileName ?? exam.title,
      type: ContentType.pdf,
      status: ContentStatus.published,
      sortOrder: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      file: file,
    );

    MaterialViewerSheet.show(
      context,
      content: content,
      onGetSignedUrl: (path) => context.read<ExamsCubit>().getSignedPdfUrl(
            path,
            storageProvider: exam.pdfStorageProvider,
          ),
    );
  }
}
