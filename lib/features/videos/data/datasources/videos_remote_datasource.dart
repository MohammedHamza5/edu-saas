import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/utils/youtube_url_parser.dart';
import '../../domain/entities/video_entity.dart';
import '../models/video_model.dart';
import '../models/video_progress_model.dart';

abstract interface class VideosRemoteDataSource {
  Future<List<VideoModel>> getVideosForGroup(String groupId);

  Future<VideoModel> getVideoById(String videoId);

  Future<String> getPlaybackUrl(String videoId);

  Future<VideoProgressModel?> getVideoProgress({
    required String videoId,
    required String studentId,
  });

  Future<VideoProgressModel> updateVideoProgress({
    required String videoId,
    required String studentId,
    required int progressSeconds,
    required int durationSeconds,
    int furthestPositionSeconds = 0,
    int actualWatchSeconds = 0,
    bool isSkipped = false,
    List<int>? newSegment,
  });

  Future<VideoModel> createAndUploadVideo({
    required String contentId,
    required String title,
    required List<int> videoBytes,
    required String fileName,
    void Function(int sentBytes, int totalBytes)? onProgress,
  });

  Future<VideoModel> linkYouTubeVideo({
    required String contentId,
    required String youtubeUrl,
    String? title,
  });

  Future<void> deleteVideo(String videoId);

  Future<String> getSignedFileUrl({
    required String storagePath,
    int expiresInSeconds = 3600,
  });

  Future<VideoModel> attachMaterialToVideo({
    required String videoId,
    required String contentId,
    required String fileName,
    required List<int> fileBytes,
  });

  /// جلب بيانات الدرس الخاصة بمجموعة محددة (PDF، Exam، PassingScore)
  Future<Map<String, dynamic>?> getLessonContext({
    required String contentId,
    required String groupId,
  });
}

class VideosRemoteDataSourceImpl implements VideosRemoteDataSource {
  final SupabaseClient? _client;
  final Dio _dio;

  VideosRemoteDataSourceImpl({
    SupabaseClient? client,
    Dio? dio,
  })  : _client = client,
        _dio = dio ?? Dio();

  SupabaseClient get _c => _client ?? SupabaseService.client;

