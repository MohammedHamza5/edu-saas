import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/video_entity.dart';
import '../../domain/entities/video_progress_entity.dart';
import '../../domain/repositories/videos_repository.dart';
import 'videos_state.dart';

class VideosCubit extends Cubit<VideosState> {
  final VideosRepository _repository;

  int _lastReportedSecond = -1;
  DateTime _lastReportedTime = DateTime.fromMillisecondsSinceEpoch(0);

  VideosCubit({required VideosRepository repository})
    : _repository = repository,
      super(const VideosInitial());

  Future<void> loadVideosForGroup(String groupId) async {
    emit(const VideosLoading());

    final result = await _repository.getVideosForGroup(groupId);

    result.when(
      onSuccess: (videos) {
        emit(VideosLoaded(videos: videos));
      },
      onFailure: (failure) {
        emit(VideosError(failure.message, code: failure.code));
      },
    );
  }

  Future<void> loadVideoPlayback({
    required String videoId,
    required String studentId,
  }) async {
    emit(const VideosLoading());

    // 1. Fetch video and progress concurrently in a single parallel round-trip
    final videoFuture = _repository.getVideoById(videoId);
    final progressFuture = studentId.isNotEmpty
        ? _repository.getVideoProgress(videoId: videoId, studentId: studentId)
        : Future.value(const Result<VideoProgressEntity?>.success(null));

    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      videoFuture,
      progressFuture,
    ]);

    final videoResult = results[0] as Result<VideoEntity>;
    final progressResult = results[1] as Result<VideoProgressEntity?>;

    if (videoResult.isFailure) {
      final f = videoResult.failureOrNull!;
      emit(VideosError(f.message, code: f.code));
      return;
    }

    final video = videoResult.dataOrNull!;

    // If video has not been uploaded yet or has no provider video ID
    if (video.providerVideoId == null || video.providerVideoId!.isEmpty) {
      emit(VideosLoaded(currentVideo: video, playbackUrl: null));
      return;
    }

    // Playback URL is already securely signed inside getVideoById without extra network trip
    String? playbackUrl = video.playbackUrl;
    if (playbackUrl == null || playbackUrl.isEmpty) {
      final urlResult = await _repository.getPlaybackUrl(video.id);
      playbackUrl = urlResult.dataOrNull;
    }

    final progress = progressResult.dataOrNull;

    emit(
      VideosLoaded(
        currentVideo: video,
        playbackUrl: playbackUrl,
        progress: progress,
      ),
    );
  }

  /// Throttled progress update: saves to DB every 10 seconds or when forced (pause/exit)
  Future<void> updateProgress({
    required String videoId,
    required String studentId,
    required int progressSeconds,
    required int durationSeconds,
    int furthestPositionSeconds = 0,
    int actualWatchSeconds = 0,
    bool isSkipped = false,
    bool force = false,
    List<int>? newSegment,
  }) async {
    if (durationSeconds <= 0) return;

    final now = DateTime.now();
    final elapsedMs = now.difference(_lastReportedTime).inMilliseconds;

    // Only update if forced OR (at least 10 seconds passed AND progress changed by >= 5s)
    if (!force &&
        (elapsedMs < 10000 ||
            (progressSeconds - _lastReportedSecond).abs() < 5)) {
      return;
    }

    // Never overwrite an existing higher progress with 0 seconds unless forced
    if (progressSeconds <= 0 && _lastReportedSecond > 5 && !force) {
      return;
    }

    _lastReportedTime = now;
    _lastReportedSecond = progressSeconds;

    final result = await _repository.updateVideoProgress(
      videoId: videoId,
      studentId: studentId,
      progressSeconds: progressSeconds,
      durationSeconds: durationSeconds,
      furthestPositionSeconds: furthestPositionSeconds,
      actualWatchSeconds: actualWatchSeconds,
      isSkipped: isSkipped,
      newSegment: newSegment,
    );

    result.when(
      onSuccess: (updatedProgress) {
        if (state is VideosLoaded) {
          final current = state as VideosLoaded;
          emit(current.copyWith(progress: updatedProgress));
        }
      },
      onFailure: (failure) {
        // Silently tolerate minor progress network drops without interrupting playback
      },
    );
  }

  Future<void> uploadVideo({
    required String contentId,
    required String title,
    required List<int> videoBytes,
    required String fileName,
  }) async {
    emit(const VideoUploading(progress: 0.0, sentBytes: 0, totalBytes: 0));

    final result = await _repository.createAndUploadVideo(
      contentId: contentId,
      title: title,
      videoBytes: videoBytes,
      fileName: fileName,
      onProgress: (sent, total) {
        if (total > 0) {
          final progress = (sent / total).clamp(0.0, 1.0);
          emit(
            VideoUploading(
              progress: progress,
              sentBytes: sent,
              totalBytes: total,
            ),
          );
        }
      },
    );

    result.when(
      onSuccess: (video) {
        emit(VideoUploadSuccess(video));
      },
      onFailure: (failure) {
        emit(VideosError(failure.message, code: failure.code));
      },
    );
  }

  Future<bool> linkYouTubeVideo({
    required String contentId,
    required String youtubeUrl,
    String? title,
  }) async {
    emit(const VideoUploading(progress: 0.5, sentBytes: 50, totalBytes: 100));

    final result = await _repository.linkYouTubeVideo(
      contentId: contentId,
      youtubeUrl: youtubeUrl,
      title: title,
    );

    return result.when(
      onSuccess: (video) {
        emit(VideoUploadSuccess(video));
        return true;
      },
      onFailure: (failure) {
        emit(VideosError(failure.message, code: failure.code));
        return false;
      },
    );
  }

  Future<String?> getSignedFileUrl(String storagePath) async {
    final result = await _repository.getSignedFileUrl(storagePath);
    return result.dataOrNull;
  }

  Future<bool> attachMaterialToVideo({
    required String videoId,
    required String contentId,
    required String fileName,
    required List<int> fileBytes,
  }) async {
    final result = await _repository.attachMaterialToVideo(
      videoId: videoId,
      contentId: contentId,
      fileName: fileName,
      fileBytes: fileBytes,
    );

    return result.when(
      onSuccess: (video) {
        if (state is VideosLoaded) {
          final current = state as VideosLoaded;
          emit(current.copyWith(currentVideo: video));
        }
        return true;
      },
      onFailure: (failure) {
        emit(VideosError(failure.message, code: failure.code));
        return false;
      },
    );
  }

  void reset() {
    emit(const VideosInitial());
  }
}
