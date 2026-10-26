import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class CreateExamTrueFalseSection extends StatelessWidget {
  final bool trueFalseAnswer;
  final bool isCreating;
  final ValueChanged<bool> onChanged;

  const CreateExamTrueFalseSection({
    super.key,
    required this.trueFalseAnswer,
    required this.isCreating,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              context.l10n.selectCorrectAnswerPrompt,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        Row(
          children: [
            Expanded(
              child: _buildTrueFalseChoiceCard(
                context: context,
                label: context.l10n.optionTrue,
                isTrue: true,
                isSelected: trueFalseAnswer == true,
                onTap: isCreating ? null : () => onChanged(true),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: _buildTrueFalseChoiceCard(
                context: context,
                label: context.l10n.optionFalse,
                isTrue: false,
                isSelected: trueFalseAnswer == false,
                onTap: isCreating ? null : () => onChanged(false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrueFalseChoiceCard({
    required BuildContext context,
    required String label,
    required bool isTrue,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    final activeColor = isTrue ? AppColors.success : AppColors.error;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s14,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? activeColor : AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? activeColor : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
