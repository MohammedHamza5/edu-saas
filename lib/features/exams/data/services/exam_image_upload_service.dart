import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_service.dart';
import '../../../../core/utils/app_logger.dart';

import 'exam_image_compressor.dart';

class ExamImageUploadService {
  final SupabaseClient? _client;

  ExamImageUploadService({SupabaseClient? client}) : _client = client;

  SupabaseClient get _safeClient => _client ?? SupabaseService.client;

  /// Uploads an exam image (crop, screenshot, or picked file).
  /// Automatically compresses and transcodes to WebP (Phase 2 optimization)
  /// before uploading to Supabase 'group-content' bucket → 'test/exam_images/' path.
  Future<String> uploadExamImage({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/png',
  }) async {
    // 1. Compress and convert to WebP
    final compressionResult = await ExamImageCompressor.compress(
      bytes: bytes,
      maxWidth: 1200,
      maxHeight: 1200,
      quality: 0.85,
    );

    final effectiveBytes = compressionResult.bytes;
    final effectiveMimeType = compressionResult.mimeType;
    final extension = compressionResult.extension;

    var cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    if (extension == 'webp') {
      cleanName = cleanName.replaceAll(
            RegExp(r'\.(png|jpg|jpeg|gif|webp)$', caseSensitive: false),
            '',
          ) +
          '.webp';
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final finalFileName = '${timestamp}_$cleanName';
    final storagePath = 'test/exam_images/$finalFileName';

    final user = _safeClient.auth.currentUser;
    AppLogger.i(
      'UploadService',
      '🚀 [UploadService] uploadExamImage starting (${compressionResult.summary}):',
    );
    AppLogger.d('UploadService', '  - FileName: $fileName -> $finalFileName');
    AppLogger.d(
      'UploadService',
      '  - Original bytes: ${bytes.length} (${(bytes.length / 1024).toStringAsFixed(1)} KB)',
    );
    AppLogger.d(
      'UploadService',
      '  - Effective bytes: ${effectiveBytes.length} (${(effectiveBytes.length / 1024).toStringAsFixed(1)} KB, $effectiveMimeType)',
    );
    AppLogger.d('UploadService', '  - Target path: group-content/$storagePath');
    AppLogger.d('UploadService', '  - Current user ID: ${user?.id}');
    AppLogger.d('UploadService', '  - Current user email: ${user?.email}');
    AppLogger.d(
      'UploadService',
      '  - Session valid: ${_safeClient.auth.currentSession != null}',
    );

    try {
      // Ensure a plain Uint8List for web release (JS TypedArray interop safety).
      final payload = Uint8List.fromList(effectiveBytes);

      AppLogger.i(
        'UploadService',
        '⏳ [UploadService] Starting uploadBinary to Supabase Storage...',
      );
      final uploadStartTime = DateTime.now();

      final uploadPath = await _safeClient.storage
          .from('group-content')
          .uploadBinary(
            storagePath,
            payload,
            fileOptions: FileOptions(
              contentType: effectiveMimeType,
              upsert: true,
            ),
          );

      final uploadDuration = DateTime.now()
          .difference(uploadStartTime)
          .inMilliseconds;
      AppLogger.s(
        'UploadService',
        '✅ [UploadService] Supabase uploadBinary completed successfully in ${uploadDuration}ms. Path: $uploadPath',
      );

      AppLogger.i(
        'UploadService',
        '⏳ [UploadService] Generating signed URL (valid 1 year)...',
      );
      final signStartTime = DateTime.now();

      final signedUrl = await _safeClient.storage
          .from('group-content')
          .createSignedUrl(storagePath, 31536000)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              AppLogger.e(
                'UploadService',
                '❌ [UploadService] createSignedUrl TIMEOUT after 15 seconds',
              );
              throw Exception(
                'signed_url_timeout: request exceeded 15 seconds',
              );
            },
          );

      final signDuration = DateTime.now()
          .difference(signStartTime)
          .inMilliseconds;
      AppLogger.s(
        'UploadService',
        '✅ [UploadService] Signed URL generated in ${signDuration}ms: $signedUrl',
      );

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
