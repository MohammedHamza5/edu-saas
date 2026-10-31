import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import 'desmos_embed_view.dart';

/// Title bar for the floating Desmos calculator with drag gestures, mode switcher, and window controls.
class DesmosCalculatorTitleBar extends StatelessWidget {
  final DesmosCalculatorMode mode;
  final bool isMinimized;
  final bool isMaximized;
  final bool isCompact;
  final VoidCallback onClose;
  final VoidCallback? onDock;
  final VoidCallback onToggleMinimize;
  final VoidCallback onToggleMaximize;
  final ValueChanged<DesmosCalculatorMode> onModeChanged;
  final GestureTapCallback? onDoubleTap;
  final GestureDragStartCallback? onPanStart;
  final GestureDragUpdateCallback? onPanUpdate;
  final GestureDragEndCallback? onPanEnd;
  final GestureDragCancelCallback? onPanCancel;

  const DesmosCalculatorTitleBar({
    super.key,
    required this.mode,
    required this.isMinimized,
    required this.isMaximized,
    required this.isCompact,
    required this.onClose,
    this.onDock,
    required this.onToggleMinimize,
    required this.onToggleMaximize,
    required this.onModeChanged,
    this.onDoubleTap,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
    this.onPanCancel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        border: Border(
          bottom: BorderSide(
            color: Color(0x33000000),
          ),
        ),
      ),
      child: Row(
        children: [
          // Draggable Handle & Title (Double tap maximizes/restores)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: onDoubleTap,
              onPanStart: onPanStart,
              onPanUpdate: onPanUpdate,
              onPanEnd: onPanEnd,
              onPanCancel: onPanCancel,
              child: Row(
                children: [
                  Tooltip(
                    message: l10n.desmosDragHandleTooltip,
                    child: const Icon(
                      Icons.drag_indicator_rounded,
                      color: Colors.white70,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mode == DesmosCalculatorMode.graphing
                          ? l10n.desmosGraphingCalculator
                          : l10n.desmosScientificCalculator,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Action Buttons (Direct touch, no gesture conflicts)
          if (!isMinimized) ...[
            if (!isCompact)
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModeButton(
                      title: l10n.desmosModeGraphing,
                      isSelected: mode == DesmosCalculatorMode.graphing,
                      onTap: () {
                        if (mode != DesmosCalculatorMode.graphing) {
                          onModeChanged(DesmosCalculatorMode.graphing);
                        }
                      },
                    ),
                    _buildModeButton(
                      title: l10n.desmosModeScientific,
                      isSelected: mode == DesmosCalculatorMode.scientific,
                      onTap: () {
                        if (mode != DesmosCalculatorMode.scientific) {
                          onModeChanged(DesmosCalculatorMode.scientific);
                        }
                      },
                    ),
                  ],
                ),
              )
            else
              IconButton(
                icon: const Icon(
                  Icons.swap_horiz_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                tooltip: mode == DesmosCalculatorMode.graphing
                    ? l10n.desmosModeScientific
                    : l10n.desmosModeGraphing,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
                onPressed: () {
                  onModeChanged(
                    mode == DesmosCalculatorMode.graphing
                        ? DesmosCalculatorMode.scientific
                        : DesmosCalculatorMode.graphing,
                  );
                },
              ),
            const SizedBox(width: 4),
          ],

          // Re-dock to Side Pane (if onDock callback provided)
          if (onDock != null)
            IconButton(
              icon: const Icon(
                Icons.vertical_split_rounded,
                color: Colors.white,
                size: 18,
              ),
              tooltip: l10n.dockCalculatorTooltip,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 28,
                minHeight: 28,
              ),
              onPressed: onDock,
            ),

          // Maximize / Restore Toggle
          if (!isMinimized)
            IconButton(
              icon: Icon(
                isMaximized
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                color: Colors.white,
                size: 20,
              ),
              tooltip: isMaximized
                  ? l10n.desmosRestoreTooltip
                  : l10n.desmosMaximizeTooltip,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 30,
                minHeight: 30,
              ),
              onPressed: onToggleMaximize,
            ),

          // Minimize / Expand Toggle
          IconButton(
            icon: Icon(
              isMinimized
                  ? Icons.unfold_more_rounded
                  : Icons.unfold_less_rounded,
              color: Colors.white,
              size: 19,
            ),
            tooltip: isMinimized
                ? l10n.desmosExpandTooltip
                : l10n.desmosMinimizeTooltip,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 30,
              minHeight: 30,
            ),
            onPressed: onToggleMinimize,
          ),

          // Close Button
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 19,
            ),
            tooltip: l10n.desmosCloseTooltip,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 30,
              minHeight: 30,
            ),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.primary : Colors.white70,
          ),
        ),
      ),
    );
  }
}
