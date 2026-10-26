import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/services/student_activity_tracker.dart';
import '../../domain/entities/video_entity.dart';
import '../../domain/repositories/videos_repository.dart';
import '../cubit/videos_cubit.dart';

/// Tracks student playback progress, segment intervals, furthest watched position,
/// and handles persistent flushing to the backend.
class VideoProgressTracker {
  final bool isTeacher;
  final String studentId;
  final VideosCubit cubit;
  final VideosRepository videosRepository;

  int furthestPositionSecs = 0;
  int? segmentStart;
  int? segmentEnd;
  bool hasRecordedStarted = false;
  bool hasRecordedCompleted = false;

  VideoProgressTracker({
    required this.isTeacher,
    required this.studentId,
    required this.cubit,
    required this.videosRepository,
  });

  /// Updates progress metrics during active playback with seek-detection and segmenting.
  void handleMetricsProgress({
    required VideoEntity? video,
    required int currentSeconds,
    required int totalSeconds,
    required int actualWatch,
    required bool isSkipped,
  }) {
    if (isTeacher || studentId.isEmpty || video == null) return;

    if (currentSeconds > furthestPositionSecs) {
      furthestPositionSecs = currentSeconds;
    }

    if (!hasRecordedStarted && currentSeconds > 0) {
      hasRecordedStarted = true;
      StudentActivityTracker.instance.recordActivity(
        eventType: 'video_started',
        contentId: video.contentId,
      );
    }

    final dur = totalSeconds > 0 ? totalSeconds : video.duration;
    if (segmentStart == null) {
      segmentStart = currentSeconds;
      segmentEnd = currentSeconds;
    }

    bool isSeek = false;
    if (segmentEnd != null && (currentSeconds - segmentEnd!).abs() > 2) {
      isSeek = true;
      // Commit the segment before starting a new one without bypassing debounce
      cubit.updateProgress(
        videoId: video.id,
        studentId: studentId,
        progressSeconds: currentSeconds,
        durationSeconds: dur,
        furthestPositionSeconds: furthestPositionSecs,
        actualWatchSeconds: actualWatch,
        isSkipped: isSkipped,
        force: false,
        newSegment: [segmentStart!, segmentEnd!],
      );
      segmentStart = currentSeconds;
      segmentEnd = currentSeconds;
    } else {
      segmentEnd = currentSeconds;
    }

    if (!isSeek) {
      cubit.updateProgress(
        videoId: video.id,
        studentId: studentId,
        progressSeconds: currentSeconds,
        durationSeconds: dur,
        furthestPositionSeconds: furthestPositionSecs,
        actualWatchSeconds: actualWatch,
        isSkipped: isSkipped,
        newSegment: [segmentStart!, segmentEnd!],
      );
    }
  }

  /// Handles 100% video completion event and triggers completion activity logging.
  void handleVideoCompleted({
    required VideoEntity? video,
    required int liveDurationSecs,
    required VoidCallback onMarkCompletedLocally,
  }) {
    if (hasRecordedCompleted) return;
    hasRecordedCompleted = true;

    if (!isTeacher && studentId.isNotEmpty && video != null) {
      final dur = liveDurationSecs > 0 ? liveDurationSecs : video.duration;
      cubit.updateProgress(
        videoId: video.id,
        studentId: studentId,
        progressSeconds: dur,
        durationSeconds: dur,
        furthestPositionSeconds:
            furthestPositionSecs > 0 ? furthestPositionSecs : dur,
        force: true,
        newSegment: segmentStart != null && segmentEnd != null
            ? [segmentStart!, segmentEnd!]
            : null,
      );
      StudentActivityTracker.instance.recordActivity(
        eventType: 'video_completed',
        contentId: video.contentId,
      );
      onMarkCompletedLocally();
    }
  }

  /// Forces an atomic, synchronous flush to the repository when leaving the player.
  Future<void> forceFlushToDB({
    required VideoEntity? video,
    required int livePositionSecs,
    required int liveDurationSecs,
  }) async {
    if (!isTeacher && studentId.isNotEmpty && video != null) {
      final pos = livePositionSecs;
      final dur = liveDurationSecs > 0 ? liveDurationSecs : video.duration;
      final newSegment = segmentStart != null && segmentEnd != null
          ? [segmentStart!, segmentEnd!]
          : null;

      if (pos > 0 && dur > 0 && SupabaseService.isAuthenticated) {
        try {
          await videosRepository
              .updateVideoProgress(
                videoId: video.id,
                studentId: studentId,
                progressSeconds: pos,
                durationSeconds: dur,
                furthestPositionSeconds: furthestPositionSecs,
                newSegment: newSegment,
              )
              .timeout(const Duration(seconds: 4));
        } catch (_) {}
      }
    }
  }
}
