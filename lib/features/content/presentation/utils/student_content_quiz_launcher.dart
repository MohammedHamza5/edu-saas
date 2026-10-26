import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/cache_manager.dart';
import '../../../exams/presentation/cubit/exams_cubit.dart';
import '../../../exams/presentation/pages/exam_intro_page.dart';
import '../../domain/entities/lesson_assignment_entity.dart';
import '../cubit/course_progress_cubit.dart';
import '../cubit/course_progress_state.dart';

/// Helper to launch an exam associated with a lesson in the student content feed.
class StudentContentQuizLauncher {
  const StudentContentQuizLauncher._();

  static Future<void> takeQuiz({
    required BuildContext context,
    required LessonAssignmentEntity item,
    required String activeGroupId,
    required String? currentUserId,
  }) async {
    if (!item.hasLessonExam || item.lessonExamId == null) return;

    try {
      final result = await InjectionContainer.examsRepository.getExamDetails(
        item.lessonExamId!,
      );

      if (!context.mounted) return;

      if (result.isSuccess && result.dataOrNull != null) {
        final exam = result.dataOrNull!;
        final questions = exam.activeVersion?.questions ?? const [];

        if (questions.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.warning,
              content: Text(context.l10n.examUnderPreparationNotice),
            ),
          );
          return;
        }

        final examsCubit = InjectionContainer.createExamsCubit();
        LessonAssignmentEntity? nextLesson;
        int? nextLessonIndex;
        int? totalLessons;

        final state = context.read<CourseProgressCubit>().state;
        if (state is CourseProgressLoaded) {
          final allLessons = state.lessons;
          totalLessons = allLessons.length;
          final cIdx = allLessons.indexWhere(
            (l) => l.contentId == item.contentId,
          );
          if (cIdx >= 0 && cIdx < allLessons.length - 1) {
            nextLesson = allLessons[cIdx + 1];
            nextLessonIndex = cIdx + 2;
          }
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
                totalLessonsCount: totalLessons,
              ),
            ),
          ),
        );

        if (context.mounted) {
          AppCache.content.clear();
          AppCache.exams.clear();
          unawaited(
            context.read<CourseProgressCubit>().loadCourseProgress(
              activeGroupId,
              studentId: currentUserId,
              forceRefresh: true,
            ),
          );
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
}
