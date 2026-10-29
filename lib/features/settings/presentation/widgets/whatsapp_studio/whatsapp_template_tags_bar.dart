import 'package:flutter/material.dart';
import '../../../../../core/extensions/localized_context_extension.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';

class WhatsAppTemplateTagsBar extends StatelessWidget {
  final void Function(String tag) onTagSelected;

  const WhatsAppTemplateTagsBar({
    super.key,
    required this.onTagSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final tags = [
      (key: '{student_name}', label: l10n.whatsappStudioTagStudentName),
      (key: '{exam_title}', label: l10n.whatsappStudioTagExamTitle),
      (key: '{score}', label: l10n.whatsappStudioTagScore),
      (key: '{max_score}', label: l10n.whatsappStudioTagMaxScore),
      (key: '{percentage}', label: l10n.whatsappStudioTagPercentage),
      (key: '{group_name}', label: l10n.whatsappStudioTagGroupName),
      (key: '{teacher_name}', label: l10n.whatsappStudioTagTeacherName),
      (key: '{evaluation_text}', label: l10n.whatsappStudioTagEvaluation),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.s4),
            Text(
              l10n.whatsappStudioTagsLabel,
              style: const TextStyle(
                fontSize: 11,
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
          children: tags.map((t) {
            return ActionChip(
              avatar: const Icon(
                Icons.add_rounded,
                size: 14,
                color: AppColors.primary,
              ),
              label: Text(t.label),
              labelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
              backgroundColor: AppColors.primary.withValues(alpha: 0.08),
              side: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              ),
              onPressed: () => onTagSelected(t.key),
            );
          }).toList(),
        ),
      ],
    );
  }
}
