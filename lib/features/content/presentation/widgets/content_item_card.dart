import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/content_entity.dart';

class ContentItemCard extends StatelessWidget {
  final ContentEntity content;
  final bool isTeacher;
  final int? index;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTogglePublish;
  final VoidCallback? onToggleArchive;
  final ValueChanged<String>? onOpenFile;
  final VoidCallback? onUploadVideo;
  final VoidCallback? onTap;

  const ContentItemCard({
    super.key,
    required this.content,
    this.isTeacher = false,
    this.index,
    this.onEdit,
    this.onDelete,
    this.onTogglePublish,
    this.onToggleArchive,
    this.onOpenFile,
    this.onUploadVideo,
    this.onTap,
  });

  IconData get _typeIcon {
    return switch (content.type) {
      ContentType.video => Icons.play_circle_fill_rounded,
      ContentType.pdf => Icons.picture_as_pdf_rounded,
      ContentType.image => Icons.image_rounded,
      ContentType.assignment => Icons.assignment_rounded,
      ContentType.exam => Icons.quiz_rounded,
    };
  }

  Color get _typeColor {
    return switch (content.type) {
      ContentType.video => AppColors.primary,
      ContentType.pdf => const Color(0xFFEA580C), // Deep Orange / Academic Math Red
      ContentType.image => Colors.purple,
      ContentType.assignment => AppColors.warning,
      ContentType.exam => AppColors.success,
    };
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = content.file != null;

    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s12),
      onTap: onTap ??
          (hasFile && onOpenFile != null
              ? () => onOpenFile!(content.file!.storagePath)
              : null),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle for Teacher when reordering
          if (isTeacher && index != null) ...[
            ReorderableDragStartListener(
              index: index!,
              child: const Padding(
                padding: EdgeInsetsDirectional.only(
                  end: AppSpacing.s8,
                  top: AppSpacing.s8,
                ),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  color: AppColors.textMuted,
                  size: 22,
                ),
              ),
            ),
          ],

          // Type Icon Avatar with subtle mathematical gradient & border
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _typeColor.withAlpha(25),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              border: Border.all(color: _typeColor.withAlpha(60)),
            ),
            child: Icon(
              _typeIcon,
              color: _typeColor,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),

          // Main Details Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Quick Status Tag
                Text(
                  content.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.s4),

                // Badges in Wrap (Zero overflow)
                Wrap(
                  spacing: AppSpacing.s6,
                  runSpacing: AppSpacing.s4,
                  children: [
                    AppBadge(
                      label: content.type.localizedLabel(context),
                      variant: AppBadgeVariant.neutral,
                    ),
                    if (isTeacher)
                      AppBadge(
                        label: content.status.localizedLabel(context),
                        variant: switch (content.status) {
                          ContentStatus.published => AppBadgeVariant.active,
                          ContentStatus.draft => AppBadgeVariant.pending,
                          ContentStatus.archived => AppBadgeVariant.suspended,
                        },
                      ),
                  ],
                ),

                // Description (if present)
                if (content.description != null &&
                    content.description!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s6),
                  Text(
                    content.description!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: AppSpacing.s10),

                // Attachment File Link (if attached)
                if (hasFile) ...[
                  const SizedBox(height: AppSpacing.s6),
                  InkWell(
                    onTap: onOpenFile != null
                        ? () => onOpenFile!(content.file!.storagePath)
                        : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.attach_file_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${content.file!.fileName} (${content.file!.formattedFileSize})',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Video Upload Action Pill for Teacher
                if (isTeacher &&
                    content.type == ContentType.video &&
                    onUploadVideo != null) ...[
                  const SizedBox(height: AppSpacing.s8),
                  InkWell(
                    onTap: onUploadVideo,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                        border: Border.all(color: AppColors.primary.withAlpha(60)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_upload_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            context.l10n.uploadVideoAction,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.s8),

                // Footer Row: Clean Date on left, 3-dots Menu on right (No eye icon, no crushing)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        content.publishedAt != null
                            ? context.l10n.publishedDatePrefix(
                                _formatDate(content.publishedAt!),
                              )
                            : context.l10n.createdDatePrefix(
                                _formatDate(content.createdAt),
                              ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ),

                    // Actions: Only the 3-dots menu (Clean & uncluttered)
                    if (isTeacher)
                      PopupMenuButton<String>(
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
                                      const Icon(Icons.cloud_upload_rounded, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Text(
                                        ctx.l10n.uploadUpdateLectureVideo,
                                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
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
                                    Text(content.isPublished
                                        ? ctx.l10n.convertToDraft
                                        : ctx.l10n.publishToStudents),
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
                                    Text(content.isArchived
                                        ? ctx.l10n.unarchiveMaterial
                                        : ctx.l10n.archiveMaterial),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(Icons.delete_outline,
                                        size: 16, color: AppColors.error),
                                    const SizedBox(width: 8),
                                    Text(
                                      ctx.l10n.permanentDelete,
                                      style: const TextStyle(color: AppColors.error),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                    else if (hasFile)
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        tooltip: context.l10n.previewAndDownloadNote,
                        onPressed: onOpenFile != null
                            ? () => onOpenFile!(content.file!.storagePath)
                            : onTap,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
