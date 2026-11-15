import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/audio_url_resolver.dart';

/// Compact, elegant voice explanation audio player for exam questions.
/// Supports play/pause, seek slider, duration display, and 1.0x - 2.0x speed toggling.
class QuestionAudioPlayer extends StatefulWidget {
  final String? audioUrl;
  final int? initialDurationSeconds;
  final Uint8List? localBytes;

  const QuestionAudioPlayer({
    super.key,
    required this.audioUrl,
    this.initialDurationSeconds,
    this.localBytes,
  });

  @override
  State<QuestionAudioPlayer> createState() => _QuestionAudioPlayerState();
}

class _QuestionAudioPlayerState extends State<QuestionAudioPlayer> {
  late final AudioPlayer _player;
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isLoading = false;
  bool _hasError = false;
  double _playbackSpeed = 1.0;

  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;

  static const List<double> _availableSpeeds = [1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    unawaited(_player.setVolume(1.0));

    if (widget.initialDurationSeconds != null && widget.initialDurationSeconds! > 0) {
      _duration = Duration(seconds: widget.initialDurationSeconds!);
    }

    _stateSubscription = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _playerState = state;
        if (state == PlayerState.playing) {
          _isLoading = false;
        } else if (state == PlayerState.completed) {
          _position = Duration.zero;
        }
      });
    });

    _positionSubscription = _player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
    });

    _durationSubscription = _player.onDurationChanged.listen((dur) {
      if (!mounted) return;
      setState(() => _duration = dur);
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    final hasBytes = widget.localBytes != null && widget.localBytes!.isNotEmpty;
    final resolvedUrl = AudioUrlResolver.resolve(widget.audioUrl);
    if (!hasBytes && (resolvedUrl == null || resolvedUrl.isEmpty)) return;

    if (_playerState == PlayerState.playing) {
      await _player.pause();
    } else {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      try {
        if (_playerState == PlayerState.paused) {
          await _player.resume();
        } else {
          await _player.setPlaybackRate(_playbackSpeed);
          if (hasBytes) {
            await _player.play(BytesSource(widget.localBytes!));
          } else {
            await _player.play(UrlSource(resolvedUrl!));
          }
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _cycleSpeed() async {
    final currentIndex = _availableSpeeds.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % _availableSpeeds.length;
    final nextSpeed = _availableSpeeds[nextIndex];

    setState(() => _playbackSpeed = nextSpeed);
    await _player.setPlaybackRate(nextSpeed);
  }

  Future<void> _seek(double value) async {
    final targetPosition = Duration(milliseconds: value.toInt());
    await _player.seek(targetPosition);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = AudioUrlResolver.resolve(widget.audioUrl);
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final isPlaying = _playerState == PlayerState.playing;

    final maxMilliseconds = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds.toDouble()
        : 1000.0;
    final currentMilliseconds = _position.inMilliseconds
        .clamp(0, maxMilliseconds.toInt())
        .toDouble();

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.s12, bottom: AppSpacing.s8),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.22),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Voice Explanation Title & Icon
              const Icon(
                Icons.record_voice_over_rounded,
                size: 17,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                l10n.audioExplanationLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              // Speed multiplier pill button
              InkWell(
                onTap: _cycleSpeed,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  ),
                  child: Text(
                    '${_playbackSpeed}x',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: [
              // Play/Pause Action Button
              SizedBox(
                width: 38,
                height: 38,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: _isLoading ? null : _togglePlayPause,
                  tooltip: isPlaying ? l10n.audioPauseTooltip : l10n.audioPlayTooltip,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 22,
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              // Seek Slider & Duration Track
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        trackHeight: 3,
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: AppColors.primary.withValues(alpha: 0.18),
                        thumbColor: AppColors.primary,
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      ),
                      child: Slider(
                        value: currentMilliseconds,
                        min: 0,
                        max: maxMilliseconds,
                        onChanged: (val) {
                          if (_hasError) return;
                          _seek(val);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (_hasError)
                            Text(
                              l10n.audioError,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            Text(
                              _formatDuration(_duration),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
