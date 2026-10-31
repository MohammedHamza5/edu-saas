import '../../../videos/domain/entities/library_video_entity.dart';
import '../../domain/entities/content_entity.dart';
import '../../domain/entities/library_material_entity.dart';
import '../models/lesson_studio_models.dart';

/// Prepopulates a [StagedLecture] with existing course settings
/// if the video is already configured in the current group.
class LessonStudioPrepopulator {
  const LessonStudioPrepopulator._();

  static StagedLecture createStagedLecture({
    required LibraryVideoEntity video,
    required List<ContentEntity> existingItems,
    String? defaultChapterId,
    bool defaultPublished = true,
  }) {
    String initialTitle = video.title;
    String? initialChapter = defaultChapterId;
    bool isPublished = defaultPublished;
    LibraryMaterialEntity? initialMaterial;
    List<StudioAttachedExam>? initialExams;

    final existing = existingItems
        .where(
          (item) =>
              item.id == video.id ||
              item.videoId == video.id ||
              item.videoProviderId == video.providerVideoId,
        )
        .firstOrNull;

    if (existing != null) {
      initialTitle = existing.title;
      isPublished = existing.isPublishedInGroup;
      if (existing.chapterId != null) {
        initialChapter = existing.chapterId;
      }
      if (existing.attachedExams.isNotEmpty) {
        initialExams = existing.attachedExams
            .map(
              (e) => StudioAttachedExam(
                examId: e.examId,
                examTitle: e.examTitle,
                isRequired: e.isRequired,
              ),
            )
            .toList();
      }
      if (existing.file != null) {
        final f = existing.file!;
        initialMaterial = LibraryMaterialEntity(
          id: f.id,
          tenantId: f.tenantId,
          title: f.fileName.replaceAll(
            RegExp(r'\.pdf$', caseSensitive: false),
            '',
          ),
          fileName: f.fileName,
          storagePath: f.storagePath,
          fileSize: f.fileSize,
          mimeType: f.mimeType,
          storageProvider: f.storageProvider,
          createdAt: f.createdAt,
          updatedAt: f.createdAt,
        );
      }
    }

    return StagedLecture(
      video: video,
      initialTitle: initialTitle,
      chapterId: initialChapter,
      isPublished: isPublished,
      initialExams: initialExams,
      libraryMaterial: initialMaterial,
    );
  }
}
