import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../content/domain/entities/lesson_assignment_entity.dart';
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';
import '../pages/exam_result_page.dart';
import 'bluebook/bluebook_review_grid_modal.dart';

/// Confirmation dialogs for forced exit and exam submission during test taking
abstract final class ExamTakingSubmissionDialogs {
  /// Warning dialog when student tries to leave the exam before completing it
  static void confirmForcedExit(
    BuildContext context, {
    required ExamTakingState state,
    required VoidCallback onConfirm,
  }) {
    final unanswered = state.totalQuestions - state.answeredCount;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: AppColors.error),
            const SizedBox(width: AppSpacing.s8),
            Expanded(child: Text(ctx.l10n.forcedExitWarningTitle)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ctx.l10n.forcedExitWarningMessage,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.s12),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ctx.l10n.answeredQuestionsCount(
                      state.answeredCount,
                      state.totalQuestions,
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (unanswered > 0) ...[
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      ctx.l10n.unansweredWarning(unanswered),
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.l10n.stayAndContinueButton),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirm();
            },
            child: Text(ctx.l10n.forcedExitConfirmButton),
          ),
        ],
      ),
    );
  }

  /// Final confirmation dialog before submitting the exam
  static void confirmSubmit(
    BuildContext context, {
    required ExamTakingState state,
    required VoidCallback onConfirm,
  }) {
    final unanswered = state.totalQuestions - state.answeredCount;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.confirmSubmitExamTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ctx.l10n.answeredQuestionsCount(
                state.answeredCount,
                state.totalQuestions,
              ),
            ),
            if (unanswered > 0) ...[
              const SizedBox(height: AppSpacing.s8),
              Text(
                ctx.l10n.unansweredWarning(unanswered),
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s12),
            Text(ctx.l10n.confirmSubmitQuestion),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.l10n.continueSolving),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirm();
            },
            child: Text(
              ctx.l10n.yesSubmitExam,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Displays the interactive Bluebook review grid modal.
  static void openBluebookReviewGrid(
    BuildContext context, {
    required ExamTakingState state,
    required ValueChanged<int> onQuestionSelected,
    required VoidCallback onConfirmFinish,
  }) {
    if (state.isSubmitting) return;
    final answeredIndices = <int>{};
    final flaggedIndices = <int>{};
    for (int i = 0; i < state.questions.length; i++) {
      final qId = state.questions[i].id;
      if (state.answers.containsKey(qId)) {
        answeredIndices.add(i);
      }
      if (state.flaggedGuesses.contains(qId)) {
        flaggedIndices.add(i);
      }
    }

    BluebookReviewGridModal.show(
      context,
      totalQuestions: state.questions.length,
      currentQuestionIndex: state.currentQuestionIndex,
      answeredIndices: answeredIndices,
      flaggedIndices: flaggedIndices,
      onQuestionSelected: onQuestionSelected,
      onConfirmFinish: onConfirmFinish,
    );
  }

  /// Navigates to the exam result page upon successful submission.
  static void navigateToResult(
    BuildContext context, {
    required ExamTakingState state,
    required bool isLectureExam,
    LessonAssignmentEntity? nextLesson,
    int? nextLessonIndex,
    int? totalLessonsCount,
  }) {
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: context.read<ExamsCubit>(),
          child: ExamResultPage(
            exam: state.exam,
            attempt: state.submitResult!.copyWith(
              questions: state.questions,
              answers: state.submitResult!.answers.isNotEmpty
                  ? state.submitResult!.answers
                  : state.answers.entries
                      .map(
                        (e) => ExamAnswerEntity(
                          id: '',
                          attemptId: state.submitResult!.id,
                          questionId: e.key,
                          selectedOptionId: e.value,
                          answeredAt: DateTime.now(),
                        ),
                      )
                      .toList(),
            ),
            isLectureExam: isLectureExam ||
                state.exam.isLectureExam ||
                state.exam.isLinkedToLesson,
            nextLesson: nextLesson,
            nextLessonIndex: nextLessonIndex,
            totalLessonsCount: totalLessonsCount,
          ),
        ),
      ),
    );
  }
}
