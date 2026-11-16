import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/utils/app_logger.dart';

/// Result entity containing the raw audio bytes, duration, and metadata
class VoiceRecordingResult {
  final Uint8List bytes;
  final String fileName;
  final int durationSeconds;
  final String previewPathOrUrl;

  const VoiceRecordingResult({
    required this.bytes,
    required this.fileName,
    required this.durationSeconds,
    required this.previewPathOrUrl,
  });
}

/// Service managing the live microphone recording lifecycle, compression parameters,
/// and cross-platform audio extraction (Web Blob & Native Files).
class VoiceRecordingService {
  final AudioRecorder _recorder;

  Timer? _durationTimer;
  int _currentSeconds = 0;
  final _durationController = StreamController<int>.broadcast();

  VoiceRecordingService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  /// Stream of elapsed recording duration in seconds
  Stream<int> get durationStream => _durationController.stream;

  /// Current recorded duration in seconds
  int get currentDurationSeconds => _currentSeconds;

  /// Checks and requests microphone permission
  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e, stack) {
      AppLogger.e(
        'VoiceRecordingService',
        'Failed to check microphone permission',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// Whether the recorder is actively recording
  Future<bool> isRecording() async {
    try {
      return await _recorder.isRecording();
    } catch (_) {
      return false;
    }
  }

  /// Starts recording with 32kbps mono voice compression
  Future<void> start() async {
    try {
      final permitted = await hasPermission();
      if (!permitted) {
        throw Exception('Microphone permission not granted');
      }

      AudioEncoder encoder = AudioEncoder.aacLc;
      String extension = 'm4a';

      if (kIsWeb) {
        if (await _recorder.isEncoderSupported(AudioEncoder.opus)) {
          encoder = AudioEncoder.opus;
          extension = 'webm';
        }
      }

      final config = RecordConfig(
        encoder: encoder,
        bitRate: 32000,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      );

      String filePath = '';
      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        filePath = '${tempDir.path}/voice_$timestamp.$extension';
      }

      await _recorder.start(config, path: filePath);

      _currentSeconds = 0;
      _durationController.add(0);
      _durationTimer?.cancel();
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _currentSeconds++;
        _durationController.add(_currentSeconds);
      });

      AppLogger.i('VoiceRecordingService', 'Recording started (encoder: $encoder)');
    } catch (e, stack) {
      _stopTimer();
      AppLogger.e('VoiceRecordingService', 'Failed to start recording', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Stops recording, retrieves compressed bytes, and returns [VoiceRecordingResult]
  Future<VoiceRecordingResult?> stop() async {
    try {
      final duration = _currentSeconds;
      _stopTimer();

      final pathOrUrl = await _recorder.stop();
      if (pathOrUrl == null || pathOrUrl.isEmpty) {
        AppLogger.w('VoiceRecordingService', 'Recorder returned empty path/url');
        return null;
      }

      Uint8List bytes;
      String extension = 'm4a';

      if (kIsWeb || pathOrUrl.startsWith('blob:') || pathOrUrl.startsWith('http')) {
        final res = await http.get(Uri.parse(pathOrUrl));
        bytes = res.bodyBytes;
        if (pathOrUrl.contains('webm') || (res.headers['content-type']?.contains('webm') ?? false)) {
          extension = 'webm';
        }
      } else {
        final file = File(pathOrUrl);
        bytes = await file.readAsBytes();
        if (pathOrUrl.endsWith('.webm')) {
          extension = 'webm';
        }
        try {
          await file.delete();
        } catch (_) {}
      }

      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.$extension';
      AppLogger.i(
        'VoiceRecordingService',
        'Recording stopped. Bytes: ${bytes.length}, duration: ${duration}s, ext: $extension',
      );

      return VoiceRecordingResult(
        bytes: bytes,
        fileName: fileName,
        durationSeconds: duration > 0 ? duration : 1,
        previewPathOrUrl: pathOrUrl,
      );
    } catch (e, stack) {
      _stopTimer();
      AppLogger.e('VoiceRecordingService', 'Failed to stop recording', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Cancels and discards the active recording session
  Future<void> cancel() async {
    try {
      _stopTimer();
      await _recorder.cancel();
      AppLogger.i('VoiceRecordingService', 'Recording cancelled');
    } catch (e, stack) {
      AppLogger.e('VoiceRecordingService', 'Failed to cancel recording', error: e, stackTrace: stack);
    }
  }

  void _stopTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _currentSeconds = 0;
  }

  /// Releases recorder and stream resources
  void dispose() {
    _stopTimer();
    _durationController.close();
    _recorder.dispose();
  }
}
