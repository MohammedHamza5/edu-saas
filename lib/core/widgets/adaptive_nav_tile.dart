import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'adaptive_nav_destination.dart';

/// Navigation tile rendered inside the Adaptive Scaffold sidebar or drawer.
class AdaptiveNavTile extends StatelessWidget {
  final AdaptiveDestination item;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isCollapsed;

  const AdaptiveNavTile({
    super.key,
    required this.item,
    required this.isSelected,
    this.onTap,
    this.isCollapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final fgColor = isSelected
        ? const Color(0xFF38BDF8)
        : const Color(0xFFCBD5E1);
    const textColor = Colors.white;
    const inactiveTextColor = Color(0xFFE2E8F0);

    Widget iconBox = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF38BDF8).withValues(alpha: 0.16)
            : const Color(0xFF1E293B).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF38BDF8).withValues(alpha: 0.45)
              : const Color(0xFF334155).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          isSelected ? (item.selectedIcon ?? item.icon) : item.icon,
          color: fgColor,
          size: 20,
        ),
      ),
    );

    if (item.badge != null) {
      iconBox = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          iconBox,
          PositionedDirectional(top: -4, end: -4, child: item.badge!),
        ],
      );
    } else if (item.badgeCount != null && item.badgeCount! > 0) {
      iconBox = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          iconBox,
          PositionedDirectional(
            top: -4,
            end: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66EF4444),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                '${item.badgeCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Center(
          child: Tooltip(
            message: item.label,
            preferBelow: false,
            waitDuration: const Duration(milliseconds: 200),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onTap,
                mouseCursor: SystemMouseCursors.click,
                borderRadius: BorderRadius.circular(10),
                hoverColor: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                child: iconBox,
              ),
            ),
          ),
        ),
      );
    }

    final bgColor = isSelected ? const Color(0xFF1E293B) : Colors.transparent;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        onHover: (hovered) {
          if (hovered) {
            item.onHover?.call();
          }
        },
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(10),
        hoverColor: const Color(0xFF1E293B).withValues(alpha: 0.5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s10,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
                    width: 1,
                  )
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              iconBox,
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? textColor : inactiveTextColor,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        fontSize: 14,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF7DD3FC)
                              : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (item.badge != null)
                item.badge!
              else if (item.badgeCount != null && item.badgeCount! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${item.badgeCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
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
