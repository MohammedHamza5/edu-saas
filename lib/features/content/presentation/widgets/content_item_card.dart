import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/content_entity.dart';
import 'content_item_card_attachments_view.dart';
import 'content_item_card_helpers.dart';
import 'content_item_card_locked_banner.dart';
import 'content_item_card_menu.dart';
import 'content_item_card_reorder_controls.dart';

/// Card widget displaying a single learning material / content item.
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
      ContentType.pdf => const Color(0xFFEA580C),
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
      onTap: onTap ??
          (hasFile && onOpenFile != null
              ? () => onOpenFile!(content.file!.storagePath)
              : null),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reordering controls for Teacher
          if (isTeacher && index != null) ...[
            ContentItemCardReorderControls(
              index: index!,
              canMoveUp: canMoveUp,
              canMoveDown: canMoveDown,
              onMoveUp: onMoveUp,
              onMoveDown: onMoveDown,
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
                  ContentItemCardLockedBanner(content: content),
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

                // File Attachments / Supplementary PDF / Video Status View
                ContentItemCardAttachmentsView(
                  content: content,
                  isTeacher: isTeacher,
                  hasFile: hasFile,
                  onOpenFile: onOpenFile,
                  onUploadVideo: onUploadVideo,
                ),

                const SizedBox(height: AppSpacing.s8),

                // Footer Row: Clean Date on left, 3-dots Menu or Preview on right
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

                    // Actions: Only the 3-dots menu for Teacher, or Preview for Student
                    if (isTeacher)
                      ContentItemCardMenu(
                        content: content,
                        hasFile: hasFile,
                        onUploadVideo: onUploadVideo,
                        onEdit: onEdit,
                        onTogglePublish: onTogglePublish,
                        onToggleArchive: onToggleArchive,
                        onOpenFile: onOpenFile,
                        onDelete: onDelete,
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
