import 'package:flutter/material.dart';
import 'package:edu_saas/core/theme/app_colors.dart';
import 'package:edu_saas/core/theme/app_spacing.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_entity.dart';

class SmartPracticeOptionsView extends StatelessWidget {
  final List<QuestionOptionEntity> options;
  final String? selectedOptionId;
  final String? correctOptionId;
  final bool isSubmitted;
  final ValueChanged<String> onSelectOption;

  const SmartPracticeOptionsView({
    super.key,
    required this.options,
    required this.selectedOptionId,
    required this.correctOptionId,
    required this.isSubmitted,
    required this.onSelectOption,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options.asMap().entries.map((entry) {
        final idx = entry.key;
        final opt = entry.value;
        final isSelected = selectedOptionId == opt.id;
        final isModelCorrect = correctOptionId != null && opt.id == correctOptionId;

        Color borderCol = AppColors.border;
        Color bgCol = AppColors.surface;

        if (isSubmitted) {
          if (isModelCorrect) {
            borderCol = AppColors.success;
            bgCol = AppColors.success.withValues(alpha: 0.1);
          } else if (isSelected) {
            borderCol = AppColors.error;
            bgCol = AppColors.error.withValues(alpha: 0.1);
          }
        } else if (isSelected) {
          borderCol = AppColors.primary;
          bgCol = AppColors.primary.withValues(alpha: 0.08);
        }

        final letter = String.fromCharCode(65 + (idx < 26 ? idx : 0));

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s12),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            onTap: isSubmitted ? null : () => onSelectOption(opt.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s16,
              ),
              decoration: BoxDecoration(
                color: bgCol,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(
                  color: borderCol,
                  width: isSelected || (isSubmitted && isModelCorrect) ? 2.0 : 1.2,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: isSelected
                        ? (isSubmitted && !isModelCorrect
                            ? AppColors.error
                            : AppColors.primary)
                        : (isSubmitted && isModelCorrect
                            ? AppColors.success
                            : AppColors.surfaceVariant),
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSelected || (isSubmitted && isModelCorrect)
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s16),
                  Expanded(
                    child: Text(
                      opt.optionText,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (isSubmitted && isModelCorrect)
                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22)
                  else if (isSubmitted && isSelected)
                    const Icon(Icons.cancel_rounded, color: AppColors.error, size: 22),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
