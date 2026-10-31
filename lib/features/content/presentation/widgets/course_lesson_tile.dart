import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/content_entity.dart';
import 'course_lesson_action_buttons.dart';
import 'course_lesson_chips_wrap.dart';

/// Teacher-side draggable lesson row inside the Course Builder.
///
/// Shows:
///   - Drag handle (reorder grip)
///   - Lesson number badge
///   - Lesson title (with video name underneath)
///   - Study-material chip (PDF)
///   - Quiz chip (Lesson Quiz)
///   - Actions: Edit | Delete
///
/// No student-progress states — pure teacher authoring view.
class CourseLessonTile extends StatefulWidget {
  final ContentEntity content;
  final int index;

  /// Title override per-course (can differ from video title)
  final String? lessonTitle;

  /// Whether a PDF handout is attached
  final bool hasPdf;

  /// The lesson quiz name (if any)
  final String? quizTitle;

  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleVisibility;
  final VoidCallback? onViewAnalytics;
  final VoidCallback? onOpenFullPage;
  final VoidCallback? onMoveToChapter;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const CourseLessonTile({
    super.key,
    required this.content,
    required this.index,
    this.isSelected = false,
    this.onTap,
    this.lessonTitle,
    this.hasPdf = false,
    this.quizTitle,
    this.onEdit,
    this.onDelete,
    this.onToggleVisibility,
    this.onViewAnalytics,
    this.onOpenFullPage,
    this.onMoveToChapter,
    this.canMoveUp = false,
    this.canMoveDown = false,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  State<CourseLessonTile> createState() => _CourseLessonTileState();
}

class _CourseLessonTileState extends State<CourseLessonTile> {
  bool _isHovered = false;

  String get _displayTitle => widget.lessonTitle?.isNotEmpty == true
      ? widget.lessonTitle!
      : widget.content.title;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isSelected = widget.isSelected;
    final isCompact = MediaQuery.sizeOf(context).width < 360;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: AppSpacing.s8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : _isHovered
              ? AppColors.surfaceVariant.withValues(alpha: 0.5)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : _isHovered
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.border,
            width: isSelected ? 2.0 : (_isHovered ? 1.5 : 1.0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : _isHovered
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: widget.quizTitle != null 
              ? AppColors.success.withValues(alpha: 0.03) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          child: InkWell(
            onTap: widget.onTap ?? widget.onEdit,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 8 : AppSpacing.s12,
                vertical: AppSpacing.s10,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Drag Handle with proper ReorderableDragStartListener, grab cursor, and hit-testing
                  Tooltip(
                    message: l10n.dragToReorder,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: ReorderableDragStartListener(
                        index: widget.index,
                        child: Container(
                          color: Colors.transparent,
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 3 : AppSpacing.s6,
                            vertical: AppSpacing.s8,
                          ),
                          child: const Icon(
                            Icons.drag_indicator_rounded,
                            color: AppColors.textMuted,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Move Up / Down Buttons
                  if (widget.onMoveUp != null || widget.onMoveDown != null) ...[
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: l10n.moveUp,
                          child: InkWell(
                            onTap: widget.canMoveUp ? widget.onMoveUp : null,
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                Icons.keyboard_arrow_up_rounded,
                                size: 16,
                                color: widget.canMoveUp
                                    ? AppColors.textSecondary
                                    : AppColors.textMuted.withValues(
                                        alpha: 0.25,
                                      ),
                              ),
                            ),
                          ),
                        ),
                        Tooltip(
                          message: l10n.moveDown,
                          child: InkWell(
                            onTap: widget.canMoveDown
                                ? widget.onMoveDown
                                : null,
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: widget.canMoveDown
                                    ? AppColors.textSecondary
                                    : AppColors.textMuted.withValues(
                                        alpha: 0.25,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: isCompact ? 4 : AppSpacing.s6),
                  ] else ...[
                    SizedBox(width: isCompact ? 4 : AppSpacing.s6),
                  ],

                  // Lesson Number Badge
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: widget.quizTitle != null
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: widget.quizTitle != null
                            ? AppColors.success.withValues(alpha: 0.3)
                            : AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: widget.quizTitle != null
                              ? AppColors.success
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isCompact ? 6 : AppSpacing.s12),

                  // Title + Metadata
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontSize: 14.5,
                            height: 1.3,
                          ),
                        ),
                        // Show original video title if lesson has an override
                        if (widget.lessonTitle != null &&
                            widget.lessonTitle!.isNotEmpty &&
                            widget.lessonTitle != widget.content.title) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.content.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.s6),
                        CourseLessonChipsWrap(
                          content: widget.content,
                          hasPdf: widget.hasPdf,
                          quizTitle: widget.quizTitle,
                        ),
                      ],
                    ),
                  ),

                  // Action Buttons (Visibility, Edit, Move, Analytics, Delete)
                  CourseLessonActionButtons(
                    content: widget.content,
                    isCompact: isCompact,
                    onToggleVisibility: widget.onToggleVisibility,
                    onViewAnalytics: widget.onViewAnalytics,
                    onEdit: widget.onEdit ?? widget.onTap,
                    onMoveToChapter: widget.onMoveToChapter,
                    onDelete: widget.onDelete,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
