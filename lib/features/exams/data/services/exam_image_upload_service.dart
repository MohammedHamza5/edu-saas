import 'dart:typed_data';
import 'package:dio/dio.dart' as dio;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_service.dart';

class ExamImageUploadService {
  final SupabaseClient? _client;

  ExamImageUploadService({SupabaseClient? client}) : _client = client;

  SupabaseClient get _safeClient => _client ?? SupabaseService.client;

  /// Uploads an exam image (crop, screenshot, or picked file)
  /// Primary target: Cloudflare R2 via `r2-storage` Edge Function.
  /// Fallback: Supabase Public Storage ('qb-documents' / 'group-content').
  Future<String> uploadExamImage({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/png',
  }) async {
    final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final finalFileName = '${timestamp}_$cleanName';

    // ── 1. Try Cloudflare R2 via Edge Function ───────────────────────────────
    try {
      final r2Res = await _safeClient.functions.invoke(
        'r2-storage',
        body: {
          'action': 'get-upload-url',
          'file_name': finalFileName,
          'content_type': mimeType,
        },
      );

      if (r2Res.status == 200 && r2Res.data is Map<String, dynamic>) {
        final data = r2Res.data as Map<String, dynamic>;
        final uploadUrl = data['upload_url'] as String?;
        final storagePath = data['storage_path'] as String?;

        if (uploadUrl != null && storagePath != null) {
          final dioClient = dio.Dio();
          final uploadRes = await dioClient.put<dynamic>(
            uploadUrl,
            data: Stream.fromIterable([bytes]),
            options: dio.Options(
              headers: {
                dio.Headers.contentTypeHeader: mimeType,
                dio.Headers.contentLengthHeader: bytes.length,
              },
            ),
          );

          if (uploadRes.statusCode == 200 || uploadRes.statusCode == 201) {
            // Get download URL or public CDN access
            final dlRes = await _safeClient.functions.invoke(
              'r2-storage',
              body: {
                'action': 'get-download-url',
                'storage_path': storagePath,
              },
            );

            if (dlRes.status == 200 && dlRes.data is Map<String, dynamic>) {
              final dlUrl = dlRes.data['download_url'] as String?;
              if (dlUrl != null && dlUrl.isNotEmpty) {
                return dlUrl;
              }
            }
          }
        }
      }
    } catch (_) {
      // Graceful fallback to Supabase Storage if Cloudflare R2 edge function is offline
    }

    // ── 2. Fallback: Supabase Storage ─────────────────────────────────────────
    final storagePath = 'exam_images/$finalFileName';

    try {
      await _safeClient.storage
          .from('qb-documents')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: true,
            ),
          );

      return _safeClient.storage
          .from('qb-documents')
          .getPublicUrl(storagePath);
    } catch (_) {
      // Secondary fallback to group-content
      await _safeClient.storage
          .from('group-content')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: true,
            ),
          );

      return _safeClient.storage
          .from('group-content')
          .getPublicUrl(storagePath);
    }
  }
}
