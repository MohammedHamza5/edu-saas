import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/library_video_entity.dart';
import '../../domain/entities/video_folder_entity.dart';

class VideoBankFolderCard extends StatefulWidget {
  final VideoFolderEntity folder;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback? onAssignAsChapter;

  const VideoBankFolderCard({
    super.key,
    required this.folder,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    this.onAssignAsChapter,
  });

  @override
  State<VideoBankFolderCard> createState() => _VideoBankFolderCardState();
}

class _VideoBankFolderCardState extends State<VideoBankFolderCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final f = widget.folder;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          border: Border.all(
            color: _isHovered
                ? Colors.amber.shade700.withValues(alpha: 0.5)
                : AppColors.border,
            width: _isHovered ? 1.5 : 1,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Colors.amber.shade700.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  const BoxShadow(
                    color: AppColors.shadowSoft,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
        ),
        child: InkWell(
          onTap: widget.onOpen,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Folder Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.folder_rounded,
                    color: Colors.amber.shade700,
                    size: 28,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        f.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              l10n.nVideos(f.videoCount),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (f.subfolderCount > 0) ...[
                            const Text(
                              ' • ',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                            Flexible(
                              child: Text(
                                l10n.nSubfolders(f.subfolderCount),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Menu
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  tooltip: '',
                  onSelected: (val) {
                    if (val == 'open') widget.onOpen();
                    if (val == 'assign_chapter') widget.onAssignAsChapter?.call();
                    if (val == 'rename') widget.onRename();
                    if (val == 'delete') widget.onDelete();
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          const Icon(Icons.folder_open_rounded, size: 16),
                          const SizedBox(width: 8),
                          Text(l10n.openFolder),
                        ],
                      ),
                    ),
                    if (widget.onAssignAsChapter != null)
                      PopupMenuItem(
                        value: 'assign_chapter',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_stories_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.assignFolderAsChapter,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 16),
                          const SizedBox(width: 8),
                          Text(l10n.renameFolder),
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
        ),
      ),
    );
  }
}

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
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (v.thumbnailUrl != null)
                    CachedNetworkImage(
                      imageUrl: v.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _thumbFallback(),
                    )
                  else
                    _thumbFallback(),

                  // Play Button overlay
                  if (v.isReady)
                    Positioned.fill(
                      child: Center(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: _isHovered ? 1.0 : 0.75,
                          child: InkWell(
                            onTap: widget.onPreview,
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Duration Badge
                  if (v.duration > 0)
                    PositionedDirectional(
                      bottom: 6,
                      end: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          v.formattedDuration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // Status Badge
                  PositionedDirectional(
                    top: 6,
                    start: 6,
                    child: _buildStatusBadge(context),
                  ),

                  // Provider Badge
                  PositionedDirectional(
                    top: 6,
                    end: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        v.isBunny
                            ? l10n.videoSourceBunny
                            : l10n.videoSourceYoutube,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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

  Widget _buildStatusBadge(BuildContext context) {
    final l10n = context.l10n;
    if (v.isReady) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.success,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          l10n.statusReady,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (v.isProcessing) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onSync,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.statusProcessing,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.onSync != null) ...[
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.refresh_rounded,
                    size: 10,
                    color: Colors.white,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        l10n.statusFailed,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _thumbFallback() {
    return Container(
      color: AppColors.surfaceVariant,
      child: const Center(
        child: Icon(
          Icons.videocam_rounded,
          size: 36,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
