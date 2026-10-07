import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/supabase_service.dart';
import '../models/library_video_model.dart';
import '../models/video_folder_model.dart';

abstract interface class VideoBankRemoteDataSource {
  Future<List<VideoFolderModel>> getFolders({String? parentId});

  Future<List<VideoFolderModel>> getAllFolders();

  Future<VideoFolderModel> createFolder({
    required String name,
    String? parentId,
  });

  Future<VideoFolderModel> updateFolder({
    required String id,
    required String name,
  });

  Future<void> deleteFolder(String id);

  Future<List<LibraryVideoModel>> getVideos({
    String? folderId,
    String? search,
  });

  Future<LibraryVideoModel> getVideoById(String id);

  Future<Map<String, dynamic>> createBankUpload({
    required String title,
    String? description,
    String? folderId,
  });

  Future<void> uploadVideoBytes({
    required String tusEndpoint,
    required String videoGuid,
    required String libraryId,
    required String signature,
    required int expire,
    required List<int> videoBytes,
    void Function(int sentBytes, int totalBytes)? onProgress,
    CancelToken? cancelToken,
  });

  Future<LibraryVideoModel> syncVideoStatus(String libraryVideoId);

  Future<void> deleteVideo(String id);

  Future<LibraryVideoModel> moveVideo({
    required String id,
    String? targetFolderId,
  });

  Future<LibraryVideoModel> updateVideo({
    required String id,
    required String title,
    String? description,
  });

  Future<String> getPlaybackUrl(String libraryVideoId);

  Future<void> linkToLectureContent({
    required String libraryVideoId,
    required String contentId,
    required String title,
  });

  Future<Map<String, dynamic>> assignFolderAsChapter({
    required String folderId,
    required String groupId,
    String? chapterTitle,
  });
}

class VideoBankRemoteDataSourceImpl implements VideoBankRemoteDataSource {
  final SupabaseClient? _client;
  final Dio _dio;

  VideoBankRemoteDataSourceImpl({SupabaseClient? client, Dio? dio})
    : _client = client,
      _dio = dio ?? Dio();

  SupabaseClient get _c => _client ?? SupabaseService.client;

  Future<String> _resolveTenantId() async {
    final cached = SupabaseService.currentTenantId;
    if (cached != null && cached.isNotEmpty) return cached;
    final uid = _c.auth.currentUser?.id;
    if (uid != null) {
      final userRow = await _c
          .from('users')
          .select('tenant_id')
          .eq('id', uid)
          .maybeSingle();
      if (userRow != null && userRow['tenant_id'] != null) {
        return userRow['tenant_id'] as String;
      }
    }
    throw const ServerException(
      'Tenant ID could not be resolved',
      code: 'TENANT_NOT_FOUND',
    );
  }

