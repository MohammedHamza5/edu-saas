import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Quick announcement template buttons allowing teachers to prefill frequent academic messages.
class AnnouncementQuickTemplatesBar extends StatelessWidget {
  final void Function(String title, String body) onApplyTemplate;

  const AnnouncementQuickTemplatesBar({
    super.key,
    required this.onApplyTemplate,
  });

  List<({String label, String title, String body})> _getTemplates(
    BuildContext context,
  ) {
    final l10n = context.l10n;
    return [
      (
        label: l10n.templateSessionReminderLabel,
        title: l10n.templateSessionReminderTitle,
        body: l10n.templateSessionReminderBody,
      ),
      (
        label: l10n.templateAssignmentReminderLabel,
        title: l10n.templateAssignmentReminderTitle,
        body: l10n.templateAssignmentReminderBody,
      ),
      (
        label: l10n.templateExamAlertLabel,
        title: l10n.templateExamAlertTitle,
        body: l10n.templateExamAlertBody,
      ),
      (
        label: l10n.templateExcellencePraiseLabel,
        title: l10n.templateExcellencePraiseTitle,
        body: l10n.templateExcellencePraiseBody,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final templates = _getTemplates(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.bolt_rounded,
              size: 16,
              color: AppColors.warning,
            ),
            const SizedBox(width: AppSpacing.s4),
            Text(
              l10n.quickTemplatesTitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: templates.map((tpl) {
            return ActionChip(
              avatar: const Icon(
                Icons.touch_app_rounded,
                size: 14,
                color: AppColors.primary,
              ),
              label: Text(
                tpl.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppSpacing.radiusSmall,
                ),
              ),
              onPressed: () => onApplyTemplate(tpl.title, tpl.body),
            );
          }).toList(),
        ),
      ],
    );
  }
}
