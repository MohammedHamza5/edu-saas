import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_service.dart';
import '../../../../core/utils/app_logger.dart';

class ExamAudioUploadService {
  final SupabaseClient? _client;

  ExamAudioUploadService({SupabaseClient? client}) : _client = client;

  SupabaseClient get _safeClient => _client ?? SupabaseService.client;

  /// Global serial queue for exam audio uploads to avoid saturation.
  static Future<void> _uploadQueue = Future.value();

  /// Uploads audio recording or picked file to 'exam-audio' bucket.
  Future<String> uploadAudio({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'audio/mp4',
  }) async {
    var cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final finalFileName = '${timestamp}_$cleanName';
    final storagePath = 'audio/$finalFileName';

    final user = _safeClient.auth.currentUser;
    AppLogger.i(
      'ExamAudioUploadService',
      'Enqueuing audio upload: $storagePath (${bytes.lengthInBytes} bytes) for user: ${user?.id}',
    );

    final completer = Completer<String>();

    _uploadQueue = _uploadQueue.catchError((_) {}).then((_) async {
      try {
        try {
          await SupabaseService.ensureFreshSession();
        } catch (_) {}

        AppLogger.i(
          'ExamAudioUploadService',
          'Starting Supabase audio upload: $storagePath',
        );

        try {
          final res = await _safeClient.storage
              .from('exam-audio')
              .uploadBinary(
                storagePath,
                bytes,
                fileOptions: FileOptions(
                  contentType: mimeType,
                  upsert: true,
                ),
              );

          AppLogger.i('ExamAudioUploadService', 'Upload completed: $res');

          final publicUrl = _safeClient.storage
              .from('exam-audio')
              .getPublicUrl(storagePath);

          completer.complete(publicUrl);
        } catch (storageError) {
          AppLogger.w(
            'ExamAudioUploadService',
            'exam-audio bucket upload failed ($storageError), attempting group-content fallback...',
          );
          final fallbackPath = 'audio/$finalFileName';
          await _safeClient.storage
              .from('group-content')
              .uploadBinary(
                fallbackPath,
                bytes,
                fileOptions: FileOptions(
                  contentType: mimeType,
                  upsert: true,
                ),
              );
          final signedUrl = await _safeClient.storage
              .from('group-content')
              .createSignedUrl(fallbackPath, 31536000);
          completer.complete(signedUrl);
        }
      } catch (e, stack) {
        AppLogger.e(
          'ExamAudioUploadService',
          'Upload failed for $storagePath',
          error: e,
          stackTrace: stack,
        );
        completer.completeError(e, stack);
      }
    });

    return completer.future;
  }
}
