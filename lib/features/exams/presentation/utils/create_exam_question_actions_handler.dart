import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/repositories/exams_repository.dart';
import '../models/create_exam_draft_models.dart';
import '../widgets/bulk_fill_options_sheet.dart';
import '../widgets/question_bank_picker_sheet.dart';
import 'create_exam_builder_helpers.dart';
import 'create_exam_questions_coordinator.dart';

/// Handles interactive user actions for questions (picking from bank, applying points, bulk filling, uploading images).
class CreateExamQuestionActionsHandler {
  CreateExamQuestionActionsHandler._();

  static void uploadQuestionImage({
    required BuildContext context,
    required CreateExamDraftQuestion q,
    required int qIndex,
    required Uint8List bytes,
    required String filename,
    required ExamsRepository uploadService,
    required VoidCallback onStateChanged,
  }) {
    CreateExamBuilderHelpers.uploadQuestionImage(
      q: q,
      qIndex: qIndex,
      bytes: bytes,
      filename: filename,
      uploadService: uploadService,
      onStateChanged: onStateChanged,
      onError: (err) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.imageUploadFailed(err)),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
    );
  }

  static Future<void> openQuestionBankPicker(
    BuildContext context, {
    required List<CreateExamDraftQuestion> questions,
    required int defaultPoints,
    required void Function(CreateExamDraftQuestion) onBindListeners,
    required VoidCallback onUpdate,
    required VoidCallback onScheduleAutoSave,
  }) async {
    final importedRevisions = await QuestionBankPickerSheet.show(context);
    if (importedRevisions != null && importedRevisions.isNotEmpty && context.mounted) {
      CreateExamQuestionsCoordinator.importFromBank(
        questions: questions,
        revisions: importedRevisions,
        defaultPoints: defaultPoints,
        onBindListeners: onBindListeners,
      );
      onUpdate();
      onScheduleAutoSave();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.questionsImportedSuccess(importedRevisions.length),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  static void applyDefaultPointsToAll({
    required BuildContext context,
    required TextEditingController defaultPointsController,
    required List<CreateExamDraftQuestion> questions,
    required void Function(int) onPointsApplied,
    required VoidCallback onUpdate,
    required VoidCallback onScheduleAutoSave,
  }) {
    final pts = int.tryParse(defaultPointsController.text.trim());
    if (pts == null || pts <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.invalidPointsError),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    CreateExamQuestionsCoordinator.applyDefaultPoints(
      questions: questions,
      points: pts,
    );
    onPointsApplied(pts);
    onUpdate();
    onScheduleAutoSave();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.pointsAppliedToAllSuccess(pts, questions.length),
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void bulkFillAllQuestions(
    BuildContext context, {
    required List<CreateExamDraftQuestion> questions,
    required String pattern,
    bool onlyEmpty = false,
    required VoidCallback onUpdate,
    required VoidCallback onScheduleAutoSave,
  }) {
    final updatedCount = CreateExamQuestionsCoordinator.bulkFillAll(
      questions: questions,
      pattern: pattern,
      onlyEmpty: onlyEmpty,
    );
    onUpdate();
    onScheduleAutoSave();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.optionsAutoFilledSuccess(updatedCount)),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  static void showBulkFillOptionsSheet(
    BuildContext context, {
    required List<CreateExamDraftQuestion> questions,
    required VoidCallback onUpdate,
    required VoidCallback onScheduleAutoSave,
  }) {
    BulkFillOptionsSheet.show(
      context,
      onSelectPattern: (pattern, {required bool onlyEmpty}) {
        bulkFillAllQuestions(
          context,
          questions: questions,
          pattern: pattern,
          onlyEmpty: onlyEmpty,
          onUpdate: onUpdate,
          onScheduleAutoSave: onScheduleAutoSave,
        );
      },
    );
  }
}
