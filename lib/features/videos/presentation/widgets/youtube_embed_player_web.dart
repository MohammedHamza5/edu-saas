import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import '../../../../core/services/student_activity_tracker.dart';

@JS('createYouTubePlayer')
external JSObject _createYouTubePlayer(JSString videoId, JSString viewId, JSString origin);

@JS('youtubePostMessage')
external void _youtubePostMessage(JSString viewId, JSString method, JSAny? value);

@JS('onYouTubePlayerMessage')
external set _onYouTubePlayerMessage(JSFunction? callback);

Widget buildYouTubeEmbedPlayer({
  required String embedUrl,
  required int initialProgressSeconds,
  void Function(int currentSeconds, int totalSeconds)? onProgress,
  void Function(int currentSeconds, int totalSeconds, int actualWatchSeconds, bool isSkipped)? onMetricsProgress,
  VoidCallback? onCompleted,
  void Function(void Function(int seconds) seekTo)? onSeekReady,
  void Function(VoidCallback play, VoidCallback pause, VoidCallback togglePlayPause)? onPlaybackControlsReady,
  ValueChanged<bool>? onFullscreenChanged,
}) {
  return _YouTubeEmbedPlayerWeb(
    embedUrl: embedUrl,
    initialProgressSeconds: initialProgressSeconds,
    onProgress: onProgress,
    onMetricsProgress: onMetricsProgress,
    onCompleted: onCompleted,
    onSeekReady: onSeekReady,
    onPlaybackControlsReady: onPlaybackControlsReady,
    onFullscreenChanged: onFullscreenChanged,
  );
}

class _YouTubeEmbedPlayerWeb extends StatefulWidget {
  final String embedUrl;
  final int initialProgressSeconds;
  final void Function(int currentSeconds, int totalSeconds)? onProgress;
  final void Function(int currentSeconds, int totalSeconds, int actualWatchSeconds, bool isSkipped)? onMetricsProgress;
  final VoidCallback? onCompleted;
  final void Function(void Function(int seconds) seekTo)? onSeekReady;
  final void Function(VoidCallback play, VoidCallback pause, VoidCallback togglePlayPause)? onPlaybackControlsReady;
  final ValueChanged<bool>? onFullscreenChanged;

  const _YouTubeEmbedPlayerWeb({
    required this.embedUrl,
    required this.initialProgressSeconds,
    this.onProgress,
    this.onMetricsProgress,
    this.onCompleted,
    this.onSeekReady,
    this.onPlaybackControlsReady,
    this.onFullscreenChanged,
  });

  @override
  State<_YouTubeEmbedPlayerWeb> createState() => _YouTubeEmbedPlayerWebState();
}

class _YouTubeEmbedPlayerWebState extends State<_YouTubeEmbedPlayerWeb> {
  late final String _viewId;
  late final String _viewType;
  bool _isPlaying = false;
  int _actualWatchSeconds = 0;
  int _lastRecordedPosition = 0;
  bool _isSkipped = false;
  Timer? _watchHeartbeatTimer;
  int _lastDuration = 0;
  bool _hasSeekedInitial = false;

