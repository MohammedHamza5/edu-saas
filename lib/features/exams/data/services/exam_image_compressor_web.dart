import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'exam_image_compressor.dart';

@JS('compressImageToWebp')
external void _compressImageToWebp(
  JSString base64Data,
  JSNumber maxWidth,
  JSNumber maxHeight,
  JSNumber quality,
  JSFunction callback,
);

/// Web-accelerated implementation using browser's native C++ WebP Canvas encoder.
Future<CompressedImageResult> compressExamImagePlatform({
  required Uint8List bytes,
  int maxWidth = 1200,
  int maxHeight = 1200,
  double quality = 0.85,
}) async {
  try {
    final base64Input = 'data:image/png;base64,${base64Encode(bytes)}';
    final completer = Completer<String?>();

    final jsCallback = ((JSString? res) {
      if (!completer.isCompleted) {
        completer.complete(res?.toDart);
      }
    }).toJS;

    _compressImageToWebp(
      base64Input.toJS,
      maxWidth.toJS,
      maxHeight.toJS,
      quality.toJS,
      jsCallback,
    );

    final resultDataUrl = await completer.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () => null,
    );

    if (resultDataUrl != null &&
        resultDataUrl.startsWith('data:image/webp;base64,')) {
      final base64String =
          resultDataUrl.substring('data:image/webp;base64,'.length);
      final webpBytes = base64Decode(base64String);

      // Only adopt WebP if it successfully compressed and produces valid bytes
      if (webpBytes.isNotEmpty && webpBytes.length < bytes.length) {
        return CompressedImageResult(
          bytes: Uint8List.fromList(webpBytes),
          mimeType: 'image/webp',
          extension: 'webp',
          originalSize: bytes.length,
          compressedSize: webpBytes.length,
        );
      }
    }
  } catch (_) {
    // Graceful fallback to original bytes if browser fails
  }

  return CompressedImageResult(
    bytes: bytes,
    mimeType: 'image/png',
    extension: 'png',
    originalSize: bytes.length,
    compressedSize: bytes.length,
  );
}
