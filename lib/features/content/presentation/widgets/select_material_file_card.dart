import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/library_material_entity.dart';

/// Card item representing a library material in the selection picker dialog
class SelectMaterialFileCard extends StatelessWidget {
  final LibraryMaterialEntity item;
  final VoidCallback onPreview;
  final VoidCallback onSelect;

  const SelectMaterialFileCard({
    super.key,
    required this.item,
    required this.onPreview,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.isPdf
                  ? Colors.red.withValues(alpha: 0.12)
                  : AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            ),
            child: Icon(
              item.isPdf
                  ? Icons.picture_as_pdf_rounded
                  : Icons.description_rounded,
              color: item.isPdf ? Colors.redAccent : AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),

          // File Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      item.formattedFileSize,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: AppColors.textSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (item.isAssigned) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          l10n.usedInLecturesCount(item.assignedLecturesCount),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        l10n.unusedMaterial,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s8),

          // Actions
          IconButton(
            icon: const Icon(Icons.remove_red_eye_outlined, size: 20),
            tooltip: l10n.previewMaterialAction,
            color: AppColors.textSecondary,
            onPressed: onPreview,
          ),
          const SizedBox(width: AppSpacing.s6),
          AppButton(
            text: l10n.selectMaterialAction,
            icon: Icons.check_circle_outline_rounded,
            onPressed: onSelect,
          ),
        ],
      ),
    );
  }
}
