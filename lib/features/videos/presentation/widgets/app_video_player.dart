import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/services/student_activity_tracker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_loading_view.dart';

class AppVideoPlayer extends StatefulWidget {
  final String streamUrl;
  final int initialProgressSeconds;
  final void Function(int currentSeconds, int totalSeconds)? onProgress;
  final void Function(int currentSeconds, int totalSeconds, int actualWatchSeconds, bool isSkipped)? onMetricsProgress;
  final VoidCallback? onCompleted;
  final String? videoTitle;

  const AppVideoPlayer({
    super.key,
    required this.streamUrl,
    this.initialProgressSeconds = 0,
    this.onProgress,
    this.onMetricsProgress,
    this.onCompleted,
    this.videoTitle,
  });

  @override
  State<AppVideoPlayer> createState() => _AppVideoPlayerState();
}

class _AppVideoPlayerState extends State<AppVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = true;
  Timer? _hideControlsTimer;
  double _playbackSpeed = 1.0;
  bool _isFullscreen = false;
  bool _showResumeBanner = false;
  String? _seekFeedbackText;
  Timer? _seekFeedbackTimer;

  // ── Smart Tracking Telemetry ──
  int _actualWatchSeconds = 0;
  int _lastRecordedPosition = 0;
  bool _isSkipped = false;
  Timer? _watchHeartbeatTimer;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(AppVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      _controller?.dispose();
      _watchHeartbeatTimer?.cancel();
      _isInitialized = false;
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    try {
      final uri = Uri.parse(widget.streamUrl);
      _controller = VideoPlayerController.networkUrl(
        uri,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );

      await _controller!.initialize();

      if (!mounted) return;

      // Check if resume is possible
      if (widget.initialProgressSeconds > 15 &&
          widget.initialProgressSeconds < _controller!.value.duration.inSeconds - 10) {
        _showResumeBanner = true;
      }

      _lastRecordedPosition = widget.initialProgressSeconds;
      _controller!.addListener(_playerListener);

      // Start 1-second watch tick timer
      _watchHeartbeatTimer?.cancel();
      _watchHeartbeatTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _controller == null) return;
        if (_controller!.value.isPlaying) {
          _actualWatchSeconds++;
          // Notify global tracker that student is active
          StudentActivityTracker.instance.registerUserInteraction();
        }
      });

      setState(() {
        _isInitialized = true;
        _hasError = false;
      });

      _startHideControlsTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = '';
      });
    }
  }

  void _playerListener() {
    if (!mounted || _controller == null) return;

    final position = _controller!.value.position.inSeconds;
    final duration = _controller!.value.duration.inSeconds;

    // Detect forward seek jumps greater than 25 seconds
    if (position - _lastRecordedPosition > 25) {
      _isSkipped = true;
    }
    _lastRecordedPosition = position;

    widget.onProgress?.call(position, duration);
    widget.onMetricsProgress?.call(position, duration, _actualWatchSeconds, _isSkipped);

    if (_controller!.value.isCompleted) {
      widget.onCompleted?.call();
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _showControls = true;
        _hideControlsTimer?.cancel();
      } else {
        _controller!.play();
        _startHideControlsTimer();
      }
    });
  }

  void _seekRelative(int seconds) {
    if (_controller == null || !_isInitialized) return;
    final current = _controller!.value.position;
    final target = current + Duration(seconds: seconds);
    final maxDuration = _controller!.value.duration;

    if (target < Duration.zero) {
      _controller!.seekTo(Duration.zero);
    } else if (target > maxDuration) {
      _controller!.seekTo(maxDuration);
    } else {
      _controller!.seekTo(target);
    }

    _showSeekFeedback(seconds > 0 ? '+$secondsث' : '$secondsث');
    _resetControlsTimer();
  }

  void _showSeekFeedback(String text) {
    _seekFeedbackTimer?.cancel();
    setState(() {
      _seekFeedbackText = text;
    });
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _seekFeedbackText = null;
        });
      }
    });
  }

  void _changeSpeed(double speed) {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      _playbackSpeed = speed;
      _controller!.setPlaybackSpeed(speed);
    });
    _resetControlsTimer();
  }

  void _resumeFromSavedProgress() {
    if (_controller == null || !_isInitialized) return;
    _controller!.seekTo(Duration(seconds: widget.initialProgressSeconds));
    _controller!.play();
    setState(() {
      _showResumeBanner = false;
    });
    _resetControlsTimer();
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
      if (_isFullscreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    });
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller != null && _controller!.value.isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _resetControlsTimer() {
    setState(() {
      _showControls = true;
    });
    _startHideControlsTimer();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      final hours = duration.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _watchHeartbeatTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    _hideControlsTimer?.cancel();
    _controller?.removeListener(_playerListener);
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 44),
              const SizedBox(height: AppSpacing.s12),
              Text(
                _errorMessage.isNotEmpty ? _errorMessage : context.l10n.videoPlaybackError,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.s16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                onPressed: () {
                  setState(() {
                    _hasError = false;
                  });
                  _initializePlayer();
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(context.l10n.retryAction),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        ),
        child: Center(
          child: AppLoadingView(message: context.l10n.loadingAdaptiveStream),
        ),
      );
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.space): _togglePlayPause,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _seekRelative(-10),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _seekRelative(10),
        const SingleActivator(LogicalKeyboardKey.keyF): _toggleFullscreen,
      },
      child: Focus(
        autofocus: true,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_isFullscreen ? 0 : AppSpacing.radiusMedium),
          child: Container(
            color: Colors.black,
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio > 0
                  ? _controller!.value.aspectRatio
                  : 16 / 9,
              child: GestureDetector(
                onTap: _resetControlsTimer,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // ── The Video Surface ─────────────────────────────
                    VideoPlayer(_controller!),

                    // ── Double-Tap Touch Zones (Mobile / Touch Seek) ───
                    Positioned.fill(
                      child: Row(
                        children: [
                          // Left 35%: Seek -10s
                          Expanded(
                            flex: 35,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onDoubleTap: () => _seekRelative(-10),
                              onTap: _resetControlsTimer,
                            ),
                          ),
                          // Center 30%: Toggle Controls
                          Expanded(
                            flex: 30,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: _resetControlsTimer,
                            ),
                          ),
                          // Right 35%: Seek +10s
                          Expanded(
                            flex: 35,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onDoubleTap: () => _seekRelative(10),
                              onTap: _resetControlsTimer,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Seek Feedback Indicator Overlay ───────────────
                    if (_seekFeedbackText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Text(
                          _seekFeedbackText!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    // ── Buffering Indicator ───────────────────────────
                    if (_controller!.value.isBuffering)
                      const CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),

                    // ── Resume Banner ─────────────────────────────────
                    if (_showResumeBanner && _showControls)
                      Positioned(
                        top: AppSpacing.s16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s16,
                            vertical: AppSpacing.s8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                            border: Border.all(color: AppColors.primaryLight.withAlpha(120)),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.history_rounded, color: AppColors.primaryLight, size: 16),
                              const SizedBox(width: AppSpacing.s8),
                              Text(
                                context.l10n.resumeFromMinute(_formatDuration(Duration(seconds: widget.initialProgressSeconds))),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                              const SizedBox(width: AppSpacing.s12),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primaryLight,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                ),
                                onPressed: _resumeFromSavedProgress,
                                child: Text(
                                  context.l10n.resumeAction,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 14),
                                onPressed: () => setState(() => _showResumeBanner = false),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ── Controls Overlay with Top & Bottom Gradients ───
                    AnimatedOpacity(
                      opacity: _showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: IgnorePointer(
                        ignoring: !_showControls,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Top Scrim: Title, Speeds, Fullscreen
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.black87, Colors.transparent],
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s12,
                                vertical: AppSpacing.s8,
                              ),
                              child: Row(
                                children: [
                                  if (widget.videoTitle != null)
                                    Expanded(
                                      child: Text(
                                        widget.videoTitle!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  const Spacer(),
                                  // Speed Dropdown Menu
                                  PopupMenuButton<double>(
                                    initialValue: _playbackSpeed,
                                    onSelected: _changeSpeed,
                                    color: const Color(0xFF1E1E2E),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.s8,
                                        vertical: AppSpacing.s4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white24,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${_playbackSpeed}x',
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
                                            color: speed == _playbackSpeed
                                                ? AppColors.primaryLight
                                                : Colors.white,
                                            fontWeight: speed == _playbackSpeed
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(width: AppSpacing.s8),
                                  // Fullscreen Toggle
                                  IconButton(
                                    icon: Icon(
                                      _isFullscreen
                                          ? Icons.fullscreen_exit_rounded
                                          : Icons.fullscreen_rounded,
                                      color: Colors.white,
                                    ),
                                    onPressed: _toggleFullscreen,
                                  ),
                                ],
                              ),
                            ),

                            // Center Actions: Seek -10s, Play/Pause, Seek +10s
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  iconSize: 36,
                                  icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                                  onPressed: () => _seekRelative(-10),
                                ),
                                const SizedBox(width: AppSpacing.s24),
                                IconButton(
                                  iconSize: 56,
                                  icon: Icon(
                                    _controller!.value.isPlaying
                                        ? Icons.pause_circle_filled_rounded
                                        : Icons.play_circle_fill_rounded,
                                    color: Colors.white,
                                  ),
                                  onPressed: _togglePlayPause,
                                ),
                                const SizedBox(width: AppSpacing.s24),
                                IconButton(
                                  iconSize: 36,
                                  icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                                  onPressed: () => _seekRelative(10),
                                ),
                              ],
                            ),

                            // Bottom Scrim: Scrubber Slider & Timers
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [Colors.black87, Colors.transparent],
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s12,
                                vertical: AppSpacing.s8,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(_controller!.value.position),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        _formatDuration(_controller!.value.duration),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  VideoProgressIndicator(
                                    _controller!,
                                    allowScrubbing: true,
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    colors: const VideoProgressColors(
                                      playedColor: AppColors.primary,
                                      bufferedColor: Colors.white30,
                                      backgroundColor: Colors.white12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
