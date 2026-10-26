import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/services/student_activity_tracker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/forensic_watermark_overlay.dart';
import 'bunny_embed_player.dart';
import 'youtube_embed_player.dart';
import 'app_video_player_controls.dart';
import 'video_security_pause_overlay.dart';

class AppVideoPlayer extends StatefulWidget {
  final String streamUrl;
  final int initialProgressSeconds;
  final int? totalDurationSeconds;
  final bool isFullscreen;
  final void Function(int currentSeconds, int totalSeconds)? onProgress;
  final void Function(
    int currentSeconds,
    int totalSeconds,
    int actualWatchSeconds,
    bool isSkipped,
  )?
  onMetricsProgress;
  final VoidCallback? onCompleted;
  final String? videoTitle;
  final void Function(void Function(int seconds) seekTo)? onSeekReady;
  final void Function(
    VoidCallback play,
    VoidCallback pause,
    VoidCallback togglePlayPause,
  )?
  onPlaybackControlsReady;
  final ValueChanged<bool>? onFullscreenChanged;

  const AppVideoPlayer({
    super.key,
    required this.streamUrl,
    this.initialProgressSeconds = 0,
    this.totalDurationSeconds,
    this.isFullscreen = false,
    this.onProgress,
    this.onMetricsProgress,
    this.onCompleted,
    this.videoTitle,
    this.onSeekReady,
    this.onPlaybackControlsReady,
    this.onFullscreenChanged,
  });

  @override
  State<AppVideoPlayer> createState() => _AppVideoPlayerState();
}

