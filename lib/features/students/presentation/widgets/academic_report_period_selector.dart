import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class AcademicReportPeriodSelector extends StatelessWidget {
  final int? selectedPeriodDays;
  final ValueChanged<int?> onPeriodSelected;

  const AcademicReportPeriodSelector({
    super.key,
    required this.selectedPeriodDays,
    required this.onPeriodSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final periods = [
      (
        days: 7,
        label: l10n.whatsappPeriod7Days,
        icon: Icons.flash_on_rounded,
      ),
      (
        days: 14,
        label: l10n.whatsappPeriod14Days,
        icon: Icons.timer_outlined,
      ),
      (
        days: 30,
        label: l10n.whatsappPeriod30Days,
        icon: Icons.calendar_month_rounded,
      ),
      (
        days: null,
        label: l10n.whatsappPeriodAllTime,
        icon: Icons.all_inclusive_rounded,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.whatsappPeriodLabel,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.s6),
        Wrap(
          spacing: AppSpacing.s6,
          runSpacing: AppSpacing.s6,
          children: periods.map((p) {
            final isSelected = selectedPeriodDays == p.days;
            return ChoiceChip(
              avatar: Icon(
                p.icon,
                size: 14,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
              label: Text(
                p.label,
                style: const TextStyle(fontSize: 11),
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              onSelected: (selected) {
                if (selected) onPeriodSelected(p.days);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
