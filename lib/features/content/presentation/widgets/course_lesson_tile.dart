import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/content_entity.dart';

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

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CourseLessonTile({
    super.key,
    required this.content,
    required this.index,
    this.lessonTitle,
    this.hasPdf = false,
    this.quizTitle,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<CourseLessonTile> createState() => _CourseLessonTileState();
}

class _CourseLessonTileState extends State<CourseLessonTile> {
  bool _isHovered = false;

  String get _displayTitle =>
      widget.lessonTitle?.isNotEmpty == true
          ? widget.lessonTitle!
          : widget.content.title;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: AppSpacing.s8),
        decoration: BoxDecoration(
          color: _isHovered
              ? AppColors.surfaceVariant.withValues(alpha: 0.5)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          border: Border.all(
            color: _isHovered
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.border,
            width: _isHovered ? 1.5 : 1,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Drag Handle
              const Icon(
                Icons.drag_indicator_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.s8),

              // Lesson Number Badge
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Center(
                  child: Text(
                    '${widget.index}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),

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
                    const SizedBox(height: AppSpacing.s4),
                    // Chips row
                    Wrap(
                      spacing: AppSpacing.s6,
                      runSpacing: AppSpacing.s4,
                      children: [
                        // Video type chip
                        _buildMiniChip(
                          icon: Icons.play_circle_outline_rounded,
                          label: l10n.contentTypeVideo,
                          color: AppColors.primary,
                        ),

                        // PDF chip
                        if (widget.hasPdf)
                          _buildMiniChip(
                            icon: Icons.picture_as_pdf_rounded,
                            label: l10n.hasStudyMaterial,
                            color: const Color(0xFFEA580C),
                          ),

                        // Quiz chip
                        if (widget.quizTitle != null)
                          _buildMiniChip(
                            icon: Icons.quiz_rounded,
                            label: l10n.hasLessonQuiz,
                            color: AppColors.success,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Buttons (visible on hover or always on mobile)
              if (_isHovered || _isMobile) ...[
                const SizedBox(width: AppSpacing.s4),
                _buildActionButton(
                  icon: Icons.edit_rounded,
                  color: AppColors.primary,
                  tooltip: l10n.editLesson,
                  onTap: widget.onEdit,
                ),
                const SizedBox(width: AppSpacing.s4),
                _buildActionButton(
                  icon: Icons.delete_outline_rounded,
                  color: AppColors.error,
                  tooltip: l10n.deleteLesson,
                  onTap: widget.onDelete,
                ),
              ] else ...[
                // Placeholder width to prevent layout jumps
                const SizedBox(width: 76),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool get _isMobile {
    try {
      return MediaQuery.of(context).size.width < 600;
    } catch (_) {
      return false;
    }
  }

  Widget _buildMiniChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
