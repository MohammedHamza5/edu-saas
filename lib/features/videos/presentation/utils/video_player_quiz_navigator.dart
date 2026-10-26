import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/cache_manager.dart';
import '../../../content/domain/entities/content_entity.dart';
import '../../../content/domain/entities/lesson_assignment_entity.dart';
import '../../../exams/presentation/cubit/exams_cubit.dart';
import '../../../exams/presentation/pages/exam_intro_page.dart';
import '../../../exams/presentation/pages/exam_result_page.dart';

/// Helper to navigate into a quiz or view its result from VideoPlayerPage.
class VideoPlayerQuizNavigator {
  const VideoPlayerQuizNavigator._();

  static Future<void> startLessonQuiz({
    required BuildContext context,
    required String examId,
    required String videoId,
    required List<LessonAssignmentEntity> courseLessons,
    required Future<void> Function() onReloadLessonContext,
  }) async {
    try {
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        ),
      );
      final result = await InjectionContainer.examsRepository.getExamDetails(examId);
      if (!context.mounted) return;
      Navigator.of(context).pop();

      if (result.isSuccess && result.dataOrNull != null) {
        final exam = result.dataOrNull!;
        final examsCubit = InjectionContainer.createExamsCubit();
        if (!context.mounted) return;
        LessonAssignmentEntity? nextLesson;
        int? nextLessonIndex;
        if (courseLessons.isNotEmpty) {
          final cIdx = courseLessons.indexWhere(
            (l) => l.contentId == videoId,
          );
          if (cIdx >= 0 && cIdx < courseLessons.length - 1) {
            final candidate = courseLessons[cIdx + 1];
            if (candidate.type == ContentType.video &&
                candidate.contentId != videoId &&
                candidate.lessonExamId != exam.id &&
                !candidate.attachedExams.any((e) => e.examId == exam.id)) {
              nextLesson = candidate;
              nextLessonIndex = cIdx + 2;
            }
          }
        }

        final isPassed = (exam.myBestScore != null &&
                exam.passingScore != null &&
                exam.myBestScore! >= exam.passingScore!) ||
            (exam.myLatestAttempt?.score != null &&
                exam.passingScore != null &&
                exam.myLatestAttempt!.score! >= exam.passingScore!);

        if (isPassed && !exam.allowRetake && exam.myLatestAttempt != null) {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => BlocProvider<ExamsCubit>.value(
                value: examsCubit,
                child: ExamResultPage(
                  exam: exam,
                  attempt: exam.myLatestAttempt!,
                  isLectureExam: true,
                  nextLesson: nextLesson,
                  nextLessonIndex: nextLessonIndex,
                  totalLessonsCount: courseLessons.length,
                ),
              ),
            ),
          );
          if (context.mounted) {
            AppCache.content.clear();
            AppCache.exams.clear();
            await onReloadLessonContext();
            if (!context.mounted) return;
          }
          return;
        }

        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => BlocProvider<ExamsCubit>.value(
              value: examsCubit,
              child: ExamIntroPage(
                exam: exam,
                isLectureExam: true,
                nextLesson: nextLesson,
                nextLessonIndex: nextLessonIndex,
                totalLessonsCount: courseLessons.length,
              ),
            ),
          ),
        );
        if (context.mounted) {
          AppCache.content.clear();
          AppCache.exams.clear();
          await onReloadLessonContext();
            if (!context.mounted) return;
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text(
                result.failureOrNull?.message ?? context.l10n.errorOccurred,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(e.toString()),
          ),
        );
      }
    }
  }

  static Future<void> openQuizResult({
    required BuildContext context,
    required String examId,
    required String videoId,
    required List<LessonAssignmentEntity> courseLessons,
    required Future<void> Function() onReloadLessonContext,
  }) async {
    try {
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        ),
      );
      final result = await InjectionContainer.examsRepository.getExamDetails(examId);
      if (!context.mounted) return;
      Navigator.of(context).pop();

      if (result.isSuccess && result.dataOrNull != null) {
        final exam = result.dataOrNull!;
        if (!context.mounted) return;
        final attempt = exam.myLatestAttempt;
        if (attempt == null) {
          await startLessonQuiz(
            context: context,
            examId: examId,
            videoId: videoId,
            courseLessons: courseLessons,
            onReloadLessonContext: onReloadLessonContext,
          );
          return;
        }

        LessonAssignmentEntity? nextLesson;
        int? nextLessonIndex;
        if (courseLessons.isNotEmpty) {
          final cIdx = courseLessons.indexWhere(
            (l) => l.contentId == videoId,
          );
          if (cIdx >= 0 && cIdx < courseLessons.length - 1) {
            final candidate = courseLessons[cIdx + 1];
            if (candidate.type == ContentType.video &&
                candidate.contentId != videoId &&
                candidate.lessonExamId != exam.id &&
                !candidate.attachedExams.any((e) => e.examId == exam.id)) {
              nextLesson = candidate;
              nextLessonIndex = cIdx + 2;
            }
          }
        }

        final examsCubit = InjectionContainer.createExamsCubit();
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => BlocProvider<ExamsCubit>.value(
              value: examsCubit,
              child: ExamResultPage(
                exam: exam,
                attempt: attempt,
                isLectureExam: true,
                nextLesson: nextLesson,
                nextLessonIndex: nextLessonIndex,
                totalLessonsCount: courseLessons.length,
              ),
            ),
          ),
        );
        if (context.mounted) {
          AppCache.content.clear();
          AppCache.exams.clear();
          await onReloadLessonContext();
            if (!context.mounted) return;
        }
      }
    } catch (_) {}
  }
}