  @override
  void initState() {
    super.initState();
    _viewId = 'yt_${DateTime.now().microsecondsSinceEpoch}';
    _viewType = 'youtube-player-view-$_viewId';

    _lastRecordedPosition = widget.initialProgressSeconds;

    // Extract YouTube video ID from embed URL
    final videoId = _extractVideoId(widget.embedUrl);

    // Get the current page origin for YouTube API security
    final origin = Uri.base.origin;

    // Register iframe platform view factory
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int id) {
        try {
          return _createYouTubePlayer(videoId.toJS, _viewId.toJS, origin.toJS);
        } catch (e) {
          debugPrint('[YouTubeEmbed] Error initializing player: $e');
          rethrow;
        }
      },
    );

    // Register JS bridge message listener
    _setupMessageBridge();

    // 1-second watchdog timer for actual watch verification
    _watchHeartbeatTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_isPlaying) {
        _actualWatchSeconds++;
        StudentActivityTracker.instance.registerUserInteraction();
      }
    });

    widget.onSeekReady?.call((seconds) {
      seekTo(seconds);
    });

    widget.onPlaybackControlsReady?.call(
      play,
      pause,
      togglePlayPause,
    );
  }

  /// Extracts the 11-character YouTube video ID from any embed/watch/short URL.
  String _extractVideoId(String url) {
    // Try to extract from embed URL: youtube-nocookie.com/embed/VIDEO_ID
    final embedMatch = RegExp(r'embed/([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (embedMatch != null) return embedMatch.group(1)!;

    // Try watch URL: youtube.com/watch?v=VIDEO_ID
    final watchMatch = RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (watchMatch != null) return watchMatch.group(1)!;

    // Try short URL: youtu.be/VIDEO_ID
    final shortMatch = RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (shortMatch != null) return shortMatch.group(1)!;

    // Fallback: assume the URL itself is a video ID
    final cleanId = url.trim();
    if (cleanId.length == 11 && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(cleanId)) {
      return cleanId;
    }

    // Last resort: return as-is
    return cleanId;
  }

  void _setupMessageBridge() {
    try {
      void handleMessage(JSString jsonStr) {
        if (!mounted) return;
        try {
          final decoded = jsonDecode(jsonStr.toDart) as Map<String, dynamic>;
          final event = decoded['event'] as String?;

          if (event == 'timeupdate') {
            final val = decoded['value'];
            int currentSeconds = 0;
            int totalSeconds = _lastDuration;

            if (val is Map) {
              currentSeconds = (val['seconds'] as num?)?.toInt() ?? 0;
              totalSeconds = (val['duration'] as num?)?.toInt() ?? _lastDuration;
            } else if (val is num) {
              currentSeconds = val.toInt();
            }

            if (totalSeconds > 0) _lastDuration = totalSeconds;

            // Detect forward skip > 25 seconds
            if (currentSeconds - _lastRecordedPosition > 25) {
              _isSkipped = true;
            }
            _lastRecordedPosition = currentSeconds;

            widget.onProgress?.call(currentSeconds, totalSeconds);
            widget.onMetricsProgress?.call(
              currentSeconds,
              totalSeconds,
              _actualWatchSeconds,
              _isSkipped,
            );
          } else if (event == 'play') {
            _isPlaying = true;
            if (widget.initialProgressSeconds > 3 && !_hasSeekedInitial) {
              _hasSeekedInitial = true;
              seekTo(widget.initialProgressSeconds);
            }
          } else if (event == 'pause') {
            _isPlaying = false;
          } else if (event == 'ended') {
            _isPlaying = false;
            widget.onCompleted?.call();
          } else if (event == 'ready') {
            if (widget.initialProgressSeconds > 3 && !_hasSeekedInitial) {
              _hasSeekedInitial = true;
              seekTo(widget.initialProgressSeconds);
            }
          }
        } catch (e) {
          debugPrint('[YouTubeEmbed] Message handling warning: $e');
        }
      }

      _onYouTubePlayerMessage = handleMessage.toJS;
    } catch (_) {}
  }

  void play() {
    try {
      _youtubePostMessage(_viewId.toJS, 'play'.toJS, null);
      _isPlaying = true;
    } catch (_) {}
  }

  void pause() {
    try {
      _youtubePostMessage(_viewId.toJS, 'pause'.toJS, null);
      _isPlaying = false;
    } catch (_) {}
  }

  void togglePlayPause() {
    if (_isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void seekTo(int seconds) {
    try {
      _youtubePostMessage(_viewId.toJS, 'seekTo'.toJS, seconds.toJS);
      _lastRecordedPosition = seconds;
    } catch (_) {}
  }

  @override
  void dispose() {
    _watchHeartbeatTimer?.cancel();
    try {
      _onYouTubePlayerMessage = null;
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Return direct AspectRatio with HtmlElementView: no Container, no clipBehavior: Clip.antiAlias
    // which previously created a CanvasKit canvas layer over the iframe blocking mouse clicks.
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
