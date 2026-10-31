import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Reordering controls for Teacher in ContentItemCard (drag handle, up/down arrows).
class ContentItemCardReorderControls extends StatelessWidget {
  final int index;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const ContentItemCardReorderControls({
    super.key,
    required this.index,
    required this.canMoveUp,
    required this.canMoveDown,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsetsDirectional.only(
              end: AppSpacing.s4,
              top: 4,
              bottom: 2,
            ),
            child: Icon(
              Icons.drag_indicator_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ),
        ),
        if (canMoveUp || canMoveDown) ...[
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 22,
            ),
            visualDensity: VisualDensity.compact,
            tooltip: context.l10n.moveUpAction,
            onPressed: canMoveUp ? onMoveUp : null,
          ),
          IconButton(
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 22,
            ),
            visualDensity: VisualDensity.compact,
            tooltip: context.l10n.moveDownAction,
            onPressed: canMoveDown ? onMoveDown : null,
          ),
        ],
      ],
    );
  }
}
