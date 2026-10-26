import 'package:flutter/material.dart';
import '../../../../../core/extensions/localized_context_extension.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../desmos_embed_view.dart';

/// Embedded Desmos Calculator pane designed for the SAT Utility Dock.
/// Maintains DOM persistence and allows instant switching between Graphing & Scientific modes.
class ExamDockDesmosTab extends StatelessWidget {
  final DesmosCalculatorMode mode;
  final ValueChanged<DesmosCalculatorMode> onModeChanged;
  final bool isVisible;

  const ExamDockDesmosTab({
    super.key,
    required this.mode,
    required this.onModeChanged,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      children: [
        // Mode Selector Bar (Graphing vs Scientific)
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s6,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Row(
            children: [
              _buildModeChip(
                context,
                title: l10n.desmosModeGraphing,
                icon: Icons.show_chart_rounded,
                isSelected: mode == DesmosCalculatorMode.graphing,
                onTap: () => onModeChanged(DesmosCalculatorMode.graphing),
              ),
              const SizedBox(width: AppSpacing.s8),
              _buildModeChip(
                context,
                title: l10n.desmosModeScientific,
                icon: Icons.calculate_outlined,
                isSelected: mode == DesmosCalculatorMode.scientific,
                onTap: () => onModeChanged(DesmosCalculatorMode.scientific),
              ),
            ],
          ),
        ),

        // Embed container with offstage visibility preserving Web DOM state
        Expanded(
          child: Offstage(
            offstage: !isVisible,
            child: Container(
              color: Colors.white,
              child: buildDesmosCalculatorEmbed(
                mode: mode,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeChip(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
