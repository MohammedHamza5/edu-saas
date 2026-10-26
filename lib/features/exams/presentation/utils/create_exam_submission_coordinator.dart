import 'package:flutter/material.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';
import '../models/create_exam_draft_models.dart';
import 'create_exam_builder_helpers.dart';

/// Handles the full submission, validation, backend persistence, and question bank sync flow.
class CreateExamSubmissionCoordinator {
  CreateExamSubmissionCoordinator._();

  /// Validates questions, awaits pending uploads, dispatches to [ExamsCubit], and reports errors.
  /// Returns the persisted [ExamEntity] on success, or null on failure/validation stop.
  static Future<ExamEntity?> submit({
    required BuildContext context,
    required ExamsCubit cubit,
    required String? targetExamId,
    required String? groupId,
    required String title,
    required String durationText,
    required String maxScoreText,
    required String passingScoreText,
    required bool shuffle,
    required bool showResult,
    required bool allowRetake,
    required bool isPublished,
    required bool saveToQuestionBank,
    required bool clearPdfOnSave,
    required String? attachedPdfFileId,
    required List<CreateExamDraftQuestion> questions,
    required Future<void> Function() onClearDraft,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;

    // 1. Await background image uploads if any are still in progress
    final uploadSuccess =
        await CreateExamBuilderHelpers.awaitPendingUploads(questions);
    if (!context.mounted) return null;
    if (!uploadSuccess) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.imageUploadPendingError),
          backgroundColor: AppColors.error,
        ),
      );
      return null;
    }

    // 2. Validate question texts and option configurations
    final validationError = CreateExamBuilderHelpers.validateQuestions(
      questions: questions,
      fillQuestionTextError: (idx) => l10n.fillQuestionTextError(idx),
      atLeastTwoOptionsRequired: l10n.atLeastTwoOptionsRequired,
      selectCorrectOptionError: (idx) => l10n.selectCorrectOptionError(idx),
    );

    if (validationError != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: AppColors.error,
        ),
      );
      return null;
    }

    // 3. Transform draft questions into domain entities
    final initialQuestions =
        CreateExamBuilderHelpers.buildExamQuestionsFromDraft(
      questions: questions,
      optionTrueText: l10n.optionTrue,
      optionFalseText: l10n.optionFalse,
    );

    final isEditing = targetExamId != null;
    final ExamEntity? resultExam;

    final duration = int.tryParse(durationText) ?? 60;
    final maxScore = int.tryParse(maxScoreText) ?? 100;
    final passingScore = int.tryParse(passingScoreText);

    if (isEditing) {
      resultExam = await cubit.updateDraftExamQuestions(
        examId: targetExamId,
        title: title,
        durationMinutes: duration,
        maxScore: maxScore,
        passingScore: passingScore,
        shuffleQuestions: shuffle,
        showResult: showResult,
        allowRetake: allowRetake,
        isPublished: isPublished,
        pdfFileId: clearPdfOnSave ? null : attachedPdfFileId,
        clearPdfFile: clearPdfOnSave,
        questions: initialQuestions,
      );
    } else {
      resultExam = await cubit.createExam(
        groupId: groupId,
        title: title,
        durationMinutes: duration,
        maxScore: maxScore,
        passingScore: passingScore,
        shuffleQuestions: shuffle,
        showResult: showResult,
        allowRetake: allowRetake,
        isPublished: isPublished,
        pdfFileId: clearPdfOnSave ? null : attachedPdfFileId,
        initialQuestions: initialQuestions,
      );
    }

    if (!context.mounted) return null;

    if (resultExam != null) {
      await onClearDraft();
      if (saveToQuestionBank) {
        CreateExamBuilderHelpers.syncQuestionsToBank(
          questions: questions,
          examTitle: title,
          qbRepo: InjectionContainer.questionBankRepository,
        );
      }
      if (!context.mounted) return resultExam;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? l10n.examDraftUpdatedSuccess
                : l10n.examBuiltAndPublishedSuccess,
          ),
          backgroundColor: AppColors.success,
        ),
      );
      return resultExam;
    } else {
      final state = cubit.state;
      String errorMsg = 'Failed';
      if (state is TeacherExamsLoaded && state.message != null) {
        errorMsg = state.message!;
      } else if (state is ExamsError) {
        errorMsg = state.message;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? l10n.examUpdateFailed(errorMsg)
                : l10n.examPublishFailed(errorMsg),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return null;
    }
  }
}
