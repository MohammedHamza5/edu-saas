import 'package:flutter/material.dart';
import '../../../../../core/extensions/localized_context_extension.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';

class WhatsAppEvaluationTiersSection extends StatelessWidget {
  final TextEditingController excellentController;
  final TextEditingController goodController;
  final TextEditingController passController;
  final TextEditingController needsImprovementController;
  final VoidCallback onChanged;

  const WhatsAppEvaluationTiersSection({
    super.key,
    required this.excellentController,
    required this.goodController,
    required this.passController,
    required this.needsImprovementController,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTierCard(
          title: l10n.whatsappStudioTierExcellentLabel,
          color: const Color(0xFF10B981), // Emerald
          controller: excellentController,
        ),
        const SizedBox(height: AppSpacing.s12),
        _buildTierCard(
          title: l10n.whatsappStudioTierGoodLabel,
          color: const Color(0xFF3B82F6), // Blue
          controller: goodController,
        ),
        const SizedBox(height: AppSpacing.s12),
        _buildTierCard(
          title: l10n.whatsappStudioTierPassLabel,
          color: const Color(0xFFF59E0B), // Amber
          controller: passController,
        ),
        const SizedBox(height: AppSpacing.s12),
        _buildTierCard(
          title: l10n.whatsappStudioTierNeedsImprovementLabel,
          color: const Color(0xFFEF4444), // Rose
          controller: needsImprovementController,
        ),
      ],
    );
  }

  Widget _buildTierCard({
    required String title,
    required Color color,
    required TextEditingController controller,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          TextField(
            controller: controller,
            maxLines: 2,
            minLines: 1,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                borderSide: BorderSide(color: color, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s10,
                vertical: AppSpacing.s8,
              ),
            ),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}
