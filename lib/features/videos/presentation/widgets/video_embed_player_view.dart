import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'bunny_embed_player.dart';
import 'youtube_embed_player.dart';

/// Presentation widget hosting web-based iframe embeds (YouTube & Bunny Stream).
class VideoEmbedPlayerView extends StatelessWidget {
  final String streamUrl;
  final int initialProgressSeconds;
  final int? totalDurationSeconds;
  final void Function(int currentSeconds, int totalSeconds)? onProgress;
  final void Function(
    int currentSeconds,
    int totalSeconds,
    int actualWatchSeconds,
    bool isSkipped,
  )? onMetricsProgress;
  final VoidCallback? onCompleted;
  final void Function(void Function(int seconds) seekTo)? onSeekReady;
  final void Function(
    VoidCallback play,
    VoidCallback pause,
    VoidCallback togglePlayPause,
  )? onPlaybackControlsReady;
  final ValueChanged<bool>? onFullscreenChanged;

  const VideoEmbedPlayerView({
    super.key,
    required this.streamUrl,
    required this.initialProgressSeconds,
    this.totalDurationSeconds,
    this.onProgress,
    this.onMetricsProgress,
    this.onCompleted,
    this.onSeekReady,
    this.onPlaybackControlsReady,
    this.onFullscreenChanged,
  });

  static bool isYouTube(String url) =>
      kIsWeb && (url.contains('youtube') || url.contains('youtu.be'));

  static bool isBunny(String url) => kIsWeb && !isYouTube(url);

  static bool isEmbed(String url) => kIsWeb;

  @override
  Widget build(BuildContext context) {
    if (isYouTube(streamUrl)) {
      return buildYouTubeEmbedPlayer(
        embedUrl: streamUrl,
        initialProgressSeconds: initialProgressSeconds,
        onProgress: onProgress,
        onMetricsProgress: onMetricsProgress,
        onCompleted: onCompleted,
        onSeekReady: onSeekReady,
        onPlaybackControlsReady: onPlaybackControlsReady,
        onFullscreenChanged: onFullscreenChanged,
      );
    }

    return buildBunnyEmbedPlayer(
      embedUrl: streamUrl,
      initialProgressSeconds: initialProgressSeconds,
      totalDurationSeconds: totalDurationSeconds,
      onProgress: onProgress,
      onMetricsProgress: onMetricsProgress,
      onCompleted: onCompleted,
      onSeekReady: onSeekReady,
      onPlaybackControlsReady: onPlaybackControlsReady,
      onFullscreenChanged: onFullscreenChanged,
    );
  }
}
