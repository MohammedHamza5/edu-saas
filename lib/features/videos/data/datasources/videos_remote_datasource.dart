import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/supabase_service.dart';
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
    int actualWatchSeconds = 0,
    bool isSkipped = false,
  });

  Future<VideoModel> createAndUploadVideo({
    required String contentId,
    required String title,
    required List<int> videoBytes,
    required String fileName,
    void Function(int sentBytes, int totalBytes)? onProgress,
  });

  Future<void> deleteVideo(String videoId);
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
          .select('*, content!inner(*)')
          .eq('content.group_id', groupId)
          .order('created_at', ascending: false);

      final List<dynamic> list = response as List<dynamic>;
      return list.map((json) {
        final model = VideoModel.fromJson(json as Map<String, dynamic>);
        if (model.providerVideoId != null && model.status.isReady) {
          final playbackUrl = _generateSignedPlaybackUrl(model.providerVideoId!);
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
          .select('*, content(*)')
          .or('id.eq.$videoId,content_id.eq.$videoId')
          .limit(1)
          .single();

      final model = VideoModel.fromJson(data);
      if (model.providerVideoId != null) {
        final playbackUrl = _generateSignedPlaybackUrl(model.providerVideoId!);
        return model.copyWithPlaybackUrl(playbackUrl);
      }
      return model;
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<String> getPlaybackUrl(String videoId) async {
    final video = await getVideoById(videoId);
    if (video.providerVideoId == null || video.providerVideoId!.isEmpty) {
      throw const ServerException(
        'Video file is not available',
        code: 'VIDEO_NOT_READY',
      );
    }
    return _generateSignedPlaybackUrl(video.providerVideoId!);
  }

  /// Generates a secure, time-limited Tokenized HLS stream URL from Bunny Stream
  String _generateSignedPlaybackUrl(String providerVideoId) {
    final tokenKey = AppConfig.bunnyTokenKey;
    final cdnHost = AppConfig.bunnyCdnHostname;

    // Expires in 3 hours (10800 seconds)
    final expires = (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000) + 10800;

    // SHA256(token_key + video_id + expires)
    final hashInput = '$tokenKey$providerVideoId$expires';
    final token = sha256.convert(utf8.encode(hashInput)).toString();

    return 'https://$cdnHost/$providerVideoId/playlist.m3u8?token=$token&expires=$expires';
  }

  @override
  Future<VideoProgressModel?> getVideoProgress({
    required String videoId,
    required String studentId,
  }) async {
    try {
      final data = await _c
          .from('video_progress')
          .select()
          .eq('video_id', videoId)
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
    int actualWatchSeconds = 0,
    bool isSkipped = false,
  }) async {
    try {
      final double percentage = durationSeconds > 0
          ? ((progressSeconds / durationSeconds) * 100).clamp(0.0, 100.0)
          : 0.0;

      // Completion criteria: watching >= 90% AND not skipped
      final bool completed = percentage >= 90.0 && !isSkipped;

      // Get user tenant
      final userTenant = _c.auth.currentUser?.userMetadata?['tenant_id'] ??
          (await _c.from('users').select('tenant_id').eq('id', studentId).single())['tenant_id'];

      final payload = {
        'tenant_id': userTenant,
        'video_id': videoId,
        'student_id': studentId,
        'progress_seconds': progressSeconds,
        'duration_seconds': durationSeconds,
        'percentage': double.parse(percentage.toStringAsFixed(2)),
        'completed': completed,
        'actual_watch_seconds': actualWatchSeconds,
        'is_skipped': isSkipped,
        'last_watched_at': DateTime.now().toIso8601String(),
      };

      final data = await _c
          .from('video_progress')
          .upsert(payload, onConflict: 'video_id, student_id')
          .select()
          .single();

      return VideoProgressModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      throw ServerException(e.toString());
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
          'Failed to initialize video with Bunny Stream',
          code: 'BUNNY_INIT_FAILED',
        );
      }

      // 2. Direct Binary Upload to Bunny Stream
      await _dio.put<void>(
        'https://video.bunnycdn.com/library/$libraryId/videos/$videoGuid',
        data: Stream.fromIterable([videoBytes]),
        options: Options(
          headers: {
            'AccessKey': apiKey,
            'Content-Type': 'application/octet-stream',
          },
        ),
        onSendProgress: onProgress,
      );

      // 3. Save Video Record in Supabase
      final thumbnailUrl = 'https://$cdnHost/$videoGuid/thumbnail.jpg';
      final videoData = await _c.from('videos').insert({
        'content_id': contentId,
        'provider': 'bunny',
        'provider_video_id': videoGuid,
        'status': 'processing',
        'thumbnail_url': thumbnailUrl,
      }).select('*, content(*)').single();

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
  Future<void> deleteVideo(String videoId) async {
    try {
      await _c.from('videos').delete().eq('id', videoId);
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
