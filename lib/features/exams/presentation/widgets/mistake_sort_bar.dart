import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../cubit/mistakes_state.dart';

/// Clean horizontal sorting bar for ordering student mistakes.
class MistakeSortBar extends StatelessWidget {
  final MistakeSortOrder activeSort;
  final ValueChanged<MistakeSortOrder> onSortChanged;

  const MistakeSortBar({
    super.key,
    required this.activeSort,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final sortOptions = [
      (order: MistakeSortOrder.defaultOrder, label: l10n.sortDefault, icon: Icons.sort_rounded),
      (order: MistakeSortOrder.mostFailed, label: l10n.sortMostFailed, icon: Icons.warning_amber_rounded),
      (order: MistakeSortOrder.newest, label: l10n.sortNewest, icon: Icons.schedule_rounded),
      (order: MistakeSortOrder.points, label: l10n.sortPoints, icon: Icons.star_outline_rounded),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: sortOptions.map((opt) {
          final isSelected = activeSort == opt.order;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s8),
            child: FilterChip(
              avatar: Icon(
                opt.icon,
                size: 14,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              label: Text(opt.label),
              selected: isSelected,
              onSelected: (_) => onSortChanged(opt.order),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
              backgroundColor: AppColors.surfaceVariant.withValues(alpha: 0.35),
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: 1,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            ),
          );
        }).toList(),
      ),
    );
  }
}
