import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/video_entity.dart';
import '../../domain/entities/video_progress_entity.dart';
import '../../domain/repositories/videos_repository.dart';
import '../datasources/videos_remote_datasource.dart';

class VideosRepositoryImpl implements VideosRepository {
  final VideosRemoteDataSource _remoteDataSource;

  /// In-memory cache for generated signed URLs with expiration tracking.
  static final Map<String, ({String url, DateTime expiresAt})> _signedUrlCache =
      {};

  /// Clears the in-memory signed URL cache (useful for testing or cache resets).
  static void clearSignedUrlCache() {
    _signedUrlCache.clear();
  }

  const VideosRepositoryImpl({required VideosRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  @override
  Future<Result<List<VideoEntity>>> getVideosForGroup(String groupId) async {
    try {
      final videos = await _remoteDataSource.getVideosForGroup(groupId);
      return Result.success(videos);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<VideoEntity>> getVideoById(String videoId) async {
    try {
      final video = await _remoteDataSource.getVideoById(videoId);
      return Result.success(video);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<String>> getPlaybackUrl(String videoId) async {
    try {
      final url = await _remoteDataSource.getPlaybackUrl(videoId);
      return Result.success(url);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<VideoProgressEntity?>> getVideoProgress({
    required String videoId,
    required String studentId,
  }) async {
    try {
      final progress = await _remoteDataSource.getVideoProgress(
        videoId: videoId,
        studentId: studentId,
      );
      return Result.success(progress);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<VideoProgressEntity>> updateVideoProgress({
    required String videoId,
    required String studentId,
    required int progressSeconds,
    required int durationSeconds,
    int furthestPositionSeconds = 0,
    int actualWatchSeconds = 0,
    bool isSkipped = false,
    List<int>? newSegment,
  }) async {
    try {
      final progress = await _remoteDataSource.updateVideoProgress(
        videoId: videoId,
        studentId: studentId,
        progressSeconds: progressSeconds,
        durationSeconds: durationSeconds,
        furthestPositionSeconds: furthestPositionSeconds,
        actualWatchSeconds: actualWatchSeconds,
        isSkipped: isSkipped,
        newSegment: newSegment,
      );
      return Result.success(progress);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<VideoEntity>> createAndUploadVideo({
    required String contentId,
    required String title,
    required List<int> videoBytes,
    required String fileName,
    void Function(int sentBytes, int totalBytes)? onProgress,
  }) async {
    try {
      final video = await _remoteDataSource.createAndUploadVideo(
        contentId: contentId,
        title: title,
        videoBytes: videoBytes,
        fileName: fileName,
        onProgress: onProgress,
      );
      return Result.success(video);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteVideo(String videoId) async {
    try {
      await _remoteDataSource.deleteVideo(videoId);
      return const Result.success(null);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<String>> getSignedFileUrl(String storagePath) async {
    final cached = _signedUrlCache[storagePath];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return Result.success(cached.url);
    }

    try {
      final url = await _remoteDataSource.getSignedFileUrl(
        storagePath: storagePath,
      );
      _signedUrlCache[storagePath] = (
        url: url,
        expiresAt: DateTime.now().add(const Duration(minutes: 50)),
      );
      return Result.success(url);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<VideoEntity>> attachMaterialToVideo({
    required String videoId,
    required String contentId,
    required String fileName,
    required List<int> fileBytes,
  }) async {
    try {
      final video = await _remoteDataSource.attachMaterialToVideo(
        videoId: videoId,
        contentId: contentId,
        fileName: fileName,
        fileBytes: fileBytes,
      );
      return Result.success(video);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<VideoEntity>> linkYouTubeVideo({
    required String contentId,
    required String youtubeUrl,
    String? title,
  }) async {
    try {
      final video = await _remoteDataSource.linkYouTubeVideo(
        contentId: contentId,
        youtubeUrl: youtubeUrl,
        title: title,
      );
      return Result.success(video);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>?>> getLessonContext({
    required String contentId,
    required String groupId,
  }) async {
    try {
      final ctx = await _remoteDataSource.getLessonContext(
        contentId: contentId,
        groupId: groupId,
      );
      return Result.success(ctx);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }
}
