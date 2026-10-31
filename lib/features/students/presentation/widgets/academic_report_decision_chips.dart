import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class AcademicReportDecisionChips extends StatelessWidget {
  final ValueChanged<String> onDecisionSelected;

  const AcademicReportDecisionChips({
    super.key,
    required this.onDecisionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final decisions = [
      (
        label: l10n.whatsappChipConsistent,
        value: l10n.whatsappDecisionConsistent,
        icon: Icons.star_rounded,
        color: const Color(0xFFF59E0B),
      ),
      (
        label: l10n.whatsappChipImproving,
        value: l10n.whatsappDecisionImproving,
        icon: Icons.trending_up_rounded,
        color: AppColors.success,
      ),
      (
        label: l10n.whatsappChipNeedsDrills,
        value: l10n.whatsappDecisionNeedsDrills,
        icon: Icons.fact_check_outlined,
        color: AppColors.warning,
      ),
      (
        label: l10n.whatsappChipCatchUp,
        value: l10n.whatsappDecisionCatchUp,
        icon: Icons.hourglass_top_rounded,
        color: AppColors.info,
      ),
      (
        label: l10n.whatsappChipNeglect,
        value: l10n.whatsappDecisionNeglect,
        icon: Icons.notification_important_outlined,
        color: AppColors.error,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.whatsappDecisionsTitle,
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
          children: decisions.map((d) {
            return ActionChip(
              avatar: Icon(d.icon, size: 14, color: d.color),
              label: Text(d.label, style: const TextStyle(fontSize: 11)),
              onPressed: () => onDecisionSelected(d.value),
            );
          }).toList(),
        ),
      ],
    );
  }
}
