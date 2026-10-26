import 'dart:typed_data';

/// Domain contract for uploading exam-related images.
/// Decouples presentation builders and widgets from concrete network/compression services.
abstract interface class ExamImageUploader {
  Future<String> uploadExamImage({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/png',
  });
}
