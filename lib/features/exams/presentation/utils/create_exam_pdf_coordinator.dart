import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../models/create_exam_draft_models.dart';
import 'create_exam_pdf_helper.dart';

/// Coordinates user interactions for picking, uploading, previewing, and bubble-sheeting PDF attachments.
class CreateExamPdfCoordinator {
  const CreateExamPdfCoordinator._();

  static Future<AttachedPdfResult?> pickFromLibrary(BuildContext context) async {
    return await CreateExamPdfHelper.pickPdfFromLibrary(context);
  }

  static Future<AttachedPdfResult?> pickFromDevice({
    required BuildContext context,
    required void Function(bool isUploading) onUploadStateChanged,
  }) async {
    try {
      return await CreateExamPdfHelper.pickPdfFromDevice(
        onUploadStateChanged: onUploadStateChanged,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return null;
    }
  }

  static void previewPdf({
    required BuildContext context,
    required String? storagePath,
    required String? fileName,
    required String? fileId,
    required int? fileSize,
    String? tenantId,
  }) {
    CreateExamPdfHelper.previewAttachedPdf(
      context: context,
      storagePath: storagePath,
      fileName: fileName,
      fileId: fileId,
      fileSize: fileSize,
      tenantId: tenantId,
    );
  }

  static Future<bool> handleQuickBubbleSheet({
    required BuildContext context,
    required int defaultPoints,
    required List<CreateExamDraftQuestion> questions,
    required void Function(CreateExamDraftQuestion) onBindListeners,
    required void Function(int totalScore, int points) onApplyScores,
  }) async {
    final result = await CreateExamPdfHelper.showQuickBubbleSheetDialog(
      context: context,
      initialPoints: defaultPoints,
      hasExistingQuestions: questions.isNotEmpty &&
          questions.any((q) => q.textController.text.isNotEmpty),
    );
    if (result == null || !context.mounted) return false;

    final totalScore = CreateExamPdfHelper.applyQuickBubbleSheetResult(
      result: result,
      questions: questions,
      onBindListeners: onBindListeners,
    );

    onApplyScores(totalScore, result.points);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.generateQuestions}: ${result.questionCount}'),
          backgroundColor: AppColors.success,
        ),
      );
    }

    return true;
  }
}
