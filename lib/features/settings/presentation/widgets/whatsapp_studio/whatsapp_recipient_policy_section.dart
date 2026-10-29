import 'package:flutter/material.dart';
import '../../../../../core/extensions/localized_context_extension.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../domain/entities/whatsapp_dispatch_config_entity.dart';

class WhatsAppRecipientPolicySection extends StatelessWidget {
  final WhatsAppRecipientTarget recipientTarget;
  final WhatsAppDispatchTiming dispatchTiming;
  final ValueChanged<WhatsAppRecipientTarget> onTargetChanged;
  final ValueChanged<WhatsAppDispatchTiming> onTimingChanged;

  const WhatsAppRecipientPolicySection({
    super.key,
    required this.recipientTarget,
    required this.dispatchTiming,
    required this.onTargetChanged,
    required this.onTimingChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section 1: Recipient Target
          Row(
            children: [
              const Icon(
                Icons.people_alt_outlined,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                l10n.whatsappStudioRecipientTargetLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),

          _buildSelectableCard(
            title: l10n.whatsappStudioRecipientParentOnly,
            subtitle: l10n.whatsappStudioRecipientParentOnlyDesc,
            icon: Icons.family_restroom_rounded,
            isSelected: recipientTarget == WhatsAppRecipientTarget.parentOnly,
            onTap: () => onTargetChanged(WhatsAppRecipientTarget.parentOnly),
            badge: 'الموصى به أكاديمياً',
          ),
          const SizedBox(height: AppSpacing.s8),

          _buildSelectableCard(
            title: l10n.whatsappStudioRecipientBoth,
            subtitle: l10n.whatsappStudioRecipientBothDesc,
            icon: Icons.groups_rounded,
            isSelected: recipientTarget == WhatsAppRecipientTarget.both,
            onTap: () => onTargetChanged(WhatsAppRecipientTarget.both),
          ),
          const SizedBox(height: AppSpacing.s8),

          _buildSelectableCard(
            title: l10n.whatsappStudioRecipientStudentOnly,
            subtitle: l10n.whatsappStudioRecipientStudentOnlyDesc,
            icon: Icons.person_outline_rounded,
            isSelected: recipientTarget == WhatsAppRecipientTarget.studentOnly,
            onTap: () => onTargetChanged(WhatsAppRecipientTarget.studentOnly),
          ),

          const SizedBox(height: AppSpacing.s24),

          // Section 2: Dispatch Timing
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                l10n.whatsappStudioDispatchTimingLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),

          _buildSelectableCard(
            title: l10n.whatsappStudioDispatchTimingInstant,
            subtitle: l10n.whatsappStudioDispatchTimingInstantDesc,
            icon: Icons.bolt_rounded,
            isSelected: dispatchTiming == WhatsAppDispatchTiming.instant,
            onTap: () => onTimingChanged(WhatsAppDispatchTiming.instant),
            accentColor: const Color(0xFF10B981),
          ),
          const SizedBox(height: AppSpacing.s8),

          _buildSelectableCard(
            title: l10n.whatsappStudioDispatchTimingExamEnd,
            subtitle: l10n.whatsappStudioDispatchTimingExamEndDesc,
            icon: Icons.timer_outlined,
            isSelected: dispatchTiming == WhatsAppDispatchTiming.examEnd,
            onTap: () => onTimingChanged(WhatsAppDispatchTiming.examEnd),
            accentColor: const Color(0xFF3B82F6),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    String? badge,
    Color accentColor = AppColors.primary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(AppSpacing.s14),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          border: Border.all(
            color: isSelected ? accentColor : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s8),
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.12)
                    : AppColors.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              ),
              child: Icon(
                icon,
                size: 22,
                color: isSelected ? accentColor : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: isSelected
                                ? accentColor
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? accentColor : AppColors.border,
                  width: isSelected ? 6 : 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
