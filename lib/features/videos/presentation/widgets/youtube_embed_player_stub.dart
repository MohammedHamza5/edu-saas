import 'package:flutter/material.dart';

Widget buildYouTubeEmbedPlayer({
  required String embedUrl,
  required int initialProgressSeconds,
  void Function(int currentSeconds, int totalSeconds)? onProgress,
  void Function(int currentSeconds, int totalSeconds, int actualWatchSeconds, bool isSkipped)? onMetricsProgress,
  VoidCallback? onCompleted,
  void Function(void Function(int seconds) seekTo)? onSeekReady,
  ValueChanged<bool>? onFullscreenChanged,
}) {
  return const SizedBox.shrink();
}
