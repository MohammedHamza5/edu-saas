import '../../../../core/errors/result.dart';
import '../entities/library_video_entity.dart';
import '../entities/video_folder_entity.dart';

abstract interface class VideoBankRepository {
  Future<Result<List<VideoFolderEntity>>> getFolders({String? parentId});

  Future<Result<List<VideoFolderEntity>>> getAllFolders();

  Future<Result<VideoFolderEntity>> createFolder({
    required String name,
    String? parentId,
  });

  Future<Result<VideoFolderEntity>> updateFolder({
    required String id,
    required String name,
  });

  Future<Result<void>> deleteFolder(String id);

  Future<Result<List<LibraryVideoEntity>>> getVideos({
    String? folderId,
    String? search,
  });

  Future<Result<LibraryVideoEntity>> getVideoById(String id);

  Future<Result<LibraryVideoEntity>> uploadVideo({
    required String title,
    String? description,
    String? folderId,
    required List<int> videoBytes,
    void Function(int sentBytes, int totalBytes)? onProgress,
  });

  /// Cancels any currently active binary video upload stream
  void cancelActiveUpload();

  Future<Result<LibraryVideoEntity>> syncVideoStatus(String libraryVideoId);

  Future<Result<void>> deleteVideo(String id);

  Future<Result<LibraryVideoEntity>> moveVideo({
    required String id,
    String? targetFolderId,
  });

  Future<Result<LibraryVideoEntity>> updateVideo({
    required String id,
    required String title,
    String? description,
  });

  Future<Result<String>> getPlaybackUrl(String libraryVideoId);

  Future<Result<void>> linkToLectureContent({
    required String libraryVideoId,
    required String contentId,
    required String title,
  });
}
