import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../question_bank/presentation/widgets/question_display_widgets.dart';
import '../../domain/entities/exam_entity.dart';
import 'exam_image_viewer.dart';
import 'question_option_tile.dart';
import '../extensions/exam_ui_extensions.dart';

/// Question stem, formula/image view, and interactive option selector for exam taking.
class ExamTakingQuestionCard extends StatelessWidget {
  final ExamQuestionEntity question;
  final int questionIndex;
  final int totalQuestions;
  final String? selectedOptionId;
  final Set<String> eliminatedOptionIds;
  final bool isFlaggedAsGuess;
  final bool isSubmitting;
  final bool isSavedInVault;
  final VoidCallback onToggleFlagGuess;
  final VoidCallback onToggleVault;
  final ValueChanged<String> onSelectOption;
  final ValueChanged<String> onToggleEliminateOption;

  const ExamTakingQuestionCard({
    super.key,
    required this.question,
    required this.questionIndex,
    required this.totalQuestions,
    required this.selectedOptionId,
    required this.eliminatedOptionIds,
    required this.isFlaggedAsGuess,
    required this.isSubmitting,
    this.isSavedInVault = false,
    required this.onToggleFlagGuess,
    required this.onToggleVault,
    required this.onSelectOption,
    required this.onToggleEliminateOption,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                    ),
                    child: Text(
                      question.questionType.localizedLabel(context),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Flag as Guess Toggle Button
                      Tooltip(
                        message: isFlaggedAsGuess
                            ? l10n.unflagGuessTooltip
                            : l10n.flagAsGuessTooltip,
                        child: InkWell(
                          onTap: onToggleFlagGuess,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSmall,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isFlaggedAsGuess
                                  ? AppColors.warning.withValues(alpha: 0.18)
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSmall,
                              ),
                              border: Border.all(
                                color: isFlaggedAsGuess
                                    ? AppColors.warning
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isFlaggedAsGuess
                                      ? Icons.flag_rounded
                                      : Icons.flag_outlined,
                                  size: 13,
                                  color: isFlaggedAsGuess
                                      ? AppColors.warning
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.guessFlagLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isFlaggedAsGuess
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isFlaggedAsGuess
                                        ? AppColors.warning
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Text(
                        l10n.scorePoints(question.points),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              Builder(
                builder: (context) {
                  final hasExplicitImage = question.imageUrl != null &&
                      question.imageUrl!.trim().isNotEmpty;
                  final isTextAnImageUrl = QuestionStemView.isImageUrl(
                    question.questionText.trim(),
                  );
                  final effectiveImageUrl = hasExplicitImage
                      ? question.imageUrl!
                      : (isTextAnImageUrl
                          ? question.questionText.trim()
                          : null);
                  final shouldShowText =
                      question.questionText.trim().isNotEmpty &&
                          !isTextAnImageUrl;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (shouldShowText) ...[
                        Text(
                          question.questionText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s12),
                      ],
                      if (effectiveImageUrl != null &&
                          effectiveImageUrl.isNotEmpty)
                        ExamImageViewer(
                          key: ValueKey(
                            'exam_q_${question.id}_$effectiveImageUrl',
                          ),
                          imageUrl: effectiveImageUrl,
                          imageMeta: question.imageMeta,
                          caption: l10n.questionProgress(
                            questionIndex + 1,
                            totalQuestions,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s20),

        // Options list
        if (question.options.isNotEmpty) ...[
          Text(
            l10n.chooseCorrectAnswer,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          ...question.options.asMap().entries.map((optEntry) {
            final optIdx = optEntry.key;
            final option = optEntry.value;
            final isSelected = selectedOptionId == option.id;
            final isEliminated = eliminatedOptionIds.contains(option.id);

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s10),
              child: QuestionOptionTile(
                option: option,
                index: optIdx,
                isSelected: isSelected,
                isEliminated: isEliminated,
                onTap: isSubmitting ? () {} : () => onSelectOption(option.id),
                onEliminate: isSubmitting
                    ? () {}
                    : () => onToggleEliminateOption(option.id),
              ),
            );
          }),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(
                    l10n.noOptionsAvailableForQuestionWarning,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