  @override
  Future<List<VideoModel>> getVideosForGroup(String groupId) async {
    try {
      final response = await _c
          .from('videos')
          .select('*, content!inner(*, files(*))')
          .eq('content.group_id', groupId)
          .order('created_at', ascending: false);

      final List<dynamic> list = response as List<dynamic>;
      return list.map((json) {
        final model = VideoModel.fromJson(json as Map<String, dynamic>);
        if (model.providerVideoId != null && model.status.isReady) {
          final playbackUrl = model.isYouTube
              ? YouTubeUrlParser.getEmbedUrl(model.providerVideoId!)
              : _generateSignedPlaybackUrl(model.providerVideoId!);
          return model.copyWithPlaybackUrl(playbackUrl);
        }
        return model;
      }).toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<VideoModel> getVideoById(String videoId) async {
    try {
      final data = await _c
          .from('videos')
          .select('*, content(*, files(*))')
          .or('id.eq.$videoId,content_id.eq.$videoId')
          .limit(1)
          .maybeSingle();

      if (data != null) {
        final model = VideoModel.fromJson(data);
        if (model.providerVideoId != null && model.providerVideoId!.isNotEmpty) {
          final playbackUrl = model.isYouTube
              ? YouTubeUrlParser.getEmbedUrl(model.providerVideoId!)
              : _generateSignedPlaybackUrl(model.providerVideoId!);
          return model.copyWithPlaybackUrl(playbackUrl);
        }
        return model;
      }

      // If no row exists in videos table, check if content row exists for this ID
      final contentData = await _c
          .from('content')
          .select('*, files(*)')
          .eq('id', videoId)
          .maybeSingle();

      if (contentData != null) {
        return VideoModel(
          id: contentData['id'] as String,
          contentId: contentData['id'] as String,
          title: contentData['title'] as String?,
          description: contentData['description'] as String?,
          provider: 'bunny',
          providerVideoId: null,
          thumbnailUrl: null,
          duration: 0,
          status: VideoStatus.uploading,
          createdAt: contentData['created_at'] != null
              ? DateTime.tryParse(contentData['created_at'] as String) ?? DateTime.now()
              : DateTime.now(),
          updatedAt: contentData['updated_at'] != null
              ? DateTime.tryParse(contentData['updated_at'] as String) ?? DateTime.now()
              : DateTime.now(),
        );
      }

      throw const ServerException(
        'Video not found',
        code: 'VIDEO_NOT_FOUND',
      );
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<String> getPlaybackUrl(String videoId) async {
    try {
      final res = await _c.rpc<dynamic>('get_video_playback_url', params: {'p_video_id': videoId});
      if (res is Map && res['playback_url'] != null) {
        return res['playback_url'] as String;
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('VIDEO_NOT_READY')) {
        throw const ServerException('Video is currently processing', code: 'VIDEO_NOT_READY');
      } else if (msg.contains('NOT_AUTHORIZED')) {
        throw const ServerException('Not authorized to play this video', code: 'NOT_AUTHORIZED');
      } else if (msg.contains('CONTENT_NOT_PUBLISHED')) {
        throw const ServerException('Video content is not published', code: 'CONTENT_NOT_PUBLISHED');
      } else if (msg.contains('VIDEO_NOT_FOUND')) {
        throw const ServerException('Video record not found', code: 'VIDEO_NOT_FOUND');
      }
    }

    final video = await getVideoById(videoId);
    if (video.providerVideoId == null || video.providerVideoId!.isEmpty) {
      throw const ServerException(
        'Video file is not available',
        code: 'VIDEO_NOT_READY',
      );
    }
    if (video.isYouTube) {
      return YouTubeUrlParser.getEmbedUrl(video.providerVideoId!);
    }
    return _generateSignedPlaybackUrl(video.providerVideoId!);
  }

  /// Generates a secure, time-limited Tokenized Embed URL from Bunny Stream (fallback when token is available)
  String _generateSignedPlaybackUrl(String providerVideoId) {
    final tokenKey = AppConfig.bunnyTokenKey;
    final libraryId = AppConfig.bunnyLibraryId;

    if (tokenKey.isEmpty) {
      return 'https://iframe.mediadelivery.net/embed/$libraryId/$providerVideoId?autoplay=true&preload=true&responsive=true&playerjs=true';
    }

    // Expires in 4 hours (14400 seconds)
    final expires = (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000) + 14400;

    // SHA256(token_key + video_id + expires)
    final hashInput = '$tokenKey$providerVideoId$expires';
    final token = sha256.convert(utf8.encode(hashInput)).toString();

    return 'https://iframe.mediadelivery.net/embed/$libraryId/$providerVideoId?token=$token&expires=$expires&autoplay=true&preload=true&responsive=true&playerjs=true';
  }

  /// Resolves the actual videos.id whether passed an id or content_id
  Future<String> _resolveVideoId(String idOrContentId) async {
    try {
      final row = await _c
          .from('videos')
          .select('id')
          .or('id.eq.$idOrContentId,content_id.eq.$idOrContentId')
          .limit(1)
          .maybeSingle();
      if (row != null && row['id'] != null) {
        return row['id'] as String;
      }
    } catch (_) {}
    return idOrContentId;
  }

  @override
  Future<VideoProgressModel?> getVideoProgress({
    required String videoId,
    required String studentId,
  }) async {
    try {
      final actualVideoId = await _resolveVideoId(videoId);
      final data = await _c
          .from('video_progress')
          .select()
          .eq('video_id', actualVideoId)
          .eq('student_id', studentId)
          .maybeSingle();

      if (data == null) return null;
      return VideoProgressModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<VideoProgressModel> updateVideoProgress({
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
      final actualVideoId = await _resolveVideoId(videoId);

      final rpcParams = {
        'p_video_id': actualVideoId,
        'p_duration_seconds': durationSeconds,
        'p_resume_position_seconds': progressSeconds,
        'p_new_segments': newSegment != null ? <List<int>>[newSegment] : <List<int>>[],
        'p_actual_watch_seconds_added': actualWatchSeconds,
        'p_is_skipped': isSkipped,
      };

      final data = await _c.rpc<dynamic>('update_video_progress_v2', params: rpcParams);

      if (data is Map<String, dynamic> && data['status'] == 'ok') {
        // Since the RPC doesn't return the full model, we need to return a merged local state
        // or just fetch it back if needed. The app usually just merges the response.
        // Or we can return a model with just the fields we got.
        return VideoProgressModel(
          id: '',
          videoId: actualVideoId,
          studentId: studentId,
          progressSeconds: (data['progress_seconds'] as num?)?.toInt() ?? progressSeconds,
          durationSeconds: durationSeconds,
          percentage: (data['watched_coverage_percentage'] as num?)?.toDouble() ?? 0.0,
          completed: data['completed'] as bool? ?? false,
          actualWatchSeconds: (data['actual_watch_seconds'] as num?)?.toInt() ?? 0,
          isSkipped: isSkipped,
          furthestPositionSeconds: (data['furthest_position_seconds'] as num?)?.toInt() ?? 0,
          lastWatchedAt: DateTime.now(),
        );
      } else {
        throw const ServerException('Failed to update progress');
      }
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>?> getLessonContext({
    required String contentId,
    required String groupId,
  }) async {
    try {
      final result = await _c.rpc<dynamic>(
        'get_lesson_context',
        params: {'p_content_id': contentId, 'p_group_id': groupId},
      );
      if (result is Map<String, dynamic>) return result;
      return null;
    } catch (e) {
      // إذا لم يوجد context (الدرس لا ينتمي للمجموعة) — fallback آمن
      return null;
    }
  }

  @override
  Future<VideoModel> createAndUploadVideo({
    required String contentId,
    required String title,
    required List<int> videoBytes,
    required String fileName,
    void Function(int sentBytes, int totalBytes)? onProgress,
  }) async {
    try {
      final libraryId = AppConfig.bunnyLibraryId;
      final apiKey = AppConfig.bunnyApiKey;
      final cdnHost = AppConfig.bunnyCdnHostname;

      // 1. Create Video Object in Bunny Stream
      final createResponse = await _dio.post<Map<String, dynamic>>(
        'https://video.bunnycdn.com/library/$libraryId/videos',
        data: {'title': title},
        options: Options(
          headers: {
            'AccessKey': apiKey,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      final videoGuid = createResponse.data?['guid'] as String?;
      if (videoGuid == null || videoGuid.isEmpty) {
        throw const ServerException(
          'Failed to initialize video processing',
          code: 'VIDEO_INIT_FAILED',
        );
      }

      // 2. Direct Binary Upload to Bunny Stream
      final payloadBytes = videoBytes is Uint8List ? videoBytes : Uint8List.fromList(videoBytes);
      await _dio.put<void>(
        'https://video.bunnycdn.com/library/$libraryId/videos/$videoGuid',
        data: payloadBytes,
        options: Options(
          headers: {
            'AccessKey': apiKey,
            'Content-Type': 'application/octet-stream',
            'Content-Length': payloadBytes.length.toString(),
          },
        ),
        onSendProgress: onProgress,
      );

      // 3. Save or Update Video Record in Supabase
      final thumbnailUrl = 'https://$cdnHost/$videoGuid/thumbnail.jpg';
      final existing = await _c
          .from('videos')
          .select('id')
          .eq('content_id', contentId)
          .maybeSingle();

      Map<String, dynamic> videoData;
      if (existing != null && existing['id'] != null) {
        videoData = await _c
            .from('videos')
            .update({
              'provider': 'bunny',
              'provider_video_id': videoGuid,
              'status': 'processing',
              'thumbnail_url': thumbnailUrl,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', existing['id'] as String)
            .select('*, content(*)')
            .single();
      } else {
        videoData = await _c.from('videos').insert({
          'content_id': contentId,
          'provider': 'bunny',
          'provider_video_id': videoGuid,
          'status': 'processing',
          'thumbnail_url': thumbnailUrl,
        }).select('*, content(*)').single();
      }

      return VideoModel.fromJson(videoData);
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?.toString() ?? e.message ?? 'Network error uploading video',
        code: 'UPLOAD_FAILED',
      );
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<VideoModel> linkYouTubeVideo({
    required String contentId,
    required String youtubeUrl,
    String? title,
  }) async {
    final youtubeId = YouTubeUrlParser.extractVideoId(youtubeUrl);
    if (youtubeId == null) {
      throw const ServerException(
        'Invalid YouTube URL or video ID',
        code: 'INVALID_YOUTUBE_URL',
      );
    }

    try {
      final thumbnailUrl = YouTubeUrlParser.getThumbnailUrl(youtubeId);
      final existing = await _c
          .from('videos')
          .select('id')
          .eq('content_id', contentId)
          .maybeSingle();

      final payload = <String, dynamic>{
        'content_id': contentId,
        'provider': 'youtube',
        'provider_video_id': youtubeId,
        'status': 'ready',
        'thumbnail_url': thumbnailUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      Map<String, dynamic> videoData;
      if (existing != null && existing['id'] != null) {
        videoData = await _c
            .from('videos')
            .update(payload)
            .eq('id', existing['id'] as String)
            .select('*, content(*, files(*))')
            .single();
      } else {
        payload['created_at'] = DateTime.now().toUtc().toIso8601String();
        videoData = await _c
            .from('videos')
            .insert(payload)
            .select('*, content(*, files(*))')
            .single();
      }

      // If a title is provided, sync with the parent content row
      if (title != null && title.trim().isNotEmpty) {
        await _c
            .from('content')
            .update({'title': title.trim()})
            .eq('id', contentId);
      }

      final model = VideoModel.fromJson(videoData);
      final embedUrl = YouTubeUrlParser.getEmbedUrl(youtubeId);
      return model.copyWithPlaybackUrl(embedUrl);
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> deleteVideo(String videoId) async {
    try {
      await _c.from('videos').delete().eq('id', videoId);
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<String> getSignedFileUrl({
    required String storagePath,
    int expiresInSeconds = 900,
  }) async {
    try {
      final signedUrl = await _c.storage
          .from('group-content')
          .createSignedUrl(storagePath, expiresInSeconds);
      return signedUrl;
    } catch (e) {
      throw ServerException(e.toString(), code: 'STORAGE_ERROR');
    }
  }

  @override
  Future<VideoModel> attachMaterialToVideo({
    required String videoId,
    required String contentId,
    required String fileName,
    required List<int> fileBytes,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final sanitizedName =
          fileName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_.-]'), '_');
      final storagePath =
          'content/$contentId/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';
      final mimeType = fileName.toLowerCase().endsWith('.pdf')
          ? 'application/pdf'
          : 'application/octet-stream';

      // 1. Upload to Supabase Storage
      await _c.storage.from('group-content').uploadBinary(
            storagePath,
            fileBytes is Uint8List ? fileBytes : Uint8List.fromList(fileBytes),
            fileOptions: FileOptions(contentType: mimeType, upsert: true),
          );

      // 2. Resolve Tenant ID
      String? tenantId = _c.auth.currentUser?.userMetadata?['tenant_id'] as String?;
      if (tenantId == null) {
        final currentUserId = _c.auth.currentUser?.id;
        if (currentUserId != null) {
          final userProfile = await _c
              .from('users')
              .select('tenant_id')
              .eq('id', currentUserId)
              .maybeSingle();
          tenantId = userProfile?['tenant_id'] as String?;
        }
      }

      if (tenantId == null) {
        final contentRow = await _c
            .from('content')
            .select('tenant_id')
            .eq('id', contentId)
            .maybeSingle();
        tenantId = contentRow?['tenant_id'] as String?;
      }

      if (tenantId == null) {
        throw const ServerException('Tenant ID could not be determined', code: 'TENANT_NOT_FOUND');
      }

      // 3. Check if file record exists
      final existingFiles = await _c
          .from('files')
          .select('id')
          .eq('content_id', contentId)
          .limit(1);
      final list = existingFiles as List<dynamic>;

      if (list.isNotEmpty) {
        final existingId = list.first['id'] as String;
        await _c.from('files').update({
          'storage_path': storagePath,
          'file_name': fileName,
          'mime_type': mimeType,
          'file_size': fileBytes.length,
          'created_at': now,
        }).eq('id', existingId);
      } else {
        await _c.from('files').insert({
          'tenant_id': tenantId,
          'content_id': contentId,
          'storage_path': storagePath,
          'file_name': fileName,
          'mime_type': mimeType,
          'file_size': fileBytes.length,
          'created_at': now,
        });
      }

      // 4. Return refreshed VideoModel
      return await getVideoById(videoId.isNotEmpty ? videoId : contentId);
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }
}
