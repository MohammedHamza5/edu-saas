import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../../../../core/di/injection_container.dart';
import '../../../notifications/domain/services/notification_dispatcher.dart';
import '../../domain/entities/library_material_entity.dart';
import '../cubit/content_cubit.dart';
import '../models/lesson_studio_models.dart';

/// Coordinates resolving lecture IDs, uploading PDF files, constructing batch payloads,
/// and dispatching notifications for Lesson Studio Workspace.
class LessonStudioSaveCoordinator {
  LessonStudioSaveCoordinator._();

  /// Resolves an existing material or uploads a new PDF to library/storage.
  static Future<String?> resolveOrUploadFileForLecture({
    required ContentCubit cubit,
    required String groupId,
    required String contentId,
    required String tenantId,
    LibraryMaterialEntity? libraryMaterial,
    PlatformFile? uploadedFile,
    Uint8List? uploadedBytes,
  }) async {
    // 1. If chosen from materials library: link directly without re-uploading
    if (libraryMaterial != null) {
      final linkRes = await InjectionContainer.materialsLibraryRepository
          .linkToLecture(
            libraryMaterialId: libraryMaterial.id,
            contentId: contentId,
            tenantId: tenantId,
          );
      if (linkRes.isSuccess && linkRes.dataOrNull != null) {
        return linkRes.dataOrNull;
      }
    }

    // 2. If uploaded from device: upload to teacher's Materials Library first so it is preserved!
    if (uploadedFile != null && uploadedBytes != null) {
      final cleanTitle = uploadedFile.name.replaceAll(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );

      final uploadRes = await InjectionContainer.materialsLibraryRepository
          .uploadMaterial(
            title: cleanTitle,
            fileName: uploadedFile.name,
            fileBytes: uploadedBytes,
            mimeType: 'application/pdf',
          );

      if (uploadRes.isSuccess && uploadRes.dataOrNull != null) {
        final newMaterial = uploadRes.dataOrNull!;
        final linkRes = await InjectionContainer.materialsLibraryRepository
            .linkToLecture(
              libraryMaterialId: newMaterial.id,
              contentId: contentId,
              tenantId: tenantId,
            );
        if (linkRes.isSuccess && linkRes.dataOrNull != null) {
          return linkRes.dataOrNull;
        }
      }

      // Fallback: direct storage upload if library upload fails
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeName = uploadedFile.name.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9_.-]'),
        '_',
      );
      final storagePath = 'groups/$groupId/${timestamp}_$safeName';

      return await cubit.uploadAndCreateFileRecord(
        tenantId: tenantId,
        contentId: contentId,
        fileName: uploadedFile.name,
        mimeType: 'application/pdf',
        fileBytes: uploadedBytes,
        storagePath: storagePath,
      );
    }

    return null;
  }

  /// Executes the complete batch save pipeline for staged lectures.
  static Future<bool> saveUnifiedBatch({
    required ContentCubit cubit,
    required String groupId,
    required List<StagedLecture> stagedLectures,
    String? batchGlobalChapterId,
    String? initialChapterId,
  }) async {
    if (stagedLectures.isEmpty) return false;

    final items = <Map<String, dynamic>>[];

    for (final staged in stagedLectures) {
      final title = staged.titleController.text.trim().isNotEmpty
          ? staged.titleController.text.trim()
          : staged.video.title;

      // 1. Resolve or create true content_id before file linking
      final actualContentId =
          await cubit.resolveOrCreateLectureContent(
            videoId: staged.video.id,
            groupId: groupId,
            title: title,
            tenantId: staged.video.tenantId,
          ) ??
          staged.video.id;

      // 2. Upload / link file using the true actualContentId
      final fileId = await resolveOrUploadFileForLecture(
        cubit: cubit,
        groupId: groupId,
        contentId: actualContentId,
        tenantId: staged.video.tenantId,
        libraryMaterial: staged.libraryMaterial,
        uploadedFile: staged.pdfFile,
        uploadedBytes: staged.pdfBytes,
      );

      final chapter =
          staged.chapterId ?? batchGlobalChapterId ?? initialChapterId;

      items.add({
        'content_id': actualContentId,
        'custom_title': title,
        if (chapter != null) 'chapter_id': chapter,
        'is_published': staged.isPublished,
        if (staged.attachedExams.isNotEmpty)
          'associated_exam_id': staged.attachedExams.first.examId,
        if (staged.attachedExams.isNotEmpty)
          'attached_exams': staged.attachedExams
              .asMap()
              .entries
              .map((e) => e.value.toJson(sortOrder: e.key))
              .toList(),
        if (staged.attachedExams.isEmpty) 'associated_exam_id': null,
        if (staged.attachedExams.isEmpty)
          'attached_exams': <Map<String, dynamic>>[],
        if (fileId != null) 'file_id': fileId,
      });
    }

    final success = await cubit.assignBatchContentToGroup(
      groupId: groupId,
      items: items,
    );

    if (success) {
      for (final staged in stagedLectures) {
        if (staged.isPublished) {
          final title = staged.titleController.text.trim().isNotEmpty
              ? staged.titleController.text.trim()
              : staged.video.title;
          unawaited(
            NotificationDispatcher.notifyNewLecture(
              title: title,
              groupId: groupId,
              contentId: staged.video.id,
              contentType: 'video',
            ),
          );
        }
      }
    }

    return success;
  }
}
