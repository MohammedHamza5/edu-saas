import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_service.dart';

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

    // Upload with a 30-second timeout to prevent infinite freeze.
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
          onTimeout: () => throw Exception('upload_timeout: request exceeded 30 seconds'),
        );

    // Generate long-lived signed URL (1 year = 31,536,000 seconds).
    final signedUrl = await _safeClient.storage
        .from('group-content')
        .createSignedUrl(storagePath, 31536000)
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('signed_url_timeout: request exceeded 15 seconds'),
        );

    return signedUrl;
  }
}
