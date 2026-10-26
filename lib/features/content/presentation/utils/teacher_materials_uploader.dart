import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/materials_library_cubit.dart';

/// Helper utility for multi-file PDF picking, incremental upload progress tracking,
/// duplicate detection, and user notification snackbars.
class TeacherMaterialsUploader {
  TeacherMaterialsUploader._();

  /// Prompts teacher to pick one or more PDF files and uploads them sequentially with progress reporting.
  static Future<void> pickAndUploadFiles({
    required BuildContext context,
    required MaterialsLibraryCubit cubit,
  }) async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
        withData: true,
      );

      if (res == null || res.files.isEmpty || !context.mounted) return;

      final totalFiles = res.files.length;
      int addedCount = 0;
      int duplicateCount = 0;
      final failedFiles = <String>[];

      for (int i = 0; i < totalFiles; i++) {
        final file = res.files[i];
        if (file.bytes == null) continue;

        if (context.mounted) {
          cubit.updateUploadStatus(
            isUploading: true,
            progress: (i + 1) / totalFiles,
            fileName: file.name,
            totalFiles: totalFiles,
            currentIndex: i + 1,
          );
        }

        try {
          final item = await cubit.uploadMaterial(
            title: file.name.replaceAll(
              RegExp(r'\.pdf$', caseSensitive: false),
              '',
            ),
            fileName: file.name,
            fileBytes: file.bytes!,
            mimeType: 'application/pdf',
          );

          if (item != null) {
            if (item.createdAt.difference(DateTime.now()).inSeconds.abs() >
                30) {
              duplicateCount++;
            } else {
              addedCount++;
            }
          } else {
            failedFiles.add(file.name);
          }
        } catch (_) {
          failedFiles.add(file.name);
        }
      }

      if (context.mounted) {
        cubit.updateUploadStatus(
          isUploading: false,
          progress: 1.0,
          totalFiles: totalFiles,
          currentIndex: totalFiles,
        );

        final l10n = context.l10n;
        final messenger = ScaffoldMessenger.of(context);

        if (failedFiles.isNotEmpty) {
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text(
                l10n.uploadMaterialError(
                  failedFiles.join(', '),
                  l10n.errorOccurred,
                ),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        } else if (duplicateCount > 0 && addedCount == 0) {
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: AppColors.primary,
              content: Text(l10n.materialDuplicateNotice),
              duration: const Duration(seconds: 3),
            ),
          );
        } else if (addedCount > 0) {
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Text(
                l10n.uploadMaterialSuccess(
                  totalFiles == 1 ? res.files.first.name : '$addedCount files',
                ),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        cubit.updateUploadStatus(isUploading: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(
              context.l10n.uploadMaterialError('File', e.toString()),
            ),
          ),
        );
      }
    }
  }
}
