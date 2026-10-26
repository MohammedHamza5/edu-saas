import 'package:flutter/material.dart';
import '../../../../../core/extensions/localized_context_extension.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../desmos_embed_view.dart';
import 'exam_dock_desmos_tab.dart';
import 'exam_dock_formula_tab.dart';
import 'exam_dock_state.dart';

/// The official SAT Bluebook-style Utility Dock for the Exam Taking experience.
/// Anchors calculator and formulas side-by-side with questions to ensure ZERO visual overlap.
class ExamUtilityDock extends StatelessWidget {
  final ExamDockTab activeTab;
  final ValueChanged<ExamDockTab> onTabChanged;
  final DesmosCalculatorMode desmosMode;
  final ValueChanged<DesmosCalculatorMode> onDesmosModeChanged;
  final VoidCallback onCollapse;
  final VoidCallback onDetachToFloat;
  final bool isDetachSupported;
  final bool isFloating;
  final VoidCallback? onReDock;
  final VoidCallback? onToggleMaximize;
  final bool isMaximized;
  final GestureDragUpdateCallback? onDragUpdate;

  const ExamUtilityDock({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
    required this.desmosMode,
    required this.onDesmosModeChanged,
    required this.onCollapse,
    required this.onDetachToFloat,
    this.isDetachSupported = true,
    this.isFloating = false,
    this.onReDock,
    this.onToggleMaximize,
    this.isMaximized = false,
    this.onDragUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: isFloating ? BorderRadius.circular(12) : null,
        border: isFloating
            ? Border.all(color: AppColors.border, width: 1.2)
            : const Border(left: BorderSide(color: AppColors.border, width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isFloating ? 0.12 : 0.04),
            blurRadius: isFloating ? 16 : 10,
            offset: Offset(isFloating ? 0 : -2, isFloating ? 6 : 0),
          ),
        ],
      ),
      clipBehavior: isFloating ? Clip.antiAlias : Clip.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onPanUpdate: isFloating ? onDragUpdate : null,
            behavior: HitTestBehavior.opaque,
            child: _buildHeader(context),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Offstage(
                    offstage: !activeTab.isCalculator,
                    child: ExamDockDesmosTab(
                      mode: desmosMode,
                      onModeChanged: onDesmosModeChanged,
                      isVisible: activeTab.isCalculator,
                    ),
                  ),
                ),
                if (activeTab.isFormulas)
                  const Positioned.fill(child: ExamDockFormulaTab()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (isFloating) ...[
            const Icon(Icons.drag_indicator_rounded, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.s4),
          ],
          Expanded(
            child: Row(
              children: [
                _tabBtn(l10n.dockTabCalculator, Icons.calculate_outlined, activeTab.isCalculator,
                    () => onTabChanged(ExamDockTab.calculator)),
                const SizedBox(width: AppSpacing.s6),
                _tabBtn(l10n.dockTabFormulas, Icons.menu_book_rounded, activeTab.isFormulas,
                    () => onTabChanged(ExamDockTab.formulas)),
              ],
            ),
          ),
          if (isFloating) ...[
            if (onReDock != null)
              IconButton(
                icon: const Icon(Icons.vertical_split_rounded, size: 18),
                tooltip: l10n.dockCalculatorTooltip,
                visualDensity: VisualDensity.compact,
                onPressed: onReDock,
              ),
            if (onToggleMaximize != null)
              IconButton(
                icon: Icon(isMaximized ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: onToggleMaximize,
              ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: l10n.collapseToolsTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: onCollapse,
            ),
          ] else ...[
            if (isDetachSupported)
              IconButton(
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                tooltip: l10n.undockCalculatorTooltip,
                visualDensity: VisualDensity.compact,
                onPressed: onDetachToFloat,
              ),
            IconButton(
              icon: const Icon(Icons.close_fullscreen_rounded, size: 18),
              tooltip: l10n.collapseToolsTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: onCollapse,
            ),
          ],
        ],
      ),
    );
  }

  Widget _tabBtn(String title, IconData icon, bool selected, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: selected ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
