import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../models/create_exam_draft_models.dart';

class CreateExamMultipleChoiceSection extends StatelessWidget {
  final List<CreateExamDraftOption> options;
  final bool isCreating;
  final ValueChanged<int> onOptionCorrectChanged;
  final VoidCallback onAddOption;
  final ValueChanged<int> onRemoveOption;
  final ValueChanged<List<String>> onQuickFill;

  const CreateExamMultipleChoiceSection({
    super.key,
    required this.options,
    required this.isCreating,
    required this.onOptionCorrectChanged,
    required this.onAddOption,
    required this.onRemoveOption,
    required this.onQuickFill,
  });

  @override
  Widget build(BuildContext context) {
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    context.l10n.optionsSelectCorrectPrompt,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  InkWell(
                    onTap: isCreating
                        ? null
                        : () => onQuickFill(['A', 'B', 'C', 'D']),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSmall),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSmall,
                        ),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_fix_high_rounded,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.quickFillAbcdChip,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: isCreating
                        ? null
                        : () => onQuickFill(['F', 'G', 'H', 'J']),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSmall),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSmall,
                        ),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        context.l10n.quickFillFghjChip,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (options.length < 6)
              TextButton.icon(
                onPressed: isCreating ? null : onAddOption,
                icon: const Icon(Icons.add, size: 16),
                label: Text(context.l10n.addOption),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        ...options.asMap().entries.map((optEntry) {
          final optIdx = optEntry.key;
          final opt = optEntry.value;
          final letter = optIdx < letters.length
              ? letters[optIdx]
              : '${optIdx + 1}';

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s10),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s8,
                vertical: AppSpacing.s4,
              ),
              decoration: BoxDecoration(
                color: opt.isCorrect
                    ? AppColors.success.withValues(alpha: 0.05)
                    : Colors.transparent,
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(
                  color: opt.isCorrect
                      ? AppColors.success.withValues(alpha: 0.6)
                      : AppColors.border,
                  width: opt.isCorrect ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Radio<int>(
                    value: optIdx,
                    groupValue: options.indexWhere((o) => o.isCorrect),
                    activeColor: AppColors.success,
                    onChanged: isCreating
                        ? null
                        : (_) => onOptionCorrectChanged(optIdx),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: opt.isCorrect
                          ? AppColors.success
                          : AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                    ),
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: opt.isCorrect
                            ? Colors.white
                            : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: TextFormField(
                      controller: opt.controller,
                      decoration: InputDecoration(
                        hintText: context.l10n.optionLetter(letter),
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  if (opt.isCorrect)
                    Container(
                      margin: const EdgeInsets.only(left: 8, right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSmall,
                        ),
                      ),
                      child: Text(
                        context.l10n.correctAnswerBadge,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  if (options.length > 2)
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      tooltip: context.l10n.removeOption,
                      onPressed: isCreating ? null : () => onRemoveOption(optIdx),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
