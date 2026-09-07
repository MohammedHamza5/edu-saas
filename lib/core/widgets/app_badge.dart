import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/math_tokens.dart';

enum AppBadgeVariant { active, pending, suspended, neutral }

class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeVariant variant;
  final IconData? icon;

  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MathTokens>() ?? MathTokens.light;

    final (backgroundColor, foregroundColor) = switch (variant) {
      AppBadgeVariant.active => (tokens.badgeActiveBackground, tokens.badgeActiveForeground),
      AppBadgeVariant.pending => (tokens.badgePendingBackground, tokens.badgePendingForeground),
      AppBadgeVariant.suspended => (tokens.badgeSuspendedBackground, tokens.badgeSuspendedForeground),
      AppBadgeVariant.neutral => (const Color(0xFFF1F5F9), const Color(0xFF475569)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foregroundColor),
            const SizedBox(width: AppSpacing.s4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: foregroundColor,
            ),
          ),
        ],
      ),
    );
  }
}
