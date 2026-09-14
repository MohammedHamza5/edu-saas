import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/videos_repository.dart';
import 'videos_state.dart';

class VideosCubit extends Cubit<VideosState> {
  final VideosRepository _repository;

  int _lastReportedSecond = -1;
  DateTime _lastReportedTime = DateTime.fromMillisecondsSinceEpoch(0);

  VideosCubit({
    required VideosRepository repository,
  })  : _repository = repository,
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

    // 1. Fetch video record
    final videoResult = await _repository.getVideoById(videoId);
    if (videoResult.isFailure) {
      final f = videoResult.failureOrNull!;
      emit(VideosError(f.message, code: f.code));
      return;
    }

    final video = videoResult.dataOrNull!;

    // If video has not been uploaded yet or has no provider video ID, emit loaded with null playbackUrl
    if (video.providerVideoId == null || video.providerVideoId!.isEmpty) {
      emit(VideosLoaded(
        currentVideo: video,
        playbackUrl: null,
      ));
      return;
    }

    // 2. Fetch secure signed playback URL
    final urlResult = await _repository.getPlaybackUrl(videoId);
    if (urlResult.isFailure) {
      final f = urlResult.failureOrNull!;
      emit(VideosError(f.message, code: f.code));
      return;
    }

    final playbackUrl = urlResult.dataOrNull!;

    // 3. Fetch current student progress for Resume functionality
    final progressResult = await _repository.getVideoProgress(
      videoId: videoId,
      studentId: studentId,
    );

    final progress = progressResult.dataOrNull;

    emit(VideosLoaded(
      currentVideo: video,
      playbackUrl: playbackUrl,
      progress: progress,
    ));
  }

  /// Throttled progress update: saves to DB every 10 seconds or when forced (pause/exit)
  Future<void> updateProgress({
    required String videoId,
    required String studentId,
    required int progressSeconds,
    required int durationSeconds,
    int actualWatchSeconds = 0,
    bool isSkipped = false,
    bool force = false,
  }) async {
    if (durationSeconds <= 0) return;

    final now = DateTime.now();
    final elapsedMs = now.difference(_lastReportedTime).inMilliseconds;

    // Only update if forced OR (at least 10 seconds passed AND progress changed by >= 5s)
    if (!force && (elapsedMs < 10000 || (progressSeconds - _lastReportedSecond).abs() < 5)) {
      return;
    }

    _lastReportedTime = now;
    _lastReportedSecond = progressSeconds;

    final result = await _repository.updateVideoProgress(
      videoId: videoId,
      studentId: studentId,
      progressSeconds: progressSeconds,
      durationSeconds: durationSeconds,
      actualWatchSeconds: actualWatchSeconds,
      isSkipped: isSkipped,
    );

    result.when(
      onSuccess: (updatedProgress) {
        if (state is VideosLoaded) {
          final current = state as VideosLoaded;
          emit(current.copyWith(progress: updatedProgress));
        }
      },
      onFailure: (_) {
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
    emit(const VideoUploading(
      progress: 0.0,
      sentBytes: 0,
      totalBytes: 0,
    ));

    final result = await _repository.createAndUploadVideo(
      contentId: contentId,
      title: title,
      videoBytes: videoBytes,
      fileName: fileName,
      onProgress: (sent, total) {
        if (total > 0) {
          final progress = (sent / total).clamp(0.0, 1.0);
          emit(VideoUploading(
            progress: progress,
            sentBytes: sent,
            totalBytes: total,
          ));
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

  void reset() {
    emit(const VideosInitial());
  }
}
