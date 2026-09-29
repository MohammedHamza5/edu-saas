import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_service.dart';

class ExamImageUploadService {
  final SupabaseClient? _client;

  ExamImageUploadService({SupabaseClient? client}) : _client = client;

  SupabaseClient get _safeClient => _client ?? SupabaseService.client;

  /// Uploads an exam image (crop, screenshot, or picked file)
  /// Storage: Supabase 'group-content' bucket → 'test/exam_images/' path (RLS-authorized).
  /// Note: Cloudflare R2 via Dio was causing browser CORS freeze.
  ///       Will re-enable via http.put when R2 bucket CORS is configured.
  Future<String> uploadExamImage({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/png',
  }) async {
    final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final finalFileName = '${timestamp}_$cleanName';

    // ── Supabase Storage 'group-content' with 'test/' RLS path ───────────────
    final storagePath = 'test/exam_images/$finalFileName';

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

    // Generate long-lived signed URL (1 year = 31,536,000 seconds)
    final signedUrl = await _safeClient.storage
        .from('group-content')
        .createSignedUrl(storagePath, 31536000);

    return signedUrl;
  }
}
