import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/video_folder_entity.dart';
import '../utils/folder_color_palette.dart';

class VideoBankFolderCard extends StatefulWidget {
  final VideoFolderEntity folder;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback? onAssignAsChapter;
  final VoidCallback? onChangeColor;

  const VideoBankFolderCard({
    super.key,
    required this.folder,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    this.onAssignAsChapter,
    this.onChangeColor,
  });

  @override
  State<VideoBankFolderCard> createState() => _VideoBankFolderCardState();
}

class _VideoBankFolderCardState extends State<VideoBankFolderCard> {
  bool _isHovered = false;

  String _formatDuration(BuildContext context, int totalSecs) {
    final l10n = context.l10n;
    final hours = totalSecs ~/ 3600;
    final minutes = (totalSecs % 3600) ~/ 60;
    if (hours > 0) {
      return l10n.folderDurationBadge(hours, minutes);
    } else if (minutes > 0) {
      return l10n.folderDurationMinutesOnly(minutes);
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final f = widget.folder;
    final folderColor = FolderColorPalette.getFolderColor(f.color);
    final isCustomColor = f.color != null && f.color!.isNotEmpty;

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
                ? folderColor.withValues(alpha: 0.75)
                : isCustomColor
                    ? folderColor.withValues(alpha: 0.35)
                    : AppColors.border,
            width: _isHovered ? 1.5 : (isCustomColor ? 1.2 : 1),
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: folderColor.withValues(alpha: 0.15),
                    blurRadius: 12,
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Folder Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: folderColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: folderColor.withValues(alpha: 0.28),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.folder_rounded,
                    color: folderColor,
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
                      const SizedBox(height: 3),
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
                          if (f.totalDurationSeconds > 0) ...[
                            const Text(
                              ' • ',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                            Flexible(
                              child: Text(
                                _formatDuration(context, f.totalDurationSeconds),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.primaryLight,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Badges: Course Assignment + Readiness
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // Course Assignment Badge
                          if (f.isAssigned)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.school_rounded,
                                    size: 11,
                                    color: AppColors.primaryLight,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      l10n.folderAssignedToCourse(
                                        f.primaryAssignedGroupName ?? '',
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.primaryLight,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                l10n.folderNotAssignedYet,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),

                          // Readiness indicator (only if folder has videos)
                          if (f.hasVideos) ...[
                            if (f.allVideosReady)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 10,
                                      color: AppColors.success,
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        l10n.folderAllVideosReady,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (f.hasPendingVideos)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.sync_rounded,
                                      size: 10,
                                      color: AppColors.warning,
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        l10n.folderVideosProcessing(
                                          f.videoCount - f.readyVideoCount,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.warning,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
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
                    if (val == 'change_color') widget.onChangeColor?.call();
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
                    if (widget.onChangeColor != null)
                      PopupMenuItem(
                        value: 'change_color',
                        child: Row(
                          children: [
                            Icon(
                              Icons.palette_rounded,
                              size: 16,
                              color: folderColor,
                            ),
                            const SizedBox(width: 8),
                            Text(l10n.changeFolderColor),
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
