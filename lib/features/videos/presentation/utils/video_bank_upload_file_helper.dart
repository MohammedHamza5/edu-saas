import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';

class VideoPickResult {
  final PlatformFile file;
  final Uint8List bytes;

  const VideoPickResult({
    required this.file,
    required this.bytes,
  });
}

/// Helper class isolating file picking, byte extraction, and size limit checks
/// for video uploads across Web, Desktop, and Mobile.
class VideoBankUploadFileHelper {
  const VideoBankUploadFileHelper._();

  static Future<VideoPickResult?> pickVideoFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = result.files.first;
      final sizeMb = (file.size / (1024 * 1024)).toStringAsFixed(1);

      // Web browsers have a hard memory buffer limit (~1.5GB to 2GB)
      if (kIsWeb && file.size > 2000 * 1024 * 1024) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.videoFileTooLargeForWeb(sizeMb)),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 8),
            ),
          );
        }
        return null;
      }

      Uint8List? bytes = file.bytes;

      // If bytes are null on desktop/mobile, read from path
      if (!kIsWeb && bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else if (bytes == null && file.readStream != null) {
        final chunks = await file.readStream!.toList();
        final total = chunks.fold<int>(0, (sum, c) => sum + c.length);
        final buffer = Uint8List(total);
        int offset = 0;
        for (final c in chunks) {
          buffer.setRange(offset, offset + c.length, c);
          offset += c.length;
        }
        bytes = buffer;
      }

      if (bytes != null) {
        return VideoPickResult(file: file, bytes: bytes);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.videoFileMemoryError(sizeMb)),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 8),
            ),
          );
        }
        return null;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return null;
    }
  }
}
