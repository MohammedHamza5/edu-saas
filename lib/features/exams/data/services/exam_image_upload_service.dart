import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_service.dart';
import '../../../../core/utils/app_logger.dart';

import 'exam_image_compressor.dart';

class ExamImageUploadService {
  final SupabaseClient? _client;

  ExamImageUploadService({SupabaseClient? client}) : _client = client;

  SupabaseClient get _safeClient => _client ?? SupabaseService.client;

  /// Global serial queue for exam image uploads.
  /// Guarantees that when multiple images across questions are uploaded simultaneously,
  /// they are sent sequentially to Supabase Storage, completely eliminating
  /// database connection pool exhaustion (HTTP 544 DatabaseTimeout) and timeouts.
  static Future<void> _uploadQueue = Future.value();

  /// Uploads an exam image (crop, screenshot, or picked file).
  /// Automatically compresses and transcodes to WebP before uploading to
  /// Supabase 'group-content' bucket → 'test/exam_images/' path.
  Future<String> uploadExamImage({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/png',
  }) async {
    // 1. Instant local compression & WebP transcoding (runs concurrently in memory)
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
      final base = cleanName.replaceAll(
        RegExp(r'\.(png|jpg|jpeg|gif|webp)$', caseSensitive: false),
        '',
      );
      cleanName = '$base.webp';
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final finalFileName = '${timestamp}_$cleanName';
    final storagePath = 'test/exam_images/$finalFileName';

    final user = _safeClient.auth.currentUser;
    AppLogger.i(
      'UploadService',
      '🚀 [UploadService] Enqueuing exam image upload (${compressionResult.summary}): $finalFileName for user ${user?.email}',
    );

    // 2. Enqueue network upload through serial queue to protect database connection pool
    final completer = Completer<String>();

    _uploadQueue = _uploadQueue.catchError((_) {}).then((_) async {
      try {
        final result = await _performUploadWithRetry(
          effectiveBytes: effectiveBytes,
          effectiveMimeType: effectiveMimeType,
          storagePath: storagePath,
          fileName: fileName,
          finalFileName: finalFileName,
          summary: compressionResult.summary,
        );
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });

    return completer.future;
  }

  Future<String> _performUploadWithRetry({
    required List<int> effectiveBytes,
    required String effectiveMimeType,
    required String storagePath,
    required String fileName,
    required String finalFileName,
    required String summary,
  }) async {
    const maxRetries = 2;
    int attempt = 0;

    while (true) {
      attempt++;
      try {
        // Ensure fresh authentication token before hitting storage
        try {
          await SupabaseService.ensureFreshSession();
        } catch (e) {
          AppLogger.w('UploadService', '⚠️ Pre-upload session check warning: $e');
        }

        final payload = Uint8List.fromList(effectiveBytes);
        final uploadStartTime = DateTime.now();

        AppLogger.i(
          'UploadService',
          '⏳ [UploadService] Starting uploadBinary (attempt $attempt) for $finalFileName...',
        );

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

        final uploadDuration =
            DateTime.now().difference(uploadStartTime).inMilliseconds;
        AppLogger.s(
          'UploadService',
          '✅ [UploadService] Supabase uploadBinary completed in ${uploadDuration}ms: $uploadPath',
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
              const Duration(seconds: 45),
              onTimeout: () {
                throw TimeoutException(
                  'signed_url_timeout: request exceeded 45 seconds',
                );
              },
            );

        final signDuration =
            DateTime.now().difference(signStartTime).inMilliseconds;
        AppLogger.s(
          'UploadService',
          '✅ [UploadService] Signed URL generated in ${signDuration}ms: $signedUrl',
        );

        return signedUrl;
      } on StorageException catch (se, st) {
        final isAuthError = se.statusCode == '403' ||
            se.statusCode == '401' ||
            (se.message.contains('row-level security')) ||
            (se.error?.contains('Unauthorized') ?? false);

        final isDatabaseTimeout = se.statusCode == '544' ||
            se.statusCode == '504' ||
            se.statusCode == '502' ||
            se.statusCode == '503' ||
            (se.message.contains('DatabaseTimeout')) ||
            (se.message.contains('timed out'));

        if (isAuthError && attempt <= maxRetries) {
          AppLogger.w(
            'UploadService',
            '⚠️ 403 StorageException on attempt $attempt. Refreshing session & retrying...',
          );
          try {
            await _safeClient.auth.refreshSession();
          } catch (_) {}
          await Future<void>.delayed(const Duration(milliseconds: 600));
          continue;
        }

        if (isDatabaseTimeout && attempt <= maxRetries) {
          AppLogger.w(
            'UploadService',
            '⚠️ 544 DatabaseTimeout on attempt $attempt. Backing off ${attempt * 1.5}s & retrying...',
          );
          await Future<void>.delayed(Duration(milliseconds: (attempt * 1500)));
          continue;
        }

        AppLogger.e(
          'UploadService',
          '❌ [UploadService] StorageException (attempt $attempt): status=${se.statusCode}, message=${se.message}, error=${se.error}',
          error: se,
          stackTrace: st,
        );
        rethrow;
      } catch (e, st) {
        final isTimeout =
            e is TimeoutException || e.toString().contains('timeout');

        if (isTimeout && attempt <= maxRetries) {
          AppLogger.w(
            'UploadService',
            '⚠️ Timeout on attempt $attempt. Backing off 1.5s & retrying...',
          );
          await Future<void>.delayed(const Duration(milliseconds: 1500));
          continue;
        }

        AppLogger.e(
          'UploadService',
          '❌ [UploadService] Unexpected error on attempt $attempt: $e',
          error: e,
          stackTrace: st,
        );
        rethrow;
      }
    }
  }
}
