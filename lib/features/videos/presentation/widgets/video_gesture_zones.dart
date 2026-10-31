import 'package:flutter/material.dart';

class VideoGestureZones extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onDoubleTapFullscreen;
  final ValueChanged<int> onSeekRelative;

  const VideoGestureZones({
    super.key,
    required this.onTap,
    required this.onDoubleTapFullscreen,
    required this.onSeekRelative,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Full-surface Transparent Event Shield ──────
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            onDoubleTap: onDoubleTapFullscreen,
          ),
        ),

        // ── Touch Double-Tap Seek Zones ────────────────
        Positioned.fill(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: () => onSeekRelative(-10),
                  onTap: onTap,
                ),
              ),
              const Expanded(flex: 4, child: SizedBox.shrink()),
              Expanded(
                flex: 3,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: () => onSeekRelative(10),
                  onTap: onTap,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
