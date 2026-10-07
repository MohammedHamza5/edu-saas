import 'package:dio/dio.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/library_video_entity.dart';
import '../../domain/entities/video_folder_entity.dart';
import '../../domain/repositories/video_bank_repository.dart';
import '../datasources/video_bank_remote_datasource.dart';

class VideoBankRepositoryImpl implements VideoBankRepository {
  final VideoBankRemoteDataSource _remoteDataSource;
  CancelToken? _activeUploadCancelToken;
  String? _activeLibraryVideoId;

  VideoBankRepositoryImpl({
    required VideoBankRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<Result<List<VideoFolderEntity>>> getFolders({String? parentId}) async {
    try {
      final folders = await _remoteDataSource.getFolders(parentId: parentId);
      return Result.success(folders);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<VideoFolderEntity>>> getAllFolders() async {
    try {
      final folders = await _remoteDataSource.getAllFolders();
      return Result.success(folders);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<VideoFolderEntity>> createFolder({
    required String name,
    String? parentId,
  }) async {
    try {
      final folder = await _remoteDataSource.createFolder(
        name: name,
        parentId: parentId,
      );
      return Result.success(folder);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<VideoFolderEntity>> updateFolder({
    required String id,
    required String name,
  }) async {
    try {
      final folder = await _remoteDataSource.updateFolder(id: id, name: name);
      return Result.success(folder);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteFolder(String id) async {
    try {
      await _remoteDataSource.deleteFolder(id);
      return const Result.success(null);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<LibraryVideoEntity>>> getVideos({
    String? folderId,
    String? search,
  }) async {
    try {
      final videos = await _remoteDataSource.getVideos(
        folderId: folderId,
        search: search,
      );
      return Result.success(videos);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<LibraryVideoEntity>> getVideoById(String id) async {
    try {
      final video = await _remoteDataSource.getVideoById(id);
      return Result.success(video);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<LibraryVideoEntity>> uploadVideo({
    required String title,
    String? description,
    String? folderId,
    required List<int> videoBytes,
    void Function(int sentBytes, int totalBytes)? onProgress,
  }) async {
    try {
      // 1. Initialize upload session via Bunny Edge Function
      final initData = await _remoteDataSource.createBankUpload(
        title: title,
        description: description,
        folderId: folderId,
      );

      final libraryVideoId = initData['library_video_id'] as String;
      final videoGuid = initData['video_guid'] as String;
      final libraryId = initData['library_id'].toString();
      final tusEndpoint = initData['tus_endpoint'] as String;
      final signature = initData['signature'] as String;
      final expire = initData['expire'] as int;

      _activeUploadCancelToken = CancelToken();
      _activeLibraryVideoId = libraryVideoId;

      // 2. Upload binary stream via TUS with onProgress
      await _remoteDataSource.uploadVideoBytes(
        tusEndpoint: tusEndpoint,
        videoGuid: videoGuid,
        libraryId: libraryId,
        signature: signature,
        expire: expire,
        videoBytes: videoBytes,
        onProgress: onProgress,
        cancelToken: _activeUploadCancelToken,
      );

      _activeUploadCancelToken = null;
      _activeLibraryVideoId = null;

      // 3. Return latest record
      final video = await _remoteDataSource.getVideoById(libraryVideoId);
      return Result.success(video);
    } on ServerException catch (e) {
      _activeUploadCancelToken = null;
      _activeLibraryVideoId = null;
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      _activeUploadCancelToken = null;
      _activeLibraryVideoId = null;
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  void cancelActiveUpload() {
    _activeUploadCancelToken?.cancel('Upload cancelled by user');
    _activeUploadCancelToken = null;
    final toDeleteId = _activeLibraryVideoId;
    _activeLibraryVideoId = null;
    if (toDeleteId != null) {
      _remoteDataSource.deleteVideo(toDeleteId).ignore();
    }
  }

  @override
  Future<Result<LibraryVideoEntity>> syncVideoStatus(
    String libraryVideoId,
  ) async {
    try {
      final video = await _remoteDataSource.syncVideoStatus(libraryVideoId);
      return Result.success(video);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteVideo(String id) async {
    try {
      await _remoteDataSource.deleteVideo(id);
      return const Result.success(null);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<LibraryVideoEntity>> moveVideo({
    required String id,
    String? targetFolderId,
  }) async {
    try {
      final video = await _remoteDataSource.moveVideo(
        id: id,
        targetFolderId: targetFolderId,
      );
      return Result.success(video);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<LibraryVideoEntity>> updateVideo({
    required String id,
    required String title,
    String? description,
  }) async {
    try {
      final video = await _remoteDataSource.updateVideo(
        id: id,
        title: title,
        description: description,
      );
      return Result.success(video);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<String>> getPlaybackUrl(String libraryVideoId) async {
    try {
      final url = await _remoteDataSource.getPlaybackUrl(libraryVideoId);
      return Result.success(url);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> linkToLectureContent({
    required String libraryVideoId,
    required String contentId,
    required String title,
  }) async {
    try {
      await _remoteDataSource.linkToLectureContent(
        libraryVideoId: libraryVideoId,
        contentId: contentId,
        title: title,
      );
      return const Result.success(null);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> assignFolderAsChapter({
    required String folderId,
    required String groupId,
    String? chapterTitle,
  }) async {
    try {
      final res = await _remoteDataSource.assignFolderAsChapter(
        folderId: folderId,
        groupId: groupId,
        chapterTitle: chapterTitle,
      );
      return Result.success(res);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }
}
