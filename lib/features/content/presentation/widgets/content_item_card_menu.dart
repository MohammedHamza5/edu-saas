import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/content_entity.dart';

/// Popup actions menu for teacher content management in ContentItemCard.
class ContentItemCardMenu extends StatelessWidget {
  final ContentEntity content;
  final bool hasFile;
  final VoidCallback? onUploadVideo;
  final VoidCallback? onEdit;
  final VoidCallback? onTogglePublish;
  final VoidCallback? onToggleArchive;
  final ValueChanged<String>? onOpenFile;
  final VoidCallback? onDelete;

  const ContentItemCardMenu({
    super.key,
    required this.content,
    required this.hasFile,
    this.onUploadVideo,
    this.onEdit,
    this.onTogglePublish,
    this.onToggleArchive,
    this.onOpenFile,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert_rounded,
        size: 20,
        color: AppColors.textSecondary,
      ),
      onSelected: (value) {
        switch (value) {
          case 'upload_video':
            onUploadVideo?.call();
          case 'edit':
            onEdit?.call();
          case 'toggle_publish':
            onTogglePublish?.call();
          case 'toggle_archive':
            onToggleArchive?.call();
          case 'open_file':
            if (hasFile && onOpenFile != null) {
              onOpenFile!(content.file!.storagePath);
            }
          case 'delete':
            onDelete?.call();
        }
      },
      itemBuilder: (ctx) => [
        if (content.type == ContentType.video && onUploadVideo != null)
          PopupMenuItem(
            value: 'upload_video',
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_upload_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  ctx.l10n.uploadUpdateLectureVideo,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        if (hasFile)
          PopupMenuItem(
            value: 'open_file',
            child: Row(
              children: [
                const Icon(Icons.download_rounded, size: 16),
                const SizedBox(width: 8),
                Text(ctx.l10n.downloadOrOpenAction),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, size: 16),
              const SizedBox(width: 8),
              Text(ctx.l10n.editMetadataAction),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'toggle_publish',
          child: Row(
            children: [
              Icon(
                content.isPublished
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                content.isPublished
                    ? ctx.l10n.convertToDraft
                    : ctx.l10n.publishToStudents,
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'toggle_archive',
          child: Row(
            children: [
              Icon(
                content.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                content.isArchived
                    ? ctx.l10n.unarchiveMaterial
                    : ctx.l10n.archiveMaterial,
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(
                Icons.delete_outline,
                size: 16,
                color: AppColors.error,
              ),
              const SizedBox(width: 8),
              Text(
                ctx.l10n.permanentDelete,
                style: const TextStyle(color: AppColors.error),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
