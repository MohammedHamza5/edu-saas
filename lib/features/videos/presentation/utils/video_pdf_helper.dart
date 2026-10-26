import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/pdf_launcher_helper.dart';
import '../../../content/domain/entities/content_entity.dart';
import '../../../content/presentation/widgets/material_viewer_sheet.dart';
import '../../domain/entities/video_entity.dart';
import '../cubit/videos_cubit.dart';

/// Helper for opening, previewing, and attaching PDF documents in the video player.
class VideoPdfHelper {
  VideoPdfHelper._();

  /// Opens the PDF material viewer sheet.
  static Future<void> openAttachedMaterial({
    required BuildContext context,
    required VideoEntity video,
    required String? preloadedPdfPath,
    required String? preloadedPdfUrl,
  }) async {
    final file = video.attachedFile;
    if (file == null) return;

    final contentWrapper = ContentEntity(
      id: video.contentId,
      tenantId: file.tenantId,
      groupId: '',
      title: video.title ?? file.fileName,
      description: video.description,
      type: ContentType.pdf,
      status: ContentStatus.published,
      file: file,
      createdAt: video.createdAt,
      updatedAt: video.updatedAt,
    );

    final cubit = context.read<VideosCubit>();
    await MaterialViewerSheet.show(
      context,
      content: contentWrapper,
      onGetSignedUrl: (storagePath) async {
        final path = storagePath.isNotEmpty ? storagePath : file.storagePath;
        if (preloadedPdfPath == path && preloadedPdfUrl != null) {
          return preloadedPdfUrl;
        }
        return cubit.getSignedFileUrl(path);
      },
    );
  }

  /// Opens PDF directly in an external viewer or browser tab with pre-warmed URL support.
  static Future<String?> openPdfDirectly({
    required BuildContext context,
    required String storagePath,
    required String? preloadedPdfPath,
    required String? preloadedPdfUrl,
    required void Function(bool isOpening) onOpeningStateChanged,
  }) async {
    if (storagePath.isEmpty) return null;

    if (preloadedPdfPath == storagePath &&
        preloadedPdfUrl != null &&
        preloadedPdfUrl.isNotEmpty) {
      unawaited(
        PdfLauncherHelper.launchPdfUrl(preloadedPdfUrl, context: context),
      );
      return preloadedPdfUrl;
    }

    onOpeningStateChanged(true);
    try {
      final cubit = context.read<VideosCubit>();
      final url = await cubit.getSignedFileUrl(storagePath);
      if (context.mounted && url != null && url.isNotEmpty) {
        unawaited(PdfLauncherHelper.launchPdfUrl(url, context: context));
        return url;
      }
    } finally {
      onOpeningStateChanged(false);
    }
    return null;
  }

  /// Prompts teacher to pick a document and attaches it to the active video.
  static Future<bool> pickAndAttachPdf({
    required BuildContext context,
    required VideoEntity video,
    required void Function(bool isAttaching) onAttachingStateChanged,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) return false;

        if (!context.mounted) return false;
        final cubit = context.read<VideosCubit>();
        onAttachingStateChanged(true);

        final success = await cubit.attachMaterialToVideo(
          videoId: video.id,
          contentId: video.contentId,
          fileName: file.name,
          fileBytes: bytes,
        );

        if (context.mounted) {
          onAttachingStateChanged(false);
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.success,
                content: Text(context.l10n.contentCreatedToast),
              ),
            );
          }
          return success;
        }
      }
    } catch (e) {
      if (context.mounted) {
        onAttachingStateChanged(false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(e.toString()),
          ),
        );
      }
    }
    return false;
  }
}
