/// Mathematical and positioning helper methods for video playback and duration formatting.
class VideoPlayerControllerHelper {
  const VideoPlayerControllerHelper._();

  /// Calculates bounded seek destination avoiding negative seconds or exceeding video duration.
  static Duration calculateSeekTarget({
    required Duration currentPosition,
    required Duration videoDuration,
    required int? totalDurationSeconds,
    required int seekSeconds,
  }) {
    final target = currentPosition + Duration(seconds: seekSeconds);
    final maxDuration = videoDuration;

    if (target < Duration.zero) {
      return Duration.zero;
    } else if (maxDuration > Duration.zero && target > maxDuration) {
      return maxDuration;
    } else if (maxDuration == Duration.zero &&
        totalDurationSeconds != null &&
        totalDurationSeconds > 0) {
      final fallbackMax = Duration(seconds: totalDurationSeconds);
      if (target > fallbackMax) {
        return fallbackMax;
      } else {
        return target;
      }
    } else {
      return target;
    }
  }

  /// Formats duration into standard [HH:]MM:SS timestamps.
  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      final hours = duration.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
