import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/services/student_activity_tracker.dart';

@JS('createBunnyPlayer')
external JSObject _createBunnyPlayer(JSString src, JSString viewId);

@JS('destroyBunnyPlayer')
external void _destroyBunnyPlayer(JSString viewId);

@JS('reloadBunnyPlayer')
external void _reloadBunnyPlayer(JSString viewId, JSNumber? seekSeconds);

@JS('bunnyPostMessage')
external void _bunnyPostMessage(JSString viewId, JSString method, JSAny? value);

@JS('onBunnyPlayerMessage')
external set _onBunnyPlayerMessage(JSFunction? callback);

Widget buildBunnyEmbedPlayer({
  required String embedUrl,
  required int initialProgressSeconds,
  int? totalDurationSeconds,
  void Function(int currentSeconds, int totalSeconds)? onProgress,
  void Function(
    int currentSeconds,
    int totalSeconds,
    int actualWatchSeconds,
    bool isSkipped,
  )?
  onMetricsProgress,
  VoidCallback? onCompleted,
  void Function(void Function(int seconds) seekTo)? onSeekReady,
  void Function(
    VoidCallback play,
    VoidCallback pause,
    VoidCallback togglePlayPause,
  )?
  onPlaybackControlsReady,
  ValueChanged<bool>? onFullscreenChanged,
}) {
  return _BunnyEmbedPlayerWeb(
    embedUrl: embedUrl,
    initialProgressSeconds: initialProgressSeconds,
    totalDurationSeconds: totalDurationSeconds,
    onProgress: onProgress,
    onMetricsProgress: onMetricsProgress,
    onCompleted: onCompleted,
    onSeekReady: onSeekReady,
    onPlaybackControlsReady: onPlaybackControlsReady,
    onFullscreenChanged: onFullscreenChanged,
  );
}

class _BunnyEmbedPlayerWeb extends StatefulWidget {
  final String embedUrl;
  final int initialProgressSeconds;
  final int? totalDurationSeconds;
  final void Function(int currentSeconds, int totalSeconds)? onProgress;
  final void Function(
    int currentSeconds,
    int totalSeconds,
    int actualWatchSeconds,
    bool isSkipped,
  )?
  onMetricsProgress;
  final VoidCallback? onCompleted;
  final void Function(void Function(int seconds) seekTo)? onSeekReady;
  final void Function(
    VoidCallback play,
    VoidCallback pause,
    VoidCallback togglePlayPause,
  )?
  onPlaybackControlsReady;
  final ValueChanged<bool>? onFullscreenChanged;

  const _BunnyEmbedPlayerWeb({
    required this.embedUrl,
    required this.initialProgressSeconds,
    this.totalDurationSeconds,
    this.onProgress,
    this.onMetricsProgress,
    this.onCompleted,
    this.onSeekReady,
    this.onPlaybackControlsReady,
    this.onFullscreenChanged,
  });

  @override
  State<_BunnyEmbedPlayerWeb> createState() => _BunnyEmbedPlayerWebState();
}

class _BunnyEmbedPlayerWebState extends State<_BunnyEmbedPlayerWeb>
    with WidgetsBindingObserver {
  late final String _viewId;
  late final String _viewType;
  bool _isPlaying = false;
  int _actualWatchSeconds = 0;
  int _lastRecordedPosition = 0;
  bool _isSkipped = false;
  Timer? _watchHeartbeatTimer;
  int _lastDuration = 0;
  bool _hasSeekedInitial = false;
  bool _completionFired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _viewId = 'bunny_${DateTime.now().microsecondsSinceEpoch}';
    _viewType = 'bunny-player-view-$_viewId';

    _lastRecordedPosition = widget.initialProgressSeconds;
    _lastDuration = widget.totalDurationSeconds ?? 0;

    // Register iframe platform view factory
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
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
        if (kDebugMode) {
          debugPrint('[BunnyEmbed] Error initializing iframe: $e');
        }
        rethrow;
      }
    });

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

    widget.onPlaybackControlsReady?.call(play, pause, togglePlayPause);
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
              currentSeconds =
                  (val['seconds'] as num?)?.toInt() ??
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
            final effectiveDuration = totalSeconds > 0
                ? totalSeconds
                : _lastDuration;

            // Detect forward skip > 25 seconds
            if (currentSeconds - _lastRecordedPosition > 25) {
              _isSkipped = true;
            }
            if (currentSeconds > _lastRecordedPosition) {
              _isPlaying = true;
            }
            _lastRecordedPosition = currentSeconds;

            widget.onProgress?.call(currentSeconds, effectiveDuration);
            widget.onMetricsProgress?.call(
              currentSeconds,
              effectiveDuration,
              _actualWatchSeconds,
              _isSkipped,
            );

            // Safety net: when reaching near completion (within 2s or 98%)
            if (!_completionFired &&
                effectiveDuration > 0 &&
                (currentSeconds >= effectiveDuration - 2 ||
                    (currentSeconds / effectiveDuration) >= 0.98)) {
              _completionFired = true;
              widget.onCompleted?.call();
            }
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
            if (!_completionFired) {
              _completionFired = true;
              widget.onCompleted?.call();
            }
          } else if (event == 'ready' || event == 'loadeddata') {
            if (widget.initialProgressSeconds > 3 && !_hasSeekedInitial) {
              _hasSeekedInitial = true;
              seekTo(widget.initialProgressSeconds);
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[BunnyEmbed] Message handling warning: $e');
          }
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

  void play() {
    try {
      _bunnyPostMessage(_viewId.toJS, 'play'.toJS, null);
    } catch (_) {}
  }

  void pause() {
    try {
      _bunnyPostMessage(_viewId.toJS, 'pause'.toJS, null);
    } catch (_) {}
  }

  void togglePlayPause() {
    if (_isPlaying) {
      pause();
    } else {
      play();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // In Web, touching or focusing the iframe causes window blur / inactive state.
    // Only pause if the user actually minimized or hid the tab/app.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_isPlaying) {
        pause();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchHeartbeatTimer?.cancel();
    try {
      _destroyBunnyPlayer(_viewId.toJS);
    } catch (_) {}
    try {
      _onBunnyPlayerMessage = null;
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          HtmlElementView(viewType: _viewType),
          PositionedDirectional(
            top: 8,
            end: 8,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  try {
                    final seekSecs = _lastRecordedPosition > 0
                        ? _lastRecordedPosition
                        : widget.initialProgressSeconds;
                    _reloadBunnyPlayer(
                      _viewId.toJS,
                      seekSecs > 0 ? seekSecs.toJS : null,
                    );
                  } catch (_) {}
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white24,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.refresh_rounded,
                        size: 15,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.reloadPlayerAction,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
