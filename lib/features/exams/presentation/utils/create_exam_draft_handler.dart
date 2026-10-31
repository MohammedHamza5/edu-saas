import 'package:flutter/material.dart';

import '../models/create_exam_draft_models.dart';
import '../models/create_exam_form_state.dart';
import 'create_exam_draft_coordinator.dart';
import 'create_exam_draft_manager.dart';
import 'create_exam_pdf_state.dart';

/// Handles auto-saving, binding listeners, restoring, and discarding drafts for the exam creator.
class CreateExamDraftHandler {
  CreateExamDraftHandler._();

  static void bindQuestionListeners(
    CreateExamDraftQuestion q,
    VoidCallback onScheduleAutoSave,
  ) {
    q.textController.addListener(onScheduleAutoSave);
    q.pointsController.addListener(onScheduleAutoSave);
    for (final opt in q.options) {
      opt.controller.addListener(onScheduleAutoSave);
    }
  }

  static Future<bool> persistDraft({
    required CreateExamDraftCoordinator draftCoordinator,
    required bool isSubmitting,
    required CreateExamFormControllers controllers,
    required CreateExamSettingsState settings,
    required CreateExamPdfState pdfState,
    required List<CreateExamDraftQuestion> questions,
  }) async {
    if (isSubmitting) return false;

    return await CreateExamDraftManager.persistDraft(
      draftCoordinator: draftCoordinator,
      isSubmitting: isSubmitting,
      title: controllers.title.text,
      duration: controllers.duration.text,
      maxScore: controllers.maxScore.text,
      passingScore: controllers.passingScore.text,
      defaultPoints: controllers.defaultPoints.text,
      shuffle: settings.shuffle,
      showResult: settings.showResult,
      allowRetake: settings.allowRetake,
      isPublished: settings.isPublished,
      saveToQuestionBank: settings.saveToQuestionBank,
      pdfFileId: pdfState.fileId,
      pdfFileName: pdfState.fileName,
      pdfFileSize: pdfState.fileSize,
      pdfStoragePath: pdfState.storagePath,
      questions: questions,
    );
  }

  static void restoreDraft({
    required BuildContext context,
    required Map<String, dynamic> savedDraftData,
    required CreateExamFormControllers controllers,
    required CreateExamSettingsState settings,
    required CreateExamPdfState pdfState,
    required List<CreateExamDraftQuestion> questions,
    required void Function(CreateExamDraftQuestion) onBindListeners,
    required VoidCallback onUpdate,
  }) {
    CreateExamDraftManager.restoreDraft(
      context: context,
      savedDraftData: savedDraftData,
      titleController: controllers.title,
      durationController: controllers.duration,
      maxScoreController: controllers.maxScore,
      passingScoreController: controllers.passingScore,
      defaultPointsController: controllers.defaultPoints,
      questions: questions,
      onBindListeners: onBindListeners,
      onApplySettings: ({
        required shuffle,
        required showResult,
        required allowRetake,
        required isPublished,
        required saveToQuestionBank,
        required pdfFileId,
        required pdfFileName,
        required pdfFileSize,
        required pdfStoragePath,
        required defaultQuestionPoints,
      }) {
        settings.shuffle = shuffle;
        settings.showResult = showResult;
        settings.allowRetake = allowRetake;
        settings.isPublished = isPublished;
        settings.saveToQuestionBank = saveToQuestionBank;
        pdfState.fileId = pdfFileId;
        pdfState.fileName = pdfFileName;
        pdfState.fileSize = pdfFileSize;
        pdfState.storagePath = pdfStoragePath;
        pdfState.clearPdfOnSave = false;
        settings.defaultQuestionPoints = defaultQuestionPoints;
        onUpdate();
      },
    );
  }
}
