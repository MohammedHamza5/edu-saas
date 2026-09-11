import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/exam_entity.dart';

class QuestionOptionTile extends StatelessWidget {
  final QuestionOptionEntity option;
  final int index;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool? isCorrectReview;
  final bool isWrongReview;

  const QuestionOptionTile({
    super.key,
    required this.option,
    required this.index,
    this.isSelected = false,
    this.onTap,
    this.isCorrectReview,
    this.isWrongReview = false,
  });

  String _getOptionLabel(BuildContext context) {
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
            width: isSelected || isCorrectReview == true || isWrongReview ? 1.5 : 1,
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

            // Option text
            Expanded(
              child: Text(
                option.optionText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

            if (isCorrectReview == true) ...[
              const SizedBox(width: AppSpacing.s8),
              const Icon(Icons.check_circle, color: AppColors.success, size: 20),
            ] else if (isWrongReview) ...[
              const SizedBox(width: AppSpacing.s8),
              const Icon(Icons.cancel, color: AppColors.error, size: 20),
            ] else if (isSelected) ...[
              const SizedBox(width: AppSpacing.s8),
              const Icon(Icons.radio_button_checked, color: AppColors.primary, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