class _AppVideoPlayerState extends State<AppVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = true;
  Timer? _hideControlsTimer;
  double _playbackSpeed = 1.0;
  bool get _isFullscreen => widget.isFullscreen;
  bool _showResumeBanner = false;
  String? _seekFeedbackText;
  Timer? _seekFeedbackTimer;
  double _aspectRatio = 16 / 9;
  double _volume = 1.0;
  bool _isMuted = false;
  bool _isSecurityPaused = false;

  // ── Smart Tracking Telemetry ──
  int _actualWatchSeconds = 0;
  int _lastRecordedPosition = 0;
  bool _isSkipped = false;
  Timer? _watchHeartbeatTimer;
  bool _completionFired = false;

  bool get _isYouTubeEmbed =>
      kIsWeb &&
      (widget.streamUrl.contains('youtube') ||
          widget.streamUrl.contains('youtu.be'));

  bool get _isBunnyEmbed => kIsWeb && !_isYouTubeEmbed;

  bool get _isEmbedPlayer => _isYouTubeEmbed || _isBunnyEmbed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!_isEmbedPlayer) {
      _initializePlayer();
    }
  }

  @override
  void didUpdateWidget(AppVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      if (!_isEmbedPlayer) {
        _controller?.dispose();
        _watchHeartbeatTimer?.cancel();
        _isInitialized = false;
        _initializePlayer();
      }
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

      if (_controller!.value.aspectRatio > 0) {
        _aspectRatio = _controller!.value.aspectRatio;
      }

      // Auto-resume playback if previous progress exists
      final effectiveDuration = _controller!.value.duration.inSeconds > 0
          ? _controller!.value.duration.inSeconds
          : (widget.totalDurationSeconds ?? 0);

      if (widget.initialProgressSeconds > 3 &&
          (effectiveDuration <= 0 ||
              widget.initialProgressSeconds < effectiveDuration - 3)) {
        await _controller!.seekTo(
          Duration(seconds: widget.initialProgressSeconds),
        );
        _showResumeBanner = true;
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _showResumeBanner = false;
            });
          }
        });
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

      widget.onSeekReady?.call((seconds) {
        if (_controller != null && _isInitialized) {
          _controller!.seekTo(Duration(seconds: seconds));
          _controller!.play();
          _resetControlsTimer();
        }
      });

      widget.onPlaybackControlsReady?.call(
        () {
          _controller?.play();
          _startHideControlsTimer();
        },
        () {
          _controller?.pause();
          _showControls = true;
          _hideControlsTimer?.cancel();
        },
        _togglePlayPause,
      );

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

    // Dynamically adjust aspect ratio when video stream metadata arrives
    if (_controller!.value.isInitialized &&
        _controller!.value.aspectRatio > 0) {
      if ((_controller!.value.aspectRatio - _aspectRatio).abs() > 0.01) {
        _aspectRatio = _controller!.value.aspectRatio;
        setState(() {});
      }
    }

    final position = _controller!.value.position.inSeconds;
    final duration = _controller!.value.duration.inSeconds;

    // Detect forward seek jumps greater than 25 seconds
    if (position - _lastRecordedPosition > 25) {
      _isSkipped = true;
    }
    _lastRecordedPosition = position;

    widget.onProgress?.call(position, duration);
    widget.onMetricsProgress?.call(
      position,
      duration,
      _actualWatchSeconds,
      _isSkipped,
    );

    if (_controller!.value.isCompleted && !_completionFired) {
      _completionFired = true;
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
    } else if (maxDuration > Duration.zero && target > maxDuration) {
      _controller!.seekTo(maxDuration);
    } else if (maxDuration == Duration.zero &&
        widget.totalDurationSeconds != null &&
        widget.totalDurationSeconds! > 0) {
      final fallbackMax = Duration(seconds: widget.totalDurationSeconds!);
      if (target > fallbackMax) {
        _controller!.seekTo(fallbackMax);
      } else {
        _controller!.seekTo(target);
      }
    } else {
      _controller!.seekTo(target);
    }

    final isAr = Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    final unit = isAr ? 'ث' : 's';
    _showSeekFeedback(seconds > 0 ? '+$seconds$unit' : '$seconds$unit');
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

  void _toggleMute() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      if (_isMuted) {
        _isMuted = false;
        if (_volume <= 0.05) _volume = 1.0;
        _controller!.setVolume(_volume);
      } else {
        _isMuted = true;
        _controller!.setVolume(0.0);
      }
    });
    _resetControlsTimer();
  }

  void _changeVolume(double newVolume) {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      _volume = newVolume.clamp(0.0, 1.0);
      _isMuted = _volume == 0.0;
      _controller!.setVolume(_isMuted ? 0.0 : _volume);
    });
    _resetControlsTimer();
  }

  void _toggleFullscreen() {
    widget.onFullscreenChanged?.call(!_isFullscreen);
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
    WidgetsBinding.instance.removeObserver(this);
    _watchHeartbeatTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    _hideControlsTimer?.cancel();
    _controller?.removeListener(_playerListener);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_controller != null && _controller!.value.isPlaying) {
        _controller!.pause();
        if (mounted) {
          setState(() {
            _isSecurityPaused = true;
          });
        }
      }
    }
  }

  void _resumeFromSecurityPause() {
    if (mounted) {
      setState(() {
        _isSecurityPaused = false;
      });
      _controller?.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isYouTubeEmbed) {
      return buildYouTubeEmbedPlayer(
        embedUrl: widget.streamUrl,
        initialProgressSeconds: widget.initialProgressSeconds,
        onProgress: widget.onProgress,
        onMetricsProgress: widget.onMetricsProgress,
        onCompleted: widget.onCompleted,
        onSeekReady: widget.onSeekReady,
        onPlaybackControlsReady: widget.onPlaybackControlsReady,
        onFullscreenChanged: widget.onFullscreenChanged,
      );
    }

    if (_isBunnyEmbed) {
      return buildBunnyEmbedPlayer(
        embedUrl: widget.streamUrl,
        initialProgressSeconds: widget.initialProgressSeconds,
        totalDurationSeconds: widget.totalDurationSeconds,
        onProgress: widget.onProgress,
        onMetricsProgress: widget.onMetricsProgress,
        onCompleted: widget.onCompleted,
        onSeekReady: widget.onSeekReady,
        onPlaybackControlsReady: widget.onPlaybackControlsReady,
        onFullscreenChanged: widget.onFullscreenChanged,
      );
    }

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
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 44,
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                _errorMessage.isNotEmpty
                    ? _errorMessage
                    : context.l10n.videoPlaybackError,
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

    final isPlaying = _controller!.value.isPlaying;
    return ForensicWatermarkOverlay(
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.space): _togglePlayPause,
          const SingleActivator(LogicalKeyboardKey.keyK): _togglePlayPause,
          const SingleActivator(LogicalKeyboardKey.keyM): _toggleMute,
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              _seekRelative(-10),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              _seekRelative(10),
          const SingleActivator(LogicalKeyboardKey.keyJ): () =>
              _seekRelative(-10),
          const SingleActivator(LogicalKeyboardKey.keyL): () =>
              _seekRelative(10),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
              _changeVolume(_volume + 0.1),
          const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              _changeVolume(_volume - 0.1),
          const SingleActivator(LogicalKeyboardKey.keyF): _toggleFullscreen,
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_isFullscreen) _toggleFullscreen();
          },
        },
        child: Focus(
          autofocus: true,
          child: MouseRegion(
            cursor: (!isPlaying || _showControls)
                ? SystemMouseCursors.basic
                : SystemMouseCursors.none,
            onHover: (_) {
              if (!_showControls) {
                _resetControlsTimer();
              } else {
                _startHideControlsTimer();
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                _isFullscreen ? 0 : AppSpacing.radiusMedium,
              ),
              child: Container(
                color: Colors.black,
                child: AspectRatio(
                  aspectRatio: _aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // ── 1. Centered LTR Video Surface ─────────────────
                      Positioned.fill(
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: _aspectRatio,
                              child: VideoPlayer(_controller!),
                            ),
                          ),
                        ),
                      ),

                      // ── 2. Full-surface Transparent Event Shield ──────
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (_showControls) {
                              _togglePlayPause();
                            } else {
                              _resetControlsTimer();
                            }
                          },
                          onDoubleTap: _toggleFullscreen,
                        ),
                      ),

                      // ── 3. Touch Double-Tap Seek Zones ────────────────
                      Positioned.fill(
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onDoubleTap: () => _seekRelative(-10),
                                onTap: () {
                                  if (_showControls) {
                                    _togglePlayPause();
                                  } else {
                                    _resetControlsTimer();
                                  }
                                },
                              ),
                            ),
                            const Expanded(flex: 4, child: SizedBox.shrink()),
                            Expanded(
                              flex: 3,
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onDoubleTap: () => _seekRelative(10),
                                onTap: () {
                                  if (_showControls) {
                                    _togglePlayPause();
                                  } else {
                                    _resetControlsTimer();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── 4. Seek Feedback Bubble (+10s / -10s) ─────────
                      if (_seekFeedbackText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusFull,
                            ),
                            border: Border.all(
                              color: AppColors.primaryLight.withAlpha(100),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black54,
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Text(
                            _seekFeedbackText!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),

                      // ── 5. Buffering Indicator ────────────────────────
                      if (_controller!.value.isBuffering)
                        const AppLoadingView.compact(
                          size: 38,
                          color: Colors.white,
                        ),

                      // ── 6. Resume Banner ──────────────────────────────
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
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusFull,
                              ),
                              border: Border.all(
                                color: AppColors.primaryLight.withAlpha(120),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 10,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.history_rounded,
                                  color: AppColors.primaryLight,
                                  size: 16,
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                Text(
                                  context.l10n.resumeFromMinute(
                                    _formatDuration(
                                      Duration(
                                        seconds: widget.initialProgressSeconds,
                                      ),
                                    ),
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s12),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primaryLight,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                  ),
                                  onPressed: _resumeFromSavedProgress,
                                  child: Text(
                                    context.l10n.resumeAction,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white70,
                                    size: 14,
                                  ),
                                  onPressed: () =>
                                      setState(() => _showResumeBanner = false),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // ── 7. Cinematic Controls Overlay ─────────────────
                      AppVideoPlayerControls(
                        showControls: _showControls,
                        videoTitle: widget.videoTitle,
                        isPlaying: isPlaying,
                        onTogglePlayPause: _togglePlayPause,
                        controller: _controller!,
                        isMuted: _isMuted,
                        volume: _volume,
                        onVolumeChanged: _changeVolume,
                        onToggleMute: _toggleMute,
                        onSeekRelative: _seekRelative,
                        playbackSpeed: _playbackSpeed,
                        onSpeedChanged: _changeSpeed,
                        isFullscreen: _isFullscreen,
                        onToggleFullscreen: _toggleFullscreen,
                        totalDurationSeconds: widget.totalDurationSeconds,
                      ),
                      if (_isSecurityPaused)
                        VideoSecurityPauseOverlay(
                          onResume: _resumeFromSecurityPause,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
