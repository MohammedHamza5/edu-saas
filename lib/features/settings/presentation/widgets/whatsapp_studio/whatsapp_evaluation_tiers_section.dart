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
          badge: '≥ 90%',
          icon: Icons.star_rounded,
          color: const Color(0xFF10B981), // Emerald
          controller: excellentController,
        ),
        const SizedBox(height: AppSpacing.s16),
        _buildTierCard(
          title: l10n.whatsappStudioTierGoodLabel,
          badge: '75% - 89%',
          icon: Icons.thumb_up_alt_rounded,
          color: const Color(0xFF3B82F6), // Blue
          controller: goodController,
        ),
        const SizedBox(height: AppSpacing.s16),
        _buildTierCard(
          title: l10n.whatsappStudioTierPassLabel,
          badge: '60% - 74%',
          icon: Icons.check_circle_outline_rounded,
          color: const Color(0xFFF59E0B), // Amber
          controller: passController,
        ),
        const SizedBox(height: AppSpacing.s16),
        _buildTierCard(
          title: l10n.whatsappStudioTierNeedsImprovementLabel,
          badge: '< 60%',
          icon: Icons.lightbulb_outline_rounded,
          color: const Color(0xFFEF4444), // Rose
          controller: needsImprovementController,
        ),
      ],
    );
  }

  Widget _buildTierCard({
    required String title,
    required String badge,
    required IconData icon,
    required Color color,
    required TextEditingController controller,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s10,
                  vertical: AppSpacing.s4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: controller,
            maxLines: 4,
            minLines: 2,
            cursorColor: color,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceVariant.withValues(alpha: 0.35),
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
                borderSide: BorderSide(color: color, width: 1.8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s14,
                vertical: AppSpacing.s12,
              ),
            ),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}
