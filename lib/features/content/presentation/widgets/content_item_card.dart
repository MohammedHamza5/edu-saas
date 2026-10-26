import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/content_entity.dart';
import 'content_item_card_helpers.dart';

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
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final bool canMoveUp;
  final bool canMoveDown;

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
    this.onMoveUp,
    this.onMoveDown,
    this.canMoveUp = false,
    this.canMoveDown = false,
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
      ContentType.pdf => const Color(
        0xFFEA580C,
      ), // Deep Orange / Academic Math Red
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
    final hasFile = content.type != ContentType.video && content.file != null;

    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s16),
      onTap:
          onTap ??
          (hasFile && onOpenFile != null
              ? () => onOpenFile!(content.file!.storagePath)
              : null),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reordering controls for Teacher
          if (isTeacher && index != null) ...[
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ReorderableDragStartListener(
                  index: index!,
                  child: const Padding(
                    padding: EdgeInsetsDirectional.only(
                      end: AppSpacing.s4,
                      top: 4,
                      bottom: 2,
                    ),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ),
                if (canMoveUp || canMoveDown) ...[
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 22,
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: context.l10n.moveUpAction,
                    onPressed: canMoveUp ? onMoveUp : null,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 22,
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: context.l10n.moveDownAction,
                    onPressed: canMoveDown ? onMoveDown : null,
                  ),
                ],
              ],
            ),
          ],

          // Type Icon Avatar with sequential lecture number badge
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: (!isTeacher && content.isLocked)
                      ? AppColors.error.withValues(alpha: 0.12)
                      : _typeColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  border: Border.all(
                    color: (!isTeacher && content.isLocked)
                        ? AppColors.error.withValues(alpha: 0.4)
                        : _typeColor.withAlpha(60),
                  ),
                ),
                child: Icon(
                  (!isTeacher && content.isLocked)
                      ? Icons.lock_rounded
                      : _typeIcon,
                  color: (!isTeacher && content.isLocked)
                      ? AppColors.error
                      : _typeColor,
                  size: 24,
                ),
              ),
              if (index != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.primary.withAlpha(40)),
                  ),
                  child: Text(
                    '#${(index! + 1).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
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
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: (!isTeacher && content.isLocked)
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
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
                    if (index != null)
                      AppBadge(
                        label: context.l10n.lectureNumberBadge(index! + 1),
                        variant: AppBadgeVariant.neutral,
                      ),
                    AppBadge(
                      label: content.type.localizedLabel(context),
                      variant: AppBadgeVariant.neutral,
                    ),
                    if (!isTeacher && content.isCompleted)
                      AppBadge(
                        label: context.l10n.completedBadge,
                        variant: AppBadgeVariant.active,
                      ),
                    if (!isTeacher && content.isLocked)
                      AppBadge(
                        label: context.l10n.lessonPrerequisiteLocked,
                        variant: AppBadgeVariant.suspended,
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

                // 3-Pillars Summary Row (Video ➔ PDF Handout ➔ Quiz)
                ContentPillarsRow(content: content),

                // Prerequisite Locked Notification Banner
                if (!isTeacher && content.isLocked) ...[
                  const SizedBox(height: AppSpacing.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_rounded,
                          size: 16,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.l10n.mustPassExamToUnlock(
                              content.prerequisiteExamTitle ??
                                  context.l10n.prerequisiteExamBadge,
                              content.prerequisitePassingScore ?? 60,
                            ),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (content.prerequisiteExamId != null)
                          TextButton(
                            onPressed: () =>
                                context.push(AppRoutes.studentExams),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              context.l10n.takeRequiredExamAction,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                // Associated Lesson Quiz Gating Banner
                if (content.attachedExams.isNotEmpty ||
                    content.associatedExamTitle != null) ...[
                  const SizedBox(height: AppSpacing.s8),
                  ContentAssociatedExamBanner(
                    content: content,
                    isTeacher: isTeacher,
                  ),
                ],

                // Student Action: Watch / Rewatch Lecture Button
                if (!isTeacher &&
                    !content.isLocked &&
                    (content.type == ContentType.video ||
                        content.hasVideo)) ...[
                  const SizedBox(height: AppSpacing.s8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onTap,
                      icon: Icon(
                        content.isVideoCompleted
                            ? Icons.replay_rounded
                            : Icons.play_arrow_rounded,
                        size: 16,
                      ),
                      label: Text(
                        content.isVideoCompleted
                            ? context.l10n.rewatchLectureAction
                            : context.l10n.startLectureAction,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],

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

                // Attachment File Link (if attached for document/image)
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

                // Supplementary PDF Material (for Video lessons)
                if (content.type == ContentType.video &&
                    content.file != null) ...[
                  const SizedBox(height: AppSpacing.s8),
                  InkWell(
                    onTap: onOpenFile != null
                        ? () => onOpenFile!(content.file!.storagePath)
                        : null,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(12),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSmall,
                        ),
                        border: Border.all(
                          color: AppColors.primary.withAlpha(40),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.picture_as_pdf_rounded,
                            size: 14,
                            color: Color(0xFFEA580C),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              '${context.l10n.videoMaterialPdfBadge}: ${content.file!.fileName} (${content.file!.formattedFileSize})',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (onOpenFile != null) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.open_in_new_rounded,
                              size: 12,
                              color: AppColors.primary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],

                // Video Status / Upload Action for Teacher
                if (isTeacher && content.type == ContentType.video) ...[
                  const SizedBox(height: AppSpacing.s8),
                  // Case A: video already uploaded → show status badge
                  if (content.hasVideo)
                    ContentVideoStatusBadge(
                      status: content.videoStatus ?? 'uploading',
                      onReplace: onUploadVideo,
                    )
                  // Case B: no video yet → show upload button
                  else if (onUploadVideo != null)
                    InkWell(
                      onTap: onUploadVideo,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSmall,
                          ),
                          border: Border.all(
                            color: AppColors.primary.withAlpha(60),
                          ),
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
                          if (content.type == ContentType.video &&
                              onUploadVideo != null)
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
                                  style: const TextStyle(
                                    color: AppColors.error,
                                  ),
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
