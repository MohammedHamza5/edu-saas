import '../../../../core/errors/result.dart';
import '../entities/video_entity.dart';
import '../entities/video_progress_entity.dart';

abstract interface class VideosRepository {
  /// Fetches videos associated with a specific group or content.
  Future<Result<List<VideoEntity>>> getVideosForGroup(String groupId);

  /// Fetches video details by ID.
  Future<Result<VideoEntity>> getVideoById(String videoId);

  /// Gets a signed, temporary Tokenized HLS playback URL from Bunny Stream.
  Future<Result<String>> getPlaybackUrl(String videoId);

  /// Fetches the current progress of a student on a specific video.
  Future<Result<VideoProgressEntity?>> getVideoProgress({
    required String videoId,
    required String studentId,
  });

  /// Updates or records student watch progress (Throttled UPSERT).
  Future<Result<VideoProgressEntity>> updateVideoProgress({
    required String videoId,
    required String studentId,
    required int progressSeconds,
    required int durationSeconds,
    int actualWatchSeconds = 0,
    bool isSkipped = false,
  });

  /// Direct Upload for Teachers: creates Bunny video object and uploads binary data.
  Future<Result<VideoEntity>> createAndUploadVideo({
    required String contentId,
    required String title,
    required List<int> videoBytes,
    required String fileName,
    void Function(int sentBytes, int totalBytes)? onProgress,
  });

  /// Deletes a video record.
  Future<Result<void>> deleteVideo(String videoId);

  /// Gets a signed URL to download or view a private attachment.
  Future<Result<String>> getSignedFileUrl(String storagePath);

  /// Attaches supplementary material (e.g. PDF notes) directly to a video lesson.
  Future<Result<VideoEntity>> attachMaterialToVideo({
    required String videoId,
    required String contentId,
    required String fileName,
    required List<int> fileBytes,
  });

  /// Links an unlisted or public YouTube video/live stream to a content item.
  Future<Result<VideoEntity>> linkYouTubeVideo({
    required String contentId,
    required String youtubeUrl,
    String? title,
  });
}
