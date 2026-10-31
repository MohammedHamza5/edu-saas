import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/services/student_activity_tracker.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/forensic_watermark_overlay.dart';
import '../utils/video_player_controller_helper.dart';
import 'video_embed_player_view.dart';
import 'video_player_error_box.dart';
import 'video_player_keyboard_shortcuts.dart';
import 'video_player_stack_surface.dart';

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

  bool get _isEmbedPlayer => VideoEmbedPlayerView.isEmbed(widget.streamUrl);

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
    final target = VideoPlayerControllerHelper.calculateSeekTarget(
      currentPosition: _controller!.value.position,
      videoDuration: _controller!.value.duration,
      totalDurationSeconds: widget.totalDurationSeconds,
      seekSeconds: seconds,
    );
    _controller!.seekTo(target);

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
    if (_isEmbedPlayer) {
      return VideoEmbedPlayerView(
        streamUrl: widget.streamUrl,
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
      return VideoPlayerErrorBox(
        errorMessage: _errorMessage,
        onRetry: () {
          setState(() {
            _hasError = false;
          });
          _initializePlayer();
        },
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
      child: VideoPlayerKeyboardShortcuts(
        onTogglePlayPause: _togglePlayPause,
        onToggleMute: _toggleMute,
        onSeekRelative: _seekRelative,
        onVolumeChange: _changeVolume,
        currentVolume: _volume,
        onToggleFullscreen: _toggleFullscreen,
        isFullscreen: _isFullscreen,
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
            child: VideoPlayerStackSurface(
              controller: _controller!,
              aspectRatio: _aspectRatio,
              showControls: _showControls,
              videoTitle: widget.videoTitle,
              isPlaying: isPlaying,
              onTogglePlayPause: _togglePlayPause,
              onResetControlsTimer: _resetControlsTimer,
              onToggleFullscreen: _toggleFullscreen,
              onSeekRelative: _seekRelative,
              seekFeedbackText: _seekFeedbackText,
              showResumeBanner: _showResumeBanner,
              resumeFormattedTime:
                  VideoPlayerControllerHelper.formatDuration(
                Duration(seconds: widget.initialProgressSeconds),
              ),
              onResumeFromSaved: _resumeFromSavedProgress,
              onDismissResumeBanner: () =>
                  setState(() => _showResumeBanner = false),
              isMuted: _isMuted,
              volume: _volume,
              onVolumeChanged: _changeVolume,
              onToggleMute: _toggleMute,
              playbackSpeed: _playbackSpeed,
              onSpeedChanged: _changeSpeed,
              isFullscreen: _isFullscreen,
              totalDurationSeconds: widget.totalDurationSeconds,
              isSecurityPaused: _isSecurityPaused,
              onResumeSecurityPause: _resumeFromSecurityPause,
            ),
          ),
        ),
      ),
    );
  }
}