  @override
  Future<List<VideoFolderModel>> getFolders({String? parentId}) async {
    try {
      var query = _c.from('video_folders_with_counts').select();

      if (parentId == null) {
        query = query.filter('parent_id', 'is', 'null');
      } else {
        query = query.eq('parent_id', parentId);
      }

      final response = await query.order('name', ascending: true);
      final list = response as List<dynamic>;

      return list
          .map((json) => VideoFolderModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<VideoFolderModel>> getAllFolders() async {
    try {
      final response = await _c
          .from('video_folders_with_counts')
          .select()
          .order('name', ascending: true);

      final list = response as List<dynamic>;
      return list
          .map((json) => VideoFolderModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<VideoFolderModel> createFolder({
    required String name,
    String? parentId,
  }) async {
    try {
      final tenantId = await _resolveTenantId();
      final response = await _c
          .from('video_folders')
          .insert({
            'tenant_id': tenantId,
            'name': name.trim(),
            'parent_id': parentId,
          })
          .select()
          .single();

      return VideoFolderModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<VideoFolderModel> updateFolder({
    required String id,
    required String name,
  }) async {
    try {
      final response = await _c
          .from('video_folders')
          .update({'name': name.trim(), 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', id)
          .select()
          .single();

      return VideoFolderModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> deleteFolder(String id) async {
    try {
      await _c.from('video_folders').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<LibraryVideoModel>> getVideos({
    String? folderId,
    String? search,
  }) async {
    try {
      var query = _c
          .from('video_library')
          .select('*, videos(id, content(group:groups(name)))');

      if (search != null && search.trim().isNotEmpty) {
        query = query.ilike('title', '%${search.trim()}%');
      } else if (folderId != null) {
        query = query.eq('folder_id', folderId);
      } else {
        query = query.filter('folder_id', 'is', 'null');
      }

      final response = await query.order('created_at', ascending: false);
      final list = response as List<dynamic>;

      return list
          .map((json) => LibraryVideoModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<LibraryVideoModel> getVideoById(String id) async {
    try {
      final response = await _c
          .from('video_library')
          .select('*, videos(id, content(group:groups(name)))')
          .eq('id', id)
          .single();

      return LibraryVideoModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> createBankUpload({
    required String title,
    String? description,
    String? folderId,
  }) async {
    try {
      final response = await _c.functions.invoke(
        'bunny-video',
        body: {
          'action': 'create-bank-upload',
          'title': title.trim(),
          'description': description?.trim(),
          'folder_id': folderId,
        },
      );

      if (response.status != 200 || response.data == null) {
        throw ServerException(
          'Failed to initialize video upload: ${response.status}',
          code: 'VIDEO_INIT_FAILED',
        );
      }

      final data = response.data as Map<String, dynamic>;
      if (data['error'] != null) {
        throw ServerException(
          data['error'].toString(),
          code: 'VIDEO_INIT_FAILED',
        );
      }

      return data;
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> uploadVideoBytes({
    required String tusEndpoint,
    required String videoGuid,
    required String libraryId,
    required String signature,
    required int expire,
    required List<int> videoBytes,
    void Function(int sentBytes, int totalBytes)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final payloadBytes = videoBytes is Uint8List
          ? videoBytes
          : Uint8List.fromList(videoBytes);

      // Step 1: Create TUS session
      final tusCreateResponse = await _dio.post<dynamic>(
        tusEndpoint,
        cancelToken: cancelToken,
        options: Options(
          headers: {
            'Upload-Length': payloadBytes.length.toString(),
            'Tus-Resumable': '1.0.0',
            'AuthorizationSignature': signature,
            'AuthorizationExpire': expire.toString(),
            'VideoId': videoGuid,
            'LibraryId': libraryId,
          },
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );

      final location = tusCreateResponse.headers.value('Location');
      if (location == null || location.isEmpty) {
        throw const ServerException(
          'Failed to create TUS upload session',
          code: 'TUS_INIT_FAILED',
        );
      }

      final uploadUrl = location.startsWith('http')
          ? location
          : 'https://video.bunnycdn.com$location';

      // Step 2: Upload Binary
      await _dio.patch<dynamic>(
        uploadUrl,
        data: payloadBytes,
        cancelToken: cancelToken,
        options: Options(
          headers: {
            'Upload-Offset': '0',
            'Content-Type': 'application/offset+octet-stream',
            'Tus-Resumable': '1.0.0',
            'AuthorizationSignature': signature,
            'AuthorizationExpire': expire.toString(),
            'VideoId': videoGuid,
            'LibraryId': libraryId,
          },
        ),
        onSendProgress: onProgress,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e) || e.type == DioExceptionType.cancel) {
        throw const ServerException(
          'Upload cancelled by user',
          code: 'UPLOAD_CANCELLED',
        );
      }
      throw ServerException(
        e.response?.data?.toString() ??
            e.message ??
            'Network error during video upload',
        code: 'UPLOAD_FAILED',
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<LibraryVideoModel> syncVideoStatus(String libraryVideoId) async {
    try {
      await _c.functions.invoke(
        'bunny-video',
        body: {
          'action': 'sync-status',
          'video_id': libraryVideoId,
        },
      );

      return await getVideoById(libraryVideoId);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> deleteVideo(String id) async {
    try {
      await _c.from('video_library').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<LibraryVideoModel> moveVideo({
    required String id,
    String? targetFolderId,
  }) async {
    try {
      final response = await _c
          .from('video_library')
          .update({
            'folder_id': targetFolderId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .select('*, videos(id, content(group:groups(name)))')
          .single();

      return LibraryVideoModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<LibraryVideoModel> updateVideo({
    required String id,
    required String title,
    String? description,
  }) async {
    try {
      final response = await _c
          .from('video_library')
          .update({
            'title': title.trim(),
            'description': description?.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .select('*, videos(id, content(group:groups(name)))')
          .single();

      return LibraryVideoModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<String> getPlaybackUrl(String libraryVideoId) async {
    try {
      final response = await _c.functions.invoke(
        'video-playback',
        body: {'video_id': libraryVideoId},
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data['playback_url'] != null) {
          return data['playback_url'] as String;
        }
      }

      final errorMsg = response.data is Map
          ? (response.data['error']?.toString() ?? 'Failed to get stream token')
          : 'Failed to get stream token';

      throw ServerException(errorMsg, code: 'STREAM_TOKEN_ERROR');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> linkToLectureContent({
    required String libraryVideoId,
    required String contentId,
    required String title,
  }) async {
    try {
      final libVideo = await getVideoById(libraryVideoId);
      final tenantId = await _resolveTenantId();

      await _c.from('videos').insert({
        'tenant_id': tenantId,
        'content_id': contentId,
        'library_video_id': libraryVideoId,
        'title': title.trim(),
        'description': libVideo.description,
        'provider': libVideo.provider,
        'provider_video_id': libVideo.providerVideoId,
        'thumbnail_url': libVideo.thumbnailUrl,
        'duration': libVideo.duration,
        'status': libVideo.status.name,
      });
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> assignFolderAsChapter({
    required String folderId,
    required String groupId,
    String? chapterTitle,
  }) async {
    try {
      final res = await _c.rpc<dynamic>(
        'assign_folder_as_chapter_to_group',
        params: {
          'p_folder_id': folderId,
          'p_group_id': groupId,
          if (chapterTitle != null && chapterTitle.trim().isNotEmpty)
            'p_chapter_title': chapterTitle.trim(),
        },
      );
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {};
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
