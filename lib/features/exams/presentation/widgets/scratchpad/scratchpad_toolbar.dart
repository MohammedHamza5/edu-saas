import 'package:flutter/material.dart';
import 'package:edu_saas/core/extensions/localized_context_extension.dart';
import 'package:edu_saas/core/theme/app_colors.dart';
import 'package:edu_saas/core/theme/app_spacing.dart';
import 'package:edu_saas/features/exams/domain/entities/scratchpad_entity.dart';

/// Floating tactical toolbar for the in-exam scratchpad.
class ScratchpadToolbar extends StatelessWidget {
  final DrawingTool activeTool;
  final Color activeColor;
  final bool isGridBackground;
  final bool canUndo;
  final ValueChanged<DrawingTool> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final VoidCallback onToggleBackground;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final VoidCallback onClose;

  const ScratchpadToolbar({
    super.key,
    required this.activeTool,
    required this.activeColor,
    required this.isGridBackground,
    required this.canUndo,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onToggleBackground,
    required this.onUndo,
    required this.onClear,
    required this.onClose,
  });

  static const _palette = [
    Color(0xFF1E293B), // Slate / Black
    Color(0xFF2563EB), // Math Blue
    Color(0xFFDC2626), // Focus Red
    Color(0xFF16A34A), // Success Green
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          // Pen tool
          _buildToolBtn(
            icon: Icons.edit_outlined,
            tool: DrawingTool.pen,
            tooltip: l10n.scratchpadPen,
          ),
          // Highlighter tool
          _buildToolBtn(
            icon: Icons.brush_outlined,
            tool: DrawingTool.highlighter,
            tooltip: l10n.scratchpadHighlighter,
          ),
          // Eraser tool
          _buildToolBtn(
            icon: Icons.auto_fix_normal_outlined,
            tool: DrawingTool.eraser,
            tooltip: l10n.scratchpadEraser,
          ),

          const SizedBox(width: 4),
          // Color dots (hidden when eraser is active)
          if (activeTool != DrawingTool.eraser)
            ..._palette.map((c) {
              final isSelected = activeColor == c;
              return InkWell(
                onTap: () => onColorChanged(c),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.white,
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                ),
              );
            }),

          const SizedBox(width: 4),
          // Toggle grid/transparent paper
          IconButton(
            onPressed: onToggleBackground,
            icon: Icon(
              isGridBackground ? Icons.grid_on_rounded : Icons.layers_clear_outlined,
              size: 20,
              color: isGridBackground ? AppColors.primary : AppColors.textSecondary,
            ),
            tooltip: isGridBackground ? l10n.scratchpadGridPaper : l10n.scratchpadOverlay,
            visualDensity: VisualDensity.compact,
          ),

          // Undo
          IconButton(
            onPressed: canUndo ? onUndo : null,
            icon: const Icon(Icons.undo_rounded, size: 20),
            tooltip: l10n.scratchpadUndo,
            visualDensity: VisualDensity.compact,
          ),

          // Clear
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            tooltip: l10n.scratchpadClear,
            visualDensity: VisualDensity.compact,
          ),

          // Close
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: l10n.scratchpadClose,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildToolBtn({
    required IconData icon,
    required DrawingTool tool,
    required String tooltip,
  }) {
    final isSelected = activeTool == tool;
    return InkWell(
      onTap: () => onToolChanged(tool),
      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }
}
