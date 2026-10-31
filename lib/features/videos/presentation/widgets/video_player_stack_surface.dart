import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/widgets/app_loading_view.dart';
import 'app_video_player_controls.dart';
import 'video_gesture_zones.dart';
import 'video_resume_banner.dart';
import 'video_security_pause_overlay.dart';
import 'video_seek_feedback_bubble.dart';

class VideoPlayerStackSurface extends StatelessWidget {
  final VideoPlayerController controller;
  final double aspectRatio;
  final bool showControls;
  final String? videoTitle;
  final bool isPlaying;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onResetControlsTimer;
  final VoidCallback onToggleFullscreen;
  final ValueChanged<int> onSeekRelative;
  final String? seekFeedbackText;
  final bool showResumeBanner;
  final String resumeFormattedTime;
  final VoidCallback onResumeFromSaved;
  final VoidCallback onDismissResumeBanner;
  final bool isMuted;
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onToggleMute;
  final double playbackSpeed;
  final ValueChanged<double> onSpeedChanged;
  final bool isFullscreen;
  final int? totalDurationSeconds;
  final bool isSecurityPaused;
  final VoidCallback onResumeSecurityPause;

  const VideoPlayerStackSurface({
    super.key,
    required this.controller,
    required this.aspectRatio,
    required this.showControls,
    required this.videoTitle,
    required this.isPlaying,
    required this.onTogglePlayPause,
    required this.onResetControlsTimer,
    required this.onToggleFullscreen,
    required this.onSeekRelative,
    required this.seekFeedbackText,
    required this.showResumeBanner,
    required this.resumeFormattedTime,
    required this.onResumeFromSaved,
    required this.onDismissResumeBanner,
    required this.isMuted,
    required this.volume,
    required this.onVolumeChanged,
    required this.onToggleMute,
    required this.playbackSpeed,
    required this.onSpeedChanged,
    required this.isFullscreen,
    required this.totalDurationSeconds,
    required this.isSecurityPaused,
    required this.onResumeSecurityPause,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── 1. Centered LTR Video Surface ─────────────────
            Positioned.fill(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
            ),

            // ── 2 & 3. Gesture Zones (Event Shield + Double-Tap Seek) ──
            VideoGestureZones(
              onTap: () {
                if (showControls) {
                  onTogglePlayPause();
                } else {
                  onResetControlsTimer();
                }
              },
              onDoubleTapFullscreen: onToggleFullscreen,
              onSeekRelative: onSeekRelative,
            ),

            // ── 4. Seek Feedback Bubble (+10s / -10s) ─────────
            if (seekFeedbackText != null)
              VideoSeekFeedbackBubble(text: seekFeedbackText!),

            // ── 5. Buffering Indicator ────────────────────────
            if (controller.value.isBuffering)
              const AppLoadingView.compact(
                size: 38,
                color: Colors.white,
              ),

            // ── 6. Resume Banner ──────────────────────────────
            if (showResumeBanner && showControls)
              VideoResumeBanner(
                formattedTime: resumeFormattedTime,
                onResume: onResumeFromSaved,
                onDismiss: onDismissResumeBanner,
              ),

            // ── 7. Cinematic Controls Overlay ─────────────────
            AppVideoPlayerControls(
              showControls: showControls,
              videoTitle: videoTitle,
              isPlaying: isPlaying,
              onTogglePlayPause: onTogglePlayPause,
              controller: controller,
              isMuted: isMuted,
              volume: volume,
              onVolumeChanged: onVolumeChanged,
              onToggleMute: onToggleMute,
              onSeekRelative: onSeekRelative,
              playbackSpeed: playbackSpeed,
              onSpeedChanged: onSpeedChanged,
              isFullscreen: isFullscreen,
              onToggleFullscreen: onToggleFullscreen,
              totalDurationSeconds: totalDurationSeconds,
            ),
            if (isSecurityPaused)
              VideoSecurityPauseOverlay(
                onResume: onResumeSecurityPause,
              ),
          ],
        ),
      ),
    );
  }
}
