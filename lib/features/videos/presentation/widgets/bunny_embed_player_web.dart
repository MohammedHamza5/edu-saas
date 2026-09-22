import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import '../../../../core/services/student_activity_tracker.dart';

@JS('createBunnyPlayer')
external JSObject _createBunnyPlayer(JSString src, JSString viewId);

@JS('bunnyPostMessage')
external void _bunnyPostMessage(JSString viewId, JSString method, JSAny? value);

@JS('onBunnyPlayerMessage')
external set _onBunnyPlayerMessage(JSFunction? callback);

Widget buildBunnyEmbedPlayer({
  required String embedUrl,
  required int initialProgressSeconds,
  void Function(int currentSeconds, int totalSeconds)? onProgress,
  void Function(int currentSeconds, int totalSeconds, int actualWatchSeconds, bool isSkipped)? onMetricsProgress,
  VoidCallback? onCompleted,
  void Function(void Function(int seconds) seekTo)? onSeekReady,
  ValueChanged<bool>? onFullscreenChanged,
}) {
  return _BunnyEmbedPlayerWeb(
    embedUrl: embedUrl,
    initialProgressSeconds: initialProgressSeconds,
    onProgress: onProgress,
    onMetricsProgress: onMetricsProgress,
    onCompleted: onCompleted,
    onSeekReady: onSeekReady,
    onFullscreenChanged: onFullscreenChanged,
  );
}

class _BunnyEmbedPlayerWeb extends StatefulWidget {
  final String embedUrl;
  final int initialProgressSeconds;
  final void Function(int currentSeconds, int totalSeconds)? onProgress;
  final void Function(int currentSeconds, int totalSeconds, int actualWatchSeconds, bool isSkipped)? onMetricsProgress;
  final VoidCallback? onCompleted;
  final void Function(void Function(int seconds) seekTo)? onSeekReady;
  final ValueChanged<bool>? onFullscreenChanged;

  const _BunnyEmbedPlayerWeb({
    required this.embedUrl,
    required this.initialProgressSeconds,
    this.onProgress,
    this.onMetricsProgress,
    this.onCompleted,
    this.onSeekReady,
    this.onFullscreenChanged,
  });

  @override
  State<_BunnyEmbedPlayerWeb> createState() => _BunnyEmbedPlayerWebState();
}

class _BunnyEmbedPlayerWebState extends State<_BunnyEmbedPlayerWeb> {
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
    _viewId = 'bunny_${DateTime.now().microsecondsSinceEpoch}';
    _viewType = 'bunny-player-view-$_viewId';

    _lastRecordedPosition = widget.initialProgressSeconds;

    // Register iframe platform view factory
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int id) {
        try {
          String finalUrl = widget.embedUrl;
          if (widget.initialProgressSeconds > 3 &&
              !finalUrl.contains('&t=') &&
              !finalUrl.contains('?t=')) {
            final separator = finalUrl.contains('?') ? '&' : '?';
            finalUrl = '$finalUrl${separator}t=${widget.initialProgressSeconds}';
          }
          return _createBunnyPlayer(finalUrl.toJS, _viewId.toJS);
        } catch (e) {
          debugPrint('[BunnyEmbed] Error initializing iframe: $e');
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
              currentSeconds = (val['seconds'] as num?)?.toInt() ??
                  (val['currentTime'] as num?)?.toInt() ??
                  0;
              final durVal = (val['duration'] as num?)?.toInt() ?? 0;
              if (durVal > 0) {
                totalSeconds = durVal;
                _lastDuration = durVal;
              } else {
                totalSeconds = _lastDuration;
              }
            } else if (val is num) {
              currentSeconds = val.toInt();
            }

            if (totalSeconds > 0) _lastDuration = totalSeconds;
            final effectiveDuration = totalSeconds > 0 ? totalSeconds : _lastDuration;

            // Detect forward skip > 25 seconds
            if (currentSeconds - _lastRecordedPosition > 25) {
              _isSkipped = true;
            }
            _lastRecordedPosition = currentSeconds;

            widget.onProgress?.call(currentSeconds, effectiveDuration);
            widget.onMetricsProgress?.call(
              currentSeconds,
              effectiveDuration,
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
          } else if (event == 'ready' || event == 'loadeddata') {
            if (widget.initialProgressSeconds > 3 && !_hasSeekedInitial) {
              _hasSeekedInitial = true;
              seekTo(widget.initialProgressSeconds);
            }
          }
        } catch (e) {
          debugPrint('[BunnyEmbed] Message handling warning: $e');
        }
      }

      _onBunnyPlayerMessage = handleMessage.toJS;
    } catch (_) {}
  }

  void seekTo(int seconds) {
    try {
      _bunnyPostMessage(_viewId.toJS, 'setCurrentTime'.toJS, seconds.toJS);
      _lastRecordedPosition = seconds;
    } catch (_) {}
  }

  @override
  void dispose() {
    _watchHeartbeatTimer?.cancel();
    try {
      _onBunnyPlayerMessage = null;
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
