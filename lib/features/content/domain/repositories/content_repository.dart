import '../../../../core/errors/result.dart';
import '../entities/content_entity.dart';

/// Contract for Academic Content operations
abstract class ContentRepository {
  /// Fetches content items for a specific group, ordered by sort_order ascending
  /// Teachers can specify a statusFilter (draft/published/archived).
  /// Students will only receive published content via RLS.
  Future<Result<List<ContentEntity>>> getGroupContent({
    required String groupId,
    ContentStatus? statusFilter,
  });

  /// Creates a new content item under the specified group
  Future<Result<ContentEntity>> createContent({
    required String groupId,
    required String title,
    String? description,
    required ContentType type,
    required ContentStatus status,
    int? sortOrder,
    String? fileName,
    String? storagePath,
    String? mimeType,
    int? fileSize,
  });

  /// Updates an existing content item's metadata
  Future<Result<ContentEntity>> updateContent({
    required String contentId,
    String? title,
    String? description,
    ContentType? type,
    ContentStatus? status,
    int? sortOrder,
  });

  /// Updates lifecycle status (e.g., Publish or Archive)
  Future<Result<void>> updateContentStatus({
    required String contentId,
    required ContentStatus status,
  });

  /// Reorders content items within a group atomically
  Future<Result<void>> reorderContentItems({
    required List<String> contentIdsInOrder,
  });

  /// Deletes a content item
  Future<Result<void>> deleteContent(String contentId);

  /// Generates a temporary secure signed URL for accessing a private storage file
  Future<Result<String>> getSignedFileUrl({
    required String storagePath,
    int expiresInSeconds = 3600,
  });
}
