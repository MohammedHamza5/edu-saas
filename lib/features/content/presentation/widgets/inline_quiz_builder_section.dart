import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../exams/domain/entities/exam_entity.dart';

/// Mutable state representation for an inline quiz question during lecture creation.
class InlineQuizQuestionData {
  QuestionType type;
  final TextEditingController questionController = TextEditingController();
  final TextEditingController pointsController = TextEditingController(
    text: '1',
  );

  // MCQ Options
  final TextEditingController optA = TextEditingController();
  final TextEditingController optB = TextEditingController();
  final TextEditingController optC = TextEditingController();
  final TextEditingController optD = TextEditingController();
  int correctIndex = 0; // 0: A, 1: B, 2: C, 3: D

  // True / False
  bool isTrueCorrect = true;

  InlineQuizQuestionData({this.type = QuestionType.multipleChoice});

  void dispose() {
    questionController.dispose();
    pointsController.dispose();
    optA.dispose();
    optB.dispose();
    optC.dispose();
    optD.dispose();
  }
}

/// Interactive section for building inline checkpoint quizzes inside lectures.
class InlineQuizBuilderSection extends StatelessWidget {
  final bool isQuizEnabled;
  final ValueChanged<bool> onQuizEnabledChanged;
  final TextEditingController passingScoreController;
  final List<InlineQuizQuestionData> questions;
  final VoidCallback onAddMcq;
  final VoidCallback onAddTrueFalse;
  final ValueChanged<int> onRemoveQuestion;
  final VoidCallback onStateChanged;

  const InlineQuizBuilderSection({
    super.key,
    required this.isQuizEnabled,
    required this.onQuizEnabledChanged,
    required this.passingScoreController,
    required this.questions,
    required this.onAddMcq,
    required this.onAddTrueFalse,
    required this.onRemoveQuestion,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Switch
          Row(
            children: [
              const Icon(
                Icons.quiz_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  context.l10n.inlineQuizSection,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Switch(
                value: isQuizEnabled,
                onChanged: onQuizEnabledChanged,
              ),
            ],
          ),

          if (isQuizEnabled) ...[
            const SizedBox(height: AppSpacing.s12),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s10),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: AppColors.success.withAlpha(50)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_open_rounded,
                    color: AppColors.success,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      context.l10n.enableInlineQuiz,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              context.l10n.lessonQuizSequentialRequirement,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: AppSpacing.s14),

            // Passing score percentage
            SizedBox(
              width: 250,
              child: AppTextField(
                controller: passingScoreController,
                label: context.l10n.examPassingScoreLabel,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // Questions list
            ...questions.asMap().entries.map((entry) {
              final idx = entry.key;
              final q = entry.value;
              return _QuestionItemCard(
                index: idx,
                question: q,
                canDelete: questions.length > 1,
                onDelete: () => onRemoveQuestion(idx),
                onChanged: onStateChanged,
              );
            }),

            const SizedBox(height: AppSpacing.s12),
            // Add Question Actions
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                  label: Text(context.l10n.addMcqQuestionAction),
                  onPressed: onAddMcq,
                ),
                OutlinedButton.icon(
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                  ),
                  label: Text(context.l10n.addTrueFalseQuestionAction),
                  onPressed: onAddTrueFalse,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuestionItemCard extends StatelessWidget {
  final int index;
  final InlineQuizQuestionData question;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _QuestionItemCard({
    required this.index,
    required this.question,
    required this.canDelete,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isMcq = question.type == QuestionType.multipleChoice;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s16),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withAlpha(30),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                isMcq
                    ? context.l10n.questionTypeMcq
                    : context.l10n.questionTypeTrueFalse,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 70,
                child: AppTextField(
                  controller: question.pointsController,
                  label: context.l10n.questionPointsLabel,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              if (canDelete)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                  tooltip: context.l10n.removeQuestionTooltip,
                  onPressed: onDelete,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          AppTextField(
            controller: question.questionController,
            label: context.l10n.questionTextLabel,
          ),
          const SizedBox(height: AppSpacing.s12),

          if (isMcq) ...[
            _McqOptionRow(
              question: question,
              optionIndex: 0,
              letter: 'A',
              controller: question.optA,
              onChanged: onChanged,
            ),
            const SizedBox(height: AppSpacing.s8),
            _McqOptionRow(
              question: question,
              optionIndex: 1,
              letter: 'B',
              controller: question.optB,
              onChanged: onChanged,
            ),
            const SizedBox(height: AppSpacing.s8),
            _McqOptionRow(
              question: question,
              optionIndex: 2,
              letter: 'C',
              controller: question.optC,
              onChanged: onChanged,
            ),
            const SizedBox(height: AppSpacing.s8),
            _McqOptionRow(
              question: question,
              optionIndex: 3,
              letter: 'D',
              controller: question.optD,
              onChanged: onChanged,
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    value: true,
                    groupValue: question.isTrueCorrect,
                    title: Text(context.l10n.trueOptionLabel),
                    onChanged: (v) {
                      question.isTrueCorrect = v!;
                      onChanged();
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    value: false,
                    groupValue: question.isTrueCorrect,
                    title: Text(context.l10n.falseOptionLabel),
                    onChanged: (v) {
                      question.isTrueCorrect = v!;
                      onChanged();
                    },
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

class _McqOptionRow extends StatelessWidget {
  final InlineQuizQuestionData question;
  final int optionIndex;
  final String letter;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _McqOptionRow({
    required this.question,
    required this.optionIndex,
    required this.letter,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = question.correctIndex == optionIndex;

    return Row(
      children: [
        Radio<int>(
          value: optionIndex,
          groupValue: question.correctIndex,
          onChanged: (v) {
            question.correctIndex = v!;
            onChanged();
          },
        ),
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.success : AppColors.surfaceVariant,
            shape: BoxShape.circle,
          ),
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: AppTextField(
            controller: controller,
            hintText: context.l10n.optionLabel(optionIndex + 1),
          ),
        ),
      ],
    );
  }
}
