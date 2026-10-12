import 'dart:typed_data';

import 'exam_image_compressor.dart';

/// Native/VM fallback implementation.
Future<CompressedImageResult> compressExamImagePlatform({
  required Uint8List bytes,
  int maxWidth = 1200,
  int maxHeight = 1200,
  double quality = 0.85,
}) async {
  // On native non-web platforms, return original bytes safely.
  return CompressedImageResult(
    bytes: bytes,
    mimeType: 'image/png',
    extension: 'png',
    originalSize: bytes.length,
    compressedSize: bytes.length,
  );
}
