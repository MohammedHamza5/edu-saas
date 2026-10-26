import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/exam_entity.dart';
import 'option_image_view.dart';

class QuestionOptionTile extends StatelessWidget {
  final QuestionOptionEntity option;
  final int index;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool? isCorrectReview;
  final bool isWrongReview;
  final bool isEliminated;
  final VoidCallback? onEliminate;

  const QuestionOptionTile({
    super.key,
    required this.option,
    required this.index,
    this.isSelected = false,
    this.onTap,
    this.isCorrectReview,
    this.isWrongReview = false,
    this.isEliminated = false,
    this.onEliminate,
  });

  String _getOptionLabel(BuildContext context) {
    final trimmed = option.optionText.trim();
    if (RegExp(r'^[A-Za-z]$').hasMatch(trimmed)) {
      return trimmed.toUpperCase();
    }
    if (trimmed.length == 1 &&
        const ['أ', 'ب', 'ج', 'د', 'هـ', 'و'].contains(trimmed)) {
      return trimmed;
    }
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final labels = isAr
        ? const ['أ', 'ب', 'ج', 'د', 'هـ', 'و']
        : const ['A', 'B', 'C', 'D', 'E', 'F'];
    if (index >= 0 && index < labels.length) {
      return labels[index];
    }
    return '${index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    Color borderColor = AppColors.border;
    Color backgroundColor = AppColors.surface;
    Color indicatorBg = AppColors.surfaceVariant;
    Color indicatorTextColor = AppColors.textPrimary;

    if (isCorrectReview == true) {
      borderColor = AppColors.success;
      backgroundColor = AppColors.success.withValues(alpha: 0.08);
      indicatorBg = AppColors.success;
      indicatorTextColor = Colors.white;
    } else if (isWrongReview) {
      borderColor = AppColors.error;
      backgroundColor = AppColors.error.withValues(alpha: 0.08);
      indicatorBg = AppColors.error;
      indicatorTextColor = Colors.white;
    } else if (isEliminated) {
      borderColor = AppColors.border.withValues(alpha: 0.4);
      backgroundColor = AppColors.surfaceVariant.withValues(alpha: 0.25);
      indicatorBg = Colors.grey.withValues(alpha: 0.2);
      indicatorTextColor = AppColors.textMuted;
    } else if (isSelected) {
      borderColor = AppColors.primary;
      backgroundColor = AppColors.primary.withValues(alpha: 0.06);
      indicatorBg = AppColors.primary;
      indicatorTextColor = Colors.white;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          border: Border.all(
            color: borderColor,
            width: isSelected || isCorrectReview == true || isWrongReview
                ? 1.5
                : 1,
          ),
        ),
        child: Row(
          children: [
            // Option letter indicator
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: indicatorBg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _getOptionLabel(context),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: indicatorTextColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),

            // Option text and optional image
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (option.optionText.isNotEmpty)
                    Text(
                      option.optionText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isEliminated
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        decoration: isEliminated
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  if (option.imageUrl != null &&
                      option.imageUrl!.isNotEmpty) ...[
                    if (option.optionText.isNotEmpty) const SizedBox(height: 6),
                    OptionImageView(imageUrl: option.imageUrl!),
                  ],
                ],
              ),
            ),

            if (onEliminate != null && isCorrectReview == null && !isWrongReview) ...[
              const SizedBox(width: AppSpacing.s4),
              InkWell(
                onTap: onEliminate,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isEliminated
                        ? Icons.strikethrough_s_rounded
                        : Icons.close_rounded,
                    size: 16,
                    color: isEliminated
                        ? AppColors.error
                        : AppColors.textMuted.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],

            if (isCorrectReview == true) ...[
              const SizedBox(width: AppSpacing.s8),
              const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 20,
              ),
            ] else if (isWrongReview) ...[
              const SizedBox(width: AppSpacing.s8),
              const Icon(Icons.cancel, color: AppColors.error, size: 20),
            ] else if (isSelected) ...[
              const SizedBox(width: AppSpacing.s8),
              const Icon(
                Icons.radio_button_checked,
                color: AppColors.primary,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
