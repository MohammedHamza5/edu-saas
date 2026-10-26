import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../content/domain/entities/content_entity.dart';
import '../../../content/domain/entities/file_attachment_entity.dart';
import '../../../content/presentation/dialogs/select_material_from_library_dialog.dart';
import '../../../content/presentation/widgets/material_viewer_sheet.dart';
import '../cubit/exams_cubit.dart';

/// Value object representing an attached PDF booklet file.
class AttachedPdfResult {
  final String id;
  final String fileName;
  final int fileSize;
  final String storagePath;

  const AttachedPdfResult({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.storagePath,
  });
}

/// Helper utility for selecting, uploading, and previewing attached exam PDF booklets.
class CreateExamPdfHelper {
  CreateExamPdfHelper._();

  /// Picks an existing material from the teacher's library.
  static Future<AttachedPdfResult?> pickPdfFromLibrary(
    BuildContext context,
  ) async {
    final selected = await SelectMaterialFromLibraryDialog.show(context);
    if (selected != null) {
      return AttachedPdfResult(
        id: selected.id,
        fileName: selected.fileName,
        fileSize: selected.fileSize,
        storagePath: selected.storagePath,
      );
    }
    return null;
  }

  /// Picks a PDF file from device storage, checks for duplicates, and uploads if needed.
  static Future<AttachedPdfResult?> pickPdfFromDevice({
    required void Function(bool isUploading) onUploadStateChanged,
  }) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return null;

    final file = res.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;

    onUploadStateChanged(true);
    try {
      final computedHash = sha256.convert(bytes).toString();
      final dupRes =
          await InjectionContainer.materialsLibraryRepository.checkDuplicate(
        fileHash: computedHash,
        fileName: file.name,
        fileSize: file.size,
      );

      final duplicate = dupRes.dataOrNull;
      if (duplicate != null) {
        onUploadStateChanged(false);
        return AttachedPdfResult(
          id: duplicate.id,
          fileName: duplicate.fileName,
          fileSize: duplicate.fileSize,
          storagePath: duplicate.storagePath,
        );
      }

      final cleanTitle =
          file.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      final uploadRes =
          await InjectionContainer.materialsLibraryRepository.uploadMaterial(
        title: cleanTitle,
        fileName: file.name,
        fileBytes: Uint8List.fromList(bytes),
        mimeType: 'application/pdf',
      );

      onUploadStateChanged(false);
      if (uploadRes.isSuccess && uploadRes.dataOrNull != null) {
        final uploaded = uploadRes.dataOrNull!;
        return AttachedPdfResult(
          id: uploaded.id,
          fileName: uploaded.fileName,
          fileSize: uploaded.fileSize,
          storagePath: uploaded.storagePath,
        );
      } else {
        throw Exception(
          uploadRes.failureOrNull?.message ?? 'Failed to upload PDF',
        );
      }
    } catch (_) {
      onUploadStateChanged(false);
      rethrow;
    }
  }

  /// Opens the PDF material viewer sheet to preview the attached booklet.
  static void previewAttachedPdf({
    required BuildContext context,
    required String? storagePath,
    required String? fileName,
    required String? fileId,
    required int? fileSize,
    required String? tenantId,
  }) {
    if (storagePath == null || storagePath.isEmpty) return;

    MaterialViewerSheet.show(
      context,
      content: ContentEntity(
        id: '',
        tenantId: tenantId ?? '',
        title: fileName ?? context.l10n.viewExamBooklet,
        type: ContentType.pdf,
        status: ContentStatus.published,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        file: FileAttachmentEntity(
          id: fileId ?? '',
          tenantId: tenantId ?? '',
          contentId: '',
          storagePath: storagePath,
          fileName: fileName ?? 'booklet.pdf',
          mimeType: 'application/pdf',
          fileSize: fileSize ?? 0,
          createdAt: DateTime.now(),
        ),
      ),
      onGetSignedUrl: (path) =>
          context.read<ExamsCubit>().getSignedPdfUrl(path),
    );
  }
}
