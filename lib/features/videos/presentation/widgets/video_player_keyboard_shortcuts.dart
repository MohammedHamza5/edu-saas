import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VideoPlayerKeyboardShortcuts extends StatelessWidget {
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleMute;
  final ValueChanged<int> onSeekRelative;
  final ValueChanged<double> onVolumeChange;
  final double currentVolume;
  final VoidCallback onToggleFullscreen;
  final bool isFullscreen;
  final Widget child;

  const VideoPlayerKeyboardShortcuts({
    super.key,
    required this.onTogglePlayPause,
    required this.onToggleMute,
    required this.onSeekRelative,
    required this.onVolumeChange,
    required this.currentVolume,
    required this.onToggleFullscreen,
    required this.isFullscreen,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.space): onTogglePlayPause,
        const SingleActivator(LogicalKeyboardKey.keyK): onTogglePlayPause,
        const SingleActivator(LogicalKeyboardKey.keyM): onToggleMute,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            onSeekRelative(-10),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            onSeekRelative(10),
        const SingleActivator(LogicalKeyboardKey.keyJ): () =>
            onSeekRelative(-10),
        const SingleActivator(LogicalKeyboardKey.keyL): () =>
            onSeekRelative(10),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            onVolumeChange(currentVolume + 0.1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            onVolumeChange(currentVolume - 0.1),
        const SingleActivator(LogicalKeyboardKey.keyF): onToggleFullscreen,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (isFullscreen) onToggleFullscreen();
        },
      },
      child: Focus(
        autofocus: true,
        child: child,
      ),
    );
  }
}
