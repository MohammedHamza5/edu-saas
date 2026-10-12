import 'dart:typed_data';

import 'exam_image_compressor_stub.dart'
    if (dart.library.js_interop) 'exam_image_compressor_web.dart';

/// Data class holding the result of image compression.
class CompressedImageResult {
  final Uint8List bytes;
  final String mimeType;
  final String extension;
  final int originalSize;
  final int compressedSize;

  const CompressedImageResult({
    required this.bytes,
    required this.mimeType,
    required this.extension,
    required this.originalSize,
    required this.compressedSize,
  });

  /// The percentage of data saved (e.g. 85.4%).
  double get compressionRatio => originalSize > 0
      ? ((1.0 - (compressedSize / originalSize)) * 100.0).clamp(0.0, 100.0)
      : 0.0;

  /// True if the output is smaller than the input.
  bool get wasCompressed => compressedSize < originalSize;

  /// Formatted description for logging.
  String get summary =>
      '${(originalSize / 1024).toStringAsFixed(1)} KB -> ${(compressedSize / 1024).toStringAsFixed(1)} KB (${compressionRatio.toStringAsFixed(1)}% reduction, $mimeType)';
}

/// Abstract or delegate class to compress exam images prior to upload.
abstract class ExamImageCompressor {
  /// Compresses [bytes] into WebP (or downscales if needed).
  /// Falls back gracefully to original [bytes] if compression is unavailable or larger.
  static Future<CompressedImageResult> compress({
    required Uint8List bytes,
    int maxWidth = 1200,
    int maxHeight = 1200,
    double quality = 0.85,
  }) {
    return compressExamImagePlatform(
      bytes: bytes,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      quality: quality,
    );
  }
}
