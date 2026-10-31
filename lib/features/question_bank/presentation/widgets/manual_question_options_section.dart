import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';

class DraftOption {
  final TextEditingController controller;
  bool isCorrect;

  DraftOption({
    String text = '',
    this.isCorrect = false,
  }) : controller = TextEditingController(text: text);

  void dispose() {
    controller.dispose();
  }
}

/// Options section in ManualQuestionEntryPage supporting both multiple-choice options
/// (with dynamic adding, removing, and radio selection) and True/False mode selection.
class ManualQuestionOptionsSection extends StatelessWidget {
  final String questionType;
  final List<DraftOption> options;
  final bool trueFalseAnswer;
  final VoidCallback onAddOption;
  final ValueChanged<int> onRemoveOption;
  final ValueChanged<int> onSelectCorrectOption;
  final ValueChanged<bool> onSelectTrueFalse;

  const ManualQuestionOptionsSection({
    super.key,
    required this.questionType,
    required this.options,
    required this.trueFalseAnswer,
    required this.onAddOption,
    required this.onRemoveOption,
    required this.onSelectCorrectOption,
    required this.onSelectTrueFalse,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (questionType == 'multiple_choice') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.optionsLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (options.length < 6)
                  TextButton.icon(
                    onPressed: onAddOption,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(l10n.addOption),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              l10n.tapToSelectAnswer,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            ...options.asMap().entries.map((entry) {
              final idx = entry.key;
              final opt = entry.value;
              final key = String.fromCharCode(65 + idx);

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Radio button for correct answer
                    IconButton(
                      icon: Icon(
                        opt.isCorrect
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: opt.isCorrect
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                      onPressed: () => onSelectCorrectOption(idx),
                    ),
                    // Option letter badge
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: opt.isCorrect
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : AppColors.surfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        key,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: opt.isCorrect
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    // Option text input
                    Expanded(
                      child: TextFormField(
                        controller: opt.controller,
                        decoration: InputDecoration(
                          hintText: l10n.optionLetter(key),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    if (options.length > 2)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                          size: 20,
                        ),
                        onPressed: () => onRemoveOption(idx),
                      ),
                  ],
                ),
              );
            }),
          ] else if (questionType == 'true_false') ...[
            Text(
              l10n.correctAnswer,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => onSelectTrueFalse(true),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.s16,
                      ),
                      decoration: BoxDecoration(
                        color: trueFalseAnswer
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.surfaceVariant,
                        border: Border.all(
                          color: trueFalseAnswer
                              ? AppColors.primary
                              : AppColors.border,
                          width: trueFalseAnswer ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            trueFalseAnswer
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            color: trueFalseAnswer
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.optionTrue,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: trueFalseAnswer
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s16),
                Expanded(
                  child: InkWell(
                    onTap: () => onSelectTrueFalse(false),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.s16,
                      ),
                      decoration: BoxDecoration(
                        color: !trueFalseAnswer
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.surfaceVariant,
                        border: Border.all(
                          color: !trueFalseAnswer
                              ? AppColors.primary
                              : AppColors.border,
                          width: !trueFalseAnswer ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            !trueFalseAnswer
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            color: !trueFalseAnswer
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.optionFalse,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: !trueFalseAnswer
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
