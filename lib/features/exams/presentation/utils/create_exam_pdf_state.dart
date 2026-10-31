import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import 'create_exam_pdf_coordinator.dart';
import 'create_exam_pdf_helper.dart';

/// State and actions container for PDF attachment in the exam creator.
class CreateExamPdfState {
  String? fileId;
  String? fileName;
  int? fileSize;
  String? storagePath;
  bool isUploading = false;
  bool clearPdfOnSave = false;

  bool get hasPdf =>
      (fileId != null && fileId!.isNotEmpty) ||
      (storagePath != null && storagePath!.isNotEmpty);

  void applyResult(
    BuildContext context,
    AttachedPdfResult result, {
    required VoidCallback onStateChanged,
    required VoidCallback onScheduleAutoSave,
  }) {
    fileId = result.id;
    fileName = result.fileName;
    fileSize = result.fileSize;
    storagePath = result.storagePath;
    clearPdfOnSave = false;
    onStateChanged();
    onScheduleAutoSave();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.pdfAttachedSuccess),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> pickFromLibrary(
    BuildContext context, {
    required VoidCallback onStateChanged,
    required VoidCallback onScheduleAutoSave,
  }) async {
    final result = await CreateExamPdfCoordinator.pickFromLibrary(context);
    if (result != null && context.mounted) {
      applyResult(
        context,
        result,
        onStateChanged: onStateChanged,
        onScheduleAutoSave: onScheduleAutoSave,
      );
    }
  }

  Future<void> pickFromDevice(
    BuildContext context, {
    required void Function(bool) onUploadStateChanged,
    required VoidCallback onStateChanged,
    required VoidCallback onScheduleAutoSave,
  }) async {
    final result = await CreateExamPdfCoordinator.pickFromDevice(
      context: context,
      onUploadStateChanged: (uploading) {
        isUploading = uploading;
        onUploadStateChanged(uploading);
      },
    );
    if (result != null && context.mounted) {
      applyResult(
        context,
        result,
        onStateChanged: onStateChanged,
        onScheduleAutoSave: onScheduleAutoSave,
      );
    }
  }

  void removePdf({
    required VoidCallback onStateChanged,
    required VoidCallback onScheduleAutoSave,
  }) {
    fileId = null;
    fileName = null;
    fileSize = null;
    storagePath = null;
    clearPdfOnSave = true;
    onStateChanged();
    onScheduleAutoSave();
  }

  void previewPdf(BuildContext context, {String? tenantId}) {
    CreateExamPdfCoordinator.previewPdf(
      context: context,
      storagePath: storagePath,
      fileName: fileName,
      fileId: fileId,
      fileSize: fileSize,
      tenantId: tenantId,
    );
  }
}
