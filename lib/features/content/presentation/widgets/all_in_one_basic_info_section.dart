import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';

class AllInOneBasicInfoSection extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController descriptionController;

  const AllInOneBasicInfoSection({
    super.key,
    required this.titleController,
    required this.descriptionController,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                l10n.lectureDetailsSection,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          AppTextField(
            controller: titleController,
            label: l10n.lectureTitleLabel,
            hintText: l10n.lectureTitleHint,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return l10n.contentTitleRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.s12),
          AppTextField(
            controller: descriptionController,
            label: l10n.lectureDescLabel,
            hintText: l10n.lectureDescHint,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
