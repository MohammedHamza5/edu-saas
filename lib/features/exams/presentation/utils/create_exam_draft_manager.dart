import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../models/create_exam_draft_models.dart';
import 'create_exam_draft_coordinator.dart';

/// Helper that orchestrates serializing, restoring, and discarding drafts for [CreateExamPage].
class CreateExamDraftManager {
  const CreateExamDraftManager._();

  static Future<bool> persistDraft({
    required CreateExamDraftCoordinator draftCoordinator,
    required bool isSubmitting,
    required String title,
    required String duration,
    required String maxScore,
    required String passingScore,
    required String defaultPoints,
    required bool shuffle,
    required bool showResult,
    required bool allowRetake,
    required bool isPublished,
    required bool saveToQuestionBank,
    required String? pdfFileId,
    required String? pdfFileName,
    required int? pdfFileSize,
    required String? pdfStoragePath,
    required List<CreateExamDraftQuestion> questions,
  }) async {
    if (isSubmitting) return false;

    if (!CreateExamDraftCoordinator.hasMeaningfulContent(
      title: title,
      questions: questions,
    )) {
      return false;
    }

    final draftData = CreateExamDraftSerializer.serialize(
      title: title,
      duration: duration,
      maxScore: maxScore,
      passingScore: passingScore,
      defaultPoints: defaultPoints,
      shuffle: shuffle,
      showResult: showResult,
      allowRetake: allowRetake,
      isPublished: isPublished,
      saveToQuestionBank: saveToQuestionBank,
      pdfFileId: pdfFileId,
      pdfFileName: pdfFileName,
      pdfFileSize: pdfFileSize,
      pdfStoragePath: pdfStoragePath,
      questions: questions,
    );

    return await draftCoordinator.persistDraft(
      isSubmitting: isSubmitting,
      draftData: draftData,
    );
  }

  static void restoreDraft({
    required BuildContext context,
    required Map<String, dynamic> savedDraftData,
    required TextEditingController titleController,
    required TextEditingController durationController,
    required TextEditingController maxScoreController,
    required TextEditingController passingScoreController,
    required TextEditingController defaultPointsController,
    required List<CreateExamDraftQuestion> questions,
    required void Function(CreateExamDraftQuestion) onBindListeners,
    required void Function({
      required bool shuffle,
      required bool showResult,
      required bool allowRetake,
      required bool isPublished,
      required bool saveToQuestionBank,
      required String? pdfFileId,
      required String? pdfFileName,
      required int? pdfFileSize,
      required String? pdfStoragePath,
      required int defaultQuestionPoints,
    })
    onApplySettings,
  }) {
    final v = CreateExamDraftSerializer.deserialize(savedDraftData);

    if (v.title != null && v.title!.isNotEmpty) {
      titleController.text = v.title!;
    }
    if (v.duration != null) durationController.text = v.duration!;
    if (v.maxScore != null) maxScoreController.text = v.maxScore!;
    if (v.passingScore != null) passingScoreController.text = v.passingScore!;
    int parsedPoints = 5;
    if (v.defaultPoints != null) {
      defaultPointsController.text = v.defaultPoints!;
      parsedPoints = int.tryParse(v.defaultPoints!) ?? 5;
    }

    onApplySettings(
      shuffle: v.shuffle ?? true,
      showResult: v.showResult ?? true,
      allowRetake: v.allowRetake ?? false,
      isPublished: v.isPublished ?? false,
      saveToQuestionBank: v.saveToQuestionBank ?? true,
      pdfFileId: v.pdfFileId,
      pdfFileName: v.pdfFileName,
      pdfFileSize: v.pdfFileSize,
      pdfStoragePath: v.pdfStoragePath,
      defaultQuestionPoints: parsedPoints,
    );

    if (v.questions != null && v.questions!.isNotEmpty) {
      CreateExamDraftCoordinator.restoreQuestions(
        targetQuestions: questions,
        newQuestions: v.questions!,
        onBindListeners: onBindListeners,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.examDraftRestoredSuccess),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void discardDraft({
    required BuildContext context,
    required CreateExamDraftCoordinator draftCoordinator,
  }) {
    draftCoordinator.clearDraft();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.examDraftDiscardedSuccess),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
