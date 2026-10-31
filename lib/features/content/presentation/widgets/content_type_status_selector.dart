import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/content_entity.dart';

/// Selector section for material content type (PDF, Video, Image, etc.) and publication status.
class ContentTypeStatusSelector extends StatelessWidget {
  final ContentType selectedType;
  final ContentStatus selectedStatus;
  final ValueChanged<ContentType> onTypeChanged;
  final ValueChanged<ContentStatus> onStatusChanged;

  const ContentTypeStatusSelector({
    super.key,
    required this.selectedType,
    required this.selectedStatus,
    required this.onTypeChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Type Selection
        Text(
          context.l10n.materialTypeLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.s6),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s6,
          children: ContentType.values.map((type) {
            final isSelected = selectedType == type;
            return ChoiceChip(
              label: Text(type.localizedLabel(context)),
              selected: isSelected,
              selectedColor: AppColors.primary.withAlpha(30),
              onSelected: (selected) {
                if (selected) onTypeChanged(type);
              },
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: AppSpacing.s16),

        // Publication Status Selection
        Text(
          context.l10n.publicationStatusLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.s6),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s6,
          children: [
            ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.edit_note_rounded,
                    size: 14,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 4),
                  Text(context.l10n.draftPrivateNotice),
                ],
              ),
              selected: selectedStatus == ContentStatus.draft,
              selectedColor: AppColors.warning.withAlpha(30),
              onSelected: (selected) {
                if (selected) onStatusChanged(ContentStatus.draft);
              },
            ),
            ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 4),
                  Text(context.l10n.publishImmediateNotice),
                ],
              ),
              selected: selectedStatus == ContentStatus.published,
              selectedColor: AppColors.success.withAlpha(30),
              onSelected: (selected) {
                if (selected) onStatusChanged(ContentStatus.published);
              },
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.s16),

        if (selectedType == ContentType.video) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              border: Border.all(color: AppColors.primary.withAlpha(40)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.s10),
                Expanded(
                  child: Text(
                    context.l10n.videoStreamingNotice,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
        ],
      ],
    );
  }
}
