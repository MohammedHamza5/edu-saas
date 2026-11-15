import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/mistake_entities.dart';
import '../utils/question_image_resolver.dart';
import 'exam_grid_in_input_pane.dart';
import 'exam_image_viewer.dart';
import 'question_audio_player.dart';

class MistakesPracticeQuestionCard extends StatelessWidget {
  final MistakeQuestionEntity question;
  final List<MistakeOptionEntity> options;
  final String? selectedOptionId;
  final ValueChanged<String> onSelectOption;

  const MistakesPracticeQuestionCard({
    super.key,
    required this.question,
    required this.options,
    required this.selectedOptionId,
    required this.onSelectOption,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Contextual Badge (Mastered vs Wrong answer vs Skipped question)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.s12),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s8,
            ),
            decoration: BoxDecoration(
              color:
                  (question.isResolved
                          ? AppColors.success
                          : question.isSkipped
                          ? AppColors.warning
                          : AppColors.error)
                      .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              border: Border.all(
                color:
                    (question.isResolved
                            ? AppColors.success
                            : question.isSkipped
                            ? AppColors.warning
                            : AppColors.error)
                        .withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  question.isResolved
                      ? Icons.check_circle_rounded
                      : question.isSkipped
                      ? Icons.pause_circle_outline_rounded
                      : Icons.cancel_outlined,
                  color: question.isResolved
                      ? AppColors.success
                      : question.isSkipped
                      ? AppColors.warning
                      : AppColors.error,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    question.isResolved
                        ? '${l10n.badgeMastered} - ${l10n.practiceModeResolvedDesc}'
                        : question.isSkipped
                        ? l10n.practiceHeaderSkippedNote
                        : l10n.practiceHeaderWrongNote,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: question.isResolved
                          ? AppColors.success
                          : question.isSkipped
                          ? AppColors.warning
                          : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Resolve Image & Question Stem
          Builder(
            builder: (context) {
              final effectiveImageUrl =
                  QuestionImageResolver.resolveEffectiveImageUrl(
                imageUrl: question.imageUrl,
                questionText: question.questionText,
              );
              final shouldShowText =
                  QuestionImageResolver.shouldShowQuestionText(
                question.questionText,
                effectiveImageUrl,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (shouldShowText) ...[
                    Text(
                      question.questionText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                  ],
                  if (effectiveImageUrl != null &&
                      effectiveImageUrl.isNotEmpty) ...[
                    ExamImageViewer(
                      key: ValueKey(
                        'practice_img_${question.questionId}_$effectiveImageUrl',
                      ),
                      imageUrl: effectiveImageUrl,
                      imageMeta: question.imageMeta,
                    ),
                    const SizedBox(height: AppSpacing.s16),
                  ],
                ],
              );
            },
          ),

          // Audio Explanation if present
          if (question.audioUrl != null && question.audioUrl!.trim().isNotEmpty) ...[
            QuestionAudioPlayer(
              key: ValueKey('practice_audio_${question.questionId}'),
              audioUrl: question.audioUrl,
              initialDurationSeconds: question.audioDurationSeconds,
            ),
            const SizedBox(height: AppSpacing.s16),
          ],

          // Instruction
          Text(
            question.isGridIn
                ? l10n.gridInAnswerPlaceholder
                : l10n.practiceExamInstruction,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // Options or Numeric Grid-in Input
          if (question.isGridIn)
            ExamGridInInputPane(
              key: ValueKey('grid_in_${question.questionId}'),
              currentAnswer: selectedOptionId,
              onAnswerChanged: onSelectOption,
              isSubmitting: false,
            )
          else
            ...options.map((opt) {
            final isSelected = selectedOptionId == opt.id;
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.s8),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.08)
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.grey.withValues(alpha: 0.25),
                  width: isSelected ? 1.8 : 1.0,
                ),
              ),
              child: InkWell(
                onTap: () => onSelectOption(opt.id),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: AppSpacing.s16,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.grey,
                      ),
                      const SizedBox(width: AppSpacing.s16),
                      Expanded(
                        child: Text(
                          opt.optionText,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : null,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
