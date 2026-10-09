import '../../../../core/errors/result.dart';
import '../entities/chapter_entity.dart';
import '../entities/content_entity.dart';
import '../entities/lesson_assignment_entity.dart';

/// Contract for Academic Content operations
abstract class ContentRepository {
  /// Fetches content items for a specific group, ordered by sort_order ascending
  /// Teachers can specify a statusFilter (draft/published/archived).
  /// Students will only receive published content via RLS.
  Future<Result<List<ContentEntity>>> getGroupContent({
    required String groupId,
    ContentStatus? statusFilter,
    int page = 0,
    int pageSize = 20,
  });

  /// Creates a new content item (optional groupId for bank items)
  Future<Result<ContentEntity>> createContent({
    String? groupId,
    required String title,
    String? description,
    required ContentType type,
    required ContentStatus status,
    int? sortOrder,
    String? fileName,
    String? storagePath,
    String? mimeType,
    int? fileSize,
    List<int>? fileBytes,
    String? associatedExamId,
    String? prerequisiteExamId,
  });

  /// Updates an existing content item's metadata and optional attached file
  Future<Result<ContentEntity>> updateContent({
    required String contentId,
    String? title,
    String? description,
    ContentType? type,
    ContentStatus? status,
    int? sortOrder,
    String? fileName,
    String? storagePath,
    String? mimeType,
    int? fileSize,
    List<int>? fileBytes,
    String? associatedExamId,
    String? prerequisiteExamId,
  });

  /// Updates lifecycle status (e.g., Publish or Archive)
  Future<Result<void>> updateContentStatus({
    required String contentId,
    required ContentStatus status,
  });

  /// Reorders content items within a group atomically
  Future<Result<void>> reorderContentItems({
    required List<String> contentIdsInOrder,
    String? groupId,
  });

  /// Deletes a content item
  Future<Result<void>> deleteContent(String contentId);

  /// Generates a temporary secure signed URL for accessing a private storage file
  Future<Result<String>> getSignedFileUrl({
    required String storagePath,
    int expiresInSeconds = 3600,
  });

  /// Retrieves the centralized video bank for the tenant (all video lessons)
  Future<Result<List<ContentEntity>>> getCentralVideoBank({
    int page = 0,
    int pageSize = 100,
  });

  /// Assigns/synchronizes a content item to one or more groups
  Future<Result<void>> assignContentToGroups({
    required String contentId,
    required List<String> groupIds,
    List<Map<String, dynamic>>? groupConfigs,
  });

  /// Atomically assigns multiple content items/videos to a group in one transaction
  Future<Result<void>> assignBatchContentToGroup({
    required String groupId,
    required List<Map<String, dynamic>> items,
  });

  /// Links a quiz/exam to a lesson unit
  Future<Result<void>> linkLessonExam({
    required String contentId,
    required String examId,
  });

  /// Fetches the course progress for a specific group and student
  Future<Result<List<LessonAssignmentEntity>>> getGroupCourseProgress({
    required String groupId,
    String? studentId,
  });

  /// Manually unlocks a lesson for a specific student in a group
  Future<Result<void>> manualUnlockLesson({
    required String studentId,
    required String groupId,
    required String contentId,
    String? reason,
  });

  /// Toggles visibility of a single lesson in a group
  Future<Result<void>> toggleLessonVisibility({
    required String contentId,
    required String groupId,
    required bool isPublished,
  });

  /// Bulk toggles visibility of all lessons in a group
  Future<Result<void>> toggleAllLessonsVisibility({
    required String groupId,
    required bool isPublished,
  });

  /// Uploads a file (R2 or fallback) and creates a record in the files table.
  /// Returns the newly created file_id.
  Future<Result<String>> uploadAndCreateFileRecord({
    required String tenantId,
    required String contentId,
    required String fileName,
    required String mimeType,
    required List<int> fileBytes,
    required String storagePath,
  });

  /// Fetches chapters belonging to a group
  Future<Result<List<ChapterEntity>>> getGroupChapters(String groupId);

  /// Creates a new chapter for a group
  Future<Result<ChapterEntity>> createChapter({
    required String groupId,
    required String title,
    bool isPublished = true,
  });

  /// Toggles chapter visibility (published/draft)
  Future<Result<void>> toggleChapterVisibility({
    required String chapterId,
    required bool isPublished,
  });

  /// Updates chapter title
  Future<Result<void>> updateChapter({
    required String chapterId,
    required String title,
  });

  /// Deletes a chapter
  Future<Result<void>> deleteChapter(String chapterId);

  /// Moves or sets a lesson to a chapter
  Future<Result<void>> setLessonChapter({
    required String contentId,
    required String groupId,
    String? chapterId,
  });

  /// Reorders lessons within a chapter or course
  Future<Result<void>> reorderChapterLessons({
    required String groupId,
    required List<String> contentIdsInOrder,
  });

  /// Reorders chapters within a course
  Future<Result<void>> reorderCourseChapters({
    required String groupId,
    required List<String> chapterIdsInOrder,
  });

  /// Removes a lesson from a group
  Future<Result<void>> removeLessonFromGroup({
    required String contentId,
    required String groupId,
  });
}
