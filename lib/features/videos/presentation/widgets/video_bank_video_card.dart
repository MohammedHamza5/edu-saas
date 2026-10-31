import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/library_video_entity.dart';
import 'video_card_thumbnail.dart';

class VideoBankVideoCard extends StatefulWidget {
  final LibraryVideoEntity video;
  final VoidCallback onPreview;
  final VoidCallback onAddToCourse;
  final VoidCallback onMove;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback? onSync;

  const VideoBankVideoCard({
    super.key,
    required this.video,
    required this.onPreview,
    required this.onAddToCourse,
    required this.onMove,
    required this.onRename,
    required this.onDelete,
    this.onSync,
  });

  @override
  State<VideoBankVideoCard> createState() => _VideoBankVideoCardState();
}

class _VideoBankVideoCardState extends State<VideoBankVideoCard> {
  bool _isHovered = false;

  LibraryVideoEntity get v => widget.video;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          border: Border.all(
            color: _isHovered
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.border,
            width: _isHovered ? 1.5 : 1,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  const BoxShadow(
                    color: AppColors.shadowSoft,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail & Overlays
            VideoCardThumbnail(
              video: v,
              isHovered: _isHovered,
              onPreview: widget.onPreview,
              onSync: widget.onSync,
            ),

            // Card Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Usage Badges
                    if (v.assignedGroupNames.isNotEmpty) ...[
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          ...v.assignedGroupNames.take(2).map(
                                (name) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                          if (v.assignedGroupNames.length > 2)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '+${v.assignedGroupNames.length - 2}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        l10n.notUsedInAnyCourse,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // Actions Row
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s8,
                vertical: 6,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: v.isReady ? widget.onAddToCourse : null,
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        size: 15,
                      ),
                      label: Text(
                        l10n.addToCourse,
                        style: const TextStyle(fontSize: 11),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.4),
                        ),
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Menu for Move, Rename, Delete
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    tooltip: '',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onSelected: (val) {
                      if (val == 'sync') widget.onSync?.call();
                      if (val == 'preview') widget.onPreview();
                      if (val == 'move') widget.onMove();
                      if (val == 'rename') widget.onRename();
                      if (val == 'delete') widget.onDelete();
                    },
                    itemBuilder: (ctx) => [
                      if (v.isProcessing && widget.onSync != null)
                        PopupMenuItem(
                          value: 'sync',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.sync_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.syncVideoStatus,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (v.isReady)
                        PopupMenuItem(
                          value: 'preview',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.play_arrow_outlined,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(l10n.previewVideo),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'move',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.drive_file_move_outlined,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(l10n.moveVideo),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined, size: 16),
                            const SizedBox(width: 8),
                            Text(l10n.renameVideo),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.deleteAction,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
