import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class AppVideoPlayerControls extends StatelessWidget {
  final bool showControls;
  final String? videoTitle;
  final bool isPlaying;
  final VoidCallback onTogglePlayPause;
  final VideoPlayerController controller;
  final bool isMuted;
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onToggleMute;
  final ValueChanged<int> onSeekRelative;
  final double playbackSpeed;
  final ValueChanged<double> onSpeedChanged;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;
  final int? totalDurationSeconds;

  const AppVideoPlayerControls({
    super.key,
    required this.showControls,
    this.videoTitle,
    required this.isPlaying,
    required this.onTogglePlayPause,
    required this.controller,
    required this.isMuted,
    required this.volume,
    required this.onVolumeChanged,
    required this.onToggleMute,
    required this.onSeekRelative,
    required this.playbackSpeed,
    required this.onSpeedChanged,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    this.totalDurationSeconds,
  });

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      final hours = duration.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      child: IgnorePointer(
        ignoring: !showControls,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Scrim: Title
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s12,
              ),
              child: Row(
                children: [
                  if (videoTitle != null)
                    Expanded(
                      child: Text(
                        videoTitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Center Action: ONLY shown when PAUSED so user can resume
            if (!isPlaying)
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withAlpha(160),
                    border: Border.all(
                      color: Colors.white.withAlpha(80),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    iconSize: 44,
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    onPressed: onTogglePlayPause,
                  ),
                ),
              )
            else
              const SizedBox.shrink(),

            // Bottom Scrim: Scrubber Slider, Play/Pause, Seek, Volume, Timers, Speed, Fullscreen
            Directionality(
              textDirection: TextDirection.ltr,
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller,
                builder: (context, val, _) {
                  final muted = isMuted || volume == 0.0;
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                      vertical: AppSpacing.s8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Modern Scrubber / Seekbar
                        VideoProgressIndicator(
                          controller,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          colors: const VideoProgressColors(
                            playedColor: AppColors.primary,
                            bufferedColor: Colors.white24,
                            backgroundColor: Colors.white12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Unified Controls Row
                        Row(
                          children: [
                            // Play / Pause
                            IconButton(
                              iconSize: 26,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              icon: Icon(
                                val.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                              ),
                              onPressed: onTogglePlayPause,
                            ),
                            const SizedBox(width: 4),
                            // Seek -10s
                            IconButton(
                              iconSize: 20,
                              tooltip: '-10s',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              icon: const Icon(
                                Icons.replay_10_rounded,
                                color: Colors.white70,
                              ),
                              onPressed: () => onSeekRelative(-10),
                            ),
                            // Seek +10s
                            IconButton(
                              iconSize: 20,
                              tooltip: '+10s',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              icon: const Icon(
                                Icons.forward_10_rounded,
                                color: Colors.white70,
                              ),
                              onPressed: () => onSeekRelative(10),
                            ),
                            const SizedBox(width: 6),
                            // Volume Mute/Unmute Toggle
                            IconButton(
                              iconSize: 20,
                              tooltip: muted
                                  ? context.l10n.videoUnmute
                                  : context.l10n.videoMute,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              icon: Icon(
                                muted
                                    ? Icons.volume_off_rounded
                                    : (volume < 0.5
                                        ? Icons.volume_down_rounded
                                        : Icons.volume_up_rounded),
                                color: Colors.white,
                              ),
                              onPressed: onToggleMute,
                            ),
                            // Volume Slider
                            SizedBox(
                              width: 68,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 5,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 10,
                                  ),
                                  activeTrackColor: Colors.white,
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: Colors.white,
                                ),
                                child: Slider(
                                  value: muted ? 0.0 : volume,
                                  min: 0.0,
                                  max: 1.0,
                                  onChanged: onVolumeChanged,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Elapsed / Total Duration
                            Text(
                              '${_formatDuration(val.position)} / ${_formatDuration(val.duration > Duration.zero ? val.duration : Duration(seconds: totalDurationSeconds ?? 0))}',
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const Spacer(),
                            // Playback Speed Menu
                            PopupMenuButton<double>(
                              initialValue: playbackSpeed,
                              onSelected: onSpeedChanged,
                              color: const Color(0xFF1E1E2E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: Colors.white12),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${playbackSpeed}x',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              itemBuilder: (context) => [
                                0.75,
                                1.0,
                                1.25,
                                1.5,
                                2.0,
                              ].map((speed) {
                                return PopupMenuItem<double>(
                                  value: speed,
                                  child: Text(
                                    '${speed}x',
                                    style: TextStyle(
                                      color: speed == playbackSpeed
                                          ? AppColors.primaryLight
                                          : Colors.white,
                                      fontWeight: speed == playbackSpeed
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(width: 8),
                            // Fullscreen Toggle
                            IconButton(
                              iconSize: 22,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              icon: Icon(
                                isFullscreen
                                    ? Icons.fullscreen_exit_rounded
                                    : Icons.fullscreen_rounded,
                                color: Colors.white,
                              ),
                              onPressed: onToggleFullscreen,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
