import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/content_entity.dart';
import '../../domain/entities/library_material_entity.dart';
import '../cubit/content_cubit.dart';

/// Helper for uploading or linking study material PDFs in [LessonEditorPane].
class LessonEditorPdfUploader {
  const LessonEditorPdfUploader._();

  static Future<String?> uploadPdfIfNeeded({
    required ContentCubit cubit,
    required bool removePdf,
    required LibraryMaterialEntity? selectedLibraryMaterial,
    required ContentEntity? selectedVideo,
    required ContentEntity? editingLesson,
    required PlatformFile? pickedFile,
    required Uint8List? pickedFileBytes,
    required String? currentFileId,
    required String groupId,
  }) async {
    if (removePdf) return null;

    // 1. If chosen from materials library: link directly without re-uploading
    if (selectedLibraryMaterial != null && selectedVideo != null) {
      final targetContentId = editingLesson?.id ?? selectedVideo.id;
      final linkRes = await InjectionContainer.materialsLibraryRepository.linkToLecture(
        libraryMaterialId: selectedLibraryMaterial.id,
        contentId: targetContentId,
        tenantId: selectedVideo.tenantId,
      );
      if (linkRes.isSuccess && linkRes.dataOrNull != null) {
        return linkRes.dataOrNull;
      }
    }

    if (pickedFile == null || pickedFileBytes == null) return currentFileId;

    // 2. If uploaded from device: upload to teacher's Materials Library first so it is preserved!
    if (selectedVideo != null) {
      final cleanTitle = pickedFile.name.replaceAll(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );

      final uploadRes = await InjectionContainer.materialsLibraryRepository.uploadMaterial(
        title: cleanTitle,
        fileName: pickedFile.name,
        fileBytes: pickedFileBytes,
        mimeType: 'application/pdf',
      );

      if (uploadRes.isSuccess && uploadRes.dataOrNull != null) {
        final newMat = uploadRes.dataOrNull!;
        final targetContentId = editingLesson?.id ?? selectedVideo.id;
        final linkRes = await InjectionContainer.materialsLibraryRepository.linkToLecture(
          libraryMaterialId: newMat.id,
          contentId: targetContentId,
          tenantId: selectedVideo.tenantId,
        );
        if (linkRes.isSuccess && linkRes.dataOrNull != null) {
          return linkRes.dataOrNull;
        }
      }
    }

    // Fallback: direct storage upload
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = pickedFile.name.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_.-]'),
      '_',
    );
    final storagePath = 'groups/$groupId/${timestamp}_$safeName';

    return await cubit.uploadAndCreateFileRecord(
      tenantId: selectedVideo?.tenantId ?? '',
      contentId: selectedVideo?.id ?? '',
      fileName: pickedFile.name,
      mimeType: 'application/pdf',
      fileBytes: pickedFileBytes,
      storagePath: storagePath,
    );
  }
}
