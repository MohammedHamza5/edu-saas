import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/utils/app_logger.dart';

class ExamImageUploadService {
  final SupabaseClient? _client;

  ExamImageUploadService({SupabaseClient? client}) : _client = client;

  SupabaseClient get _safeClient => _client ?? SupabaseService.client;

  /// Uploads an exam image (crop, screenshot, or picked file)
  /// Storage: Supabase 'group-content' bucket → 'test/exam_images/' path (RLS-authorized).
  Future<String> uploadExamImage({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/png',
  }) async {
    final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final finalFileName = '${timestamp}_$cleanName';
    final storagePath = 'test/exam_images/$finalFileName';

    final user = _safeClient.auth.currentUser;
    AppLogger.i('UploadService', '🚀 [UploadService] uploadExamImage starting:');
    AppLogger.d('UploadService', '  - FileName: $fileName -> $finalFileName');
    AppLogger.d('UploadService', '  - Bytes count: ${bytes.length} bytes (${(bytes.length / 1024).toStringAsFixed(1)} KB)');
    AppLogger.d('UploadService', '  - Target path: group-content/$storagePath');
    AppLogger.d('UploadService', '  - Current user ID: ${user?.id}');
    AppLogger.d('UploadService', '  - Current user email: ${user?.email}');
    AppLogger.d('UploadService', '  - Session valid: ${_safeClient.auth.currentSession != null}');

    try {
      AppLogger.i('UploadService', '⏳ [UploadService] Starting uploadBinary to Supabase Storage...');
      final uploadStartTime = DateTime.now();

      await _safeClient.storage
          .from('group-content')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: true,
            ),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              AppLogger.e('UploadService', '❌ [UploadService] uploadBinary TIMEOUT after 30 seconds');
              throw Exception('upload_timeout: request exceeded 30 seconds');
            },
          );

      final uploadDuration = DateTime.now().difference(uploadStartTime).inMilliseconds;
      AppLogger.s('UploadService', '✅ [UploadService] uploadBinary completed successfully in ${uploadDuration}ms');

      AppLogger.i('UploadService', '⏳ [UploadService] Generating signed URL (valid 1 year)...');
      final signStartTime = DateTime.now();

      final signedUrl = await _safeClient.storage
          .from('group-content')
          .createSignedUrl(storagePath, 31536000)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              AppLogger.e('UploadService', '❌ [UploadService] createSignedUrl TIMEOUT after 15 seconds');
              throw Exception('signed_url_timeout: request exceeded 15 seconds');
            },
          );

      final signDuration = DateTime.now().difference(signStartTime).inMilliseconds;
      AppLogger.s('UploadService', '✅ [UploadService] Signed URL generated in ${signDuration}ms: $signedUrl');

      return signedUrl;
    } on StorageException catch (se, st) {
      AppLogger.e(
        'UploadService',
        '❌ [UploadService] StorageException: status=${se.statusCode}, message=${se.message}, error=${se.error}',
        error: se,
        stackTrace: st,
      );
      rethrow;
    } catch (e, st) {
      AppLogger.e(
        'UploadService',
        '❌ [UploadService] Unexpected error during image upload: $e',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}

