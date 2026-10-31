import 'dart:async';
import '../../../../core/di/injection_container.dart';
import '../../../../core/errors/result.dart';
import '../../../content/domain/entities/attached_lesson_exam_entity.dart';
import '../../../content/domain/entities/content_entity.dart';
import '../../../content/domain/entities/lesson_assignment_entity.dart';
import '../../../exams/domain/entities/exam_entity.dart';

/// Context metadata loaded for a specific video lesson in a group.
class VideoLessonContextData {
  final List<LessonAssignmentEntity> courseLessons;
  final List<AttachedLessonExamEntity> attachedExams;
  final Map<String, ExamEntity> attachedExamDetails;
  final String? groupPdfStoragePath;
  final String? groupPdfFileName;
  final String? groupExamId;
  final String? groupExamTitle;
  final ExamEntity? lessonExam;

  const VideoLessonContextData({
    this.courseLessons = const [],
    this.attachedExams = const [],
    this.attachedExamDetails = const {},
    this.groupPdfStoragePath,
    this.groupPdfFileName,
    this.groupExamId,
    this.groupExamTitle,
    this.lessonExam,
  });

  /// Computes the effective list of attached exams, falling back to legacy single exam if available.
  List<AttachedLessonExamEntity> get effectiveAttachedExams {
    if (attachedExams.isNotEmpty) return attachedExams;
    if (groupExamId != null && groupExamId!.isNotEmpty) {
      return [
        AttachedLessonExamEntity(
          examId: groupExamId!,
          examTitle: lessonExam?.title ?? groupExamTitle ?? '',
          isRequired: true,
          sortOrder: 0,
          isPassed: lessonExam?.myLatestAttempt?.isPassed(
                lessonExam?.passingScore ?? 60,
              ) ??
              false,
          bestScore: lessonExam?.myLatestAttempt?.score?.toDouble(),
          passingScore: lessonExam?.passingScore ?? 60,
        ),
      ];
    }
    return const [];
  }
}

/// Coordinator for fetching course progress, lesson assignments, and attached exams.
class VideoLessonContextCoordinator {
  static Future<VideoLessonContextData> load({
    required String videoId,
    required String activeStudentId,
    required bool isTeacher,
    String? groupId,
    String? associatedExamId,
    String? associatedExamTitle,
  }) async {
    List<LessonAssignmentEntity> courseLessons = [];
    List<AttachedLessonExamEntity> attachedExams = [];
    final Map<String, ExamEntity> attachedExamDetails = {};
    String? groupPdfStoragePath;
    String? groupPdfFileName;
    String? groupExamId;
    String? groupExamTitle;
    ExamEntity? lessonExam;

    try {
      if (groupId != null) {
        final progressFuture = !isTeacher
            ? InjectionContainer.contentRepository.getGroupCourseProgress(
                groupId: groupId,
                studentId: activeStudentId,
              )
            : null;

        final contextFuture =
            InjectionContainer.videosRepository.getLessonContext(
          contentId: videoId,
          groupId: groupId,
        );

        final results = await Future.wait<dynamic>([
          progressFuture ?? Future.value(null),
          contextFuture,
        ]);

        final lessonsResult =
            results[0] as Result<List<LessonAssignmentEntity>>?;
        final contextResult = results[1] as Result<Map<String, dynamic>?>;

        if (lessonsResult != null &&
            lessonsResult.isSuccess &&
            lessonsResult.dataOrNull != null) {
          final loadedLessons = lessonsResult.dataOrNull!;
          courseLessons = loadedLessons
              .where((l) => l.type == ContentType.video)
              .toList();

          final current = loadedLessons
              .where(
                (LessonAssignmentEntity l) => l.contentId == videoId,
              )
              .firstOrNull;
          if (current != null && current.attachedExams.isNotEmpty) {
            attachedExams = current.attachedExams;
          }
        }

        contextResult.when(
          onSuccess: (Map<String, dynamic>? ctx) {
            if (ctx != null) {
              groupExamId =
                  ctx['lesson_exam_id'] as String? ?? associatedExamId;
              groupExamTitle =
                  ctx['lesson_exam_title'] as String? ?? associatedExamTitle;
              groupPdfStoragePath = ctx['pdf_storage_path'] as String?;
              groupPdfFileName = ctx['pdf_file_name'] as String?;

              final rawAttached = ctx['attached_exams'] as List<dynamic>?;
              final parsedAttached = rawAttached != null
                  ? rawAttached
                      .map(
                        (e) => AttachedLessonExamEntity.fromJson(
                          e as Map<String, dynamic>,
                        ),
                      )
                      .toList()
                  : <AttachedLessonExamEntity>[];

              if (parsedAttached.isNotEmpty) {
                attachedExams = parsedAttached;
                for (final att in parsedAttached) {
                  unawaited(
                    InjectionContainer.examsRepository
                        .getExamDetails(att.examId)
                        .then((res) {
                      if (res.isSuccess && res.dataOrNull != null) {
                        attachedExamDetails[att.examId] = res.dataOrNull!;
                      }
                    }),
                  );
                }
              }
            }
          },
          onFailure: (_) {},
        );
      } else if (associatedExamId != null) {
        final examResult = await InjectionContainer.examsRepository
            .getExamDetails(associatedExamId);
        if (examResult.isSuccess && examResult.dataOrNull != null) {
          final ex = examResult.dataOrNull!;
          lessonExam = ex;
          attachedExamDetails[ex.id] = ex;
        }
      }
    } catch (_) {}

    return VideoLessonContextData(
      courseLessons: courseLessons,
      attachedExams: attachedExams,
      attachedExamDetails: attachedExamDetails,
      groupPdfStoragePath: groupPdfStoragePath,
      groupPdfFileName: groupPdfFileName,
      groupExamId: groupExamId,
      groupExamTitle: groupExamTitle,
      lessonExam: lessonExam,
    );
  }
}
