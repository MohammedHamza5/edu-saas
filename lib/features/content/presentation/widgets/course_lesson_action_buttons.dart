import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/content_entity.dart';

/// Renders the action buttons (visibility, edit, delete, analytics, move) for a course lesson.
class CourseLessonActionButtons extends StatelessWidget {
  final ContentEntity content;
  final bool isCompact;
  final VoidCallback? onToggleVisibility;
  final VoidCallback? onViewAnalytics;
  final VoidCallback? onEdit;
  final VoidCallback? onMoveToChapter;
  final VoidCallback? onDelete;

  const CourseLessonActionButtons({
    super.key,
    required this.content,
    required this.isCompact,
    this.onToggleVisibility,
    this.onViewAnalytics,
    this.onEdit,
    this.onMoveToChapter,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onToggleVisibility != null) ...[
          _ActionButton(
            icon: content.isPublished
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
            color: content.isPublished ? AppColors.success : AppColors.warning,
            tooltip: content.isPublished
                ? l10n.hideLessonTooltip
                : l10n.publishLessonTooltip,
            onTap: onToggleVisibility,
            isCompact: isCompact,
          ),
          SizedBox(width: isCompact ? 4 : AppSpacing.s6),
        ],
        if (!isCompact && onViewAnalytics != null) ...[
          _ActionButton(
            icon: Icons.insights_rounded,
            color: const Color(0xFF0284C7),
            tooltip: l10n.lessonAnalytics,
            onTap: onViewAnalytics,
            isCompact: isCompact,
          ),
          SizedBox(width: isCompact ? 4 : AppSpacing.s6),
        ],
        _ActionButton(
          icon: Icons.edit_rounded,
          color: AppColors.primary,
          tooltip: l10n.editLesson,
          onTap: onEdit,
          isCompact: isCompact,
        ),
        if (!isCompact && onMoveToChapter != null) ...[
          SizedBox(width: isCompact ? 4 : AppSpacing.s6),
          _ActionButton(
            icon: Icons.drive_file_move_outlined,
            color: const Color(0xFF6366F1),
            tooltip: l10n.moveLectureToChapter,
            onTap: onMoveToChapter,
            isCompact: isCompact,
          ),
        ],
        if (!isCompact && onDelete != null) ...[
          SizedBox(width: isCompact ? 4 : AppSpacing.s6),
          _ActionButton(
            icon: Icons.delete_outline_rounded,
            color: AppColors.error,
            tooltip: l10n.deleteLesson,
            onTap: onDelete,
            isCompact: isCompact,
          ),
        ],
        if (isCompact) ...[
          SizedBox(width: isCompact ? 2 : AppSpacing.s6),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
            padding: EdgeInsets.zero,
            itemBuilder: (context) => [
              if (onViewAnalytics != null)
                PopupMenuItem(
                  value: 'analytics',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.insights_rounded,
                        size: 16,
                        color: Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 8),
                      Text(l10n.lessonAnalytics),
                    ],
                  ),
                ),
              if (onMoveToChapter != null)
                PopupMenuItem(
                  value: 'move',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.drive_file_move_outlined,
                        size: 16,
                        color: Color(0xFF6366F1),
                      ),
                      const SizedBox(width: 8),
                      Text(l10n.moveLectureToChapter),
                    ],
                  ),
                ),
              if (onDelete != null)
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
                      Text(l10n.deleteLesson),
                    ],
                  ),
                ),
            ],
            onSelected: (val) {
              if (val == 'analytics') {
                onViewAnalytics?.call();
              } else if (val == 'move') {
                onMoveToChapter?.call();
              } else if (val == 'delete') {
                onDelete?.call();
              }
            },
          ),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;
  final bool isCompact;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: color.withValues(alpha: 0.20),
          child: Container(
            padding: EdgeInsets.all(isCompact ? 5.5 : 7.5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withValues(alpha: 0.30),
                width: 1,
              ),
            ),
            child: Icon(icon, size: isCompact ? 14 : 16, color: color),
          ),
        ),
      ),
    );
  }
}
