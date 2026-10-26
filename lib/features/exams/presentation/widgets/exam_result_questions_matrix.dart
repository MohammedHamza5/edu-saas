import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/exam_entity.dart';

/// Interactive answer sheet matrix grid widget showing student performance per question
/// with status legends (correct, incorrect, skipped) and quick review navigation.
class ExamResultQuestionsMatrix extends StatelessWidget {
  final List<ExamQuestionEntity> questions;
  final List<ExamAnswerEntity> answers;
  final String attemptId;
  final bool isLoadingDetails;
  final bool hasAttachedPdf;
  final void Function(int initialQuestionIndex) onOpenReview;
  final VoidCallback onOpenPdfBooklet;

  const ExamResultQuestionsMatrix({
    super.key,
    required this.questions,
    required this.answers,
    required this.attemptId,
    required this.isLoadingDetails,
    required this.hasAttachedPdf,
    required this.onOpenReview,
    required this.onOpenPdfBooklet,
  });

  Widget _buildLegendPill(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (questions.isNotEmpty) {
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
                    Text(
                      context.l10n.questionsMatrixTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Wrap(
                      spacing: AppSpacing.s8,
                      children: [
                        if (hasAttachedPdf)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                            icon: const Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 14,
                            ),
                            label: Text(
                              context.l10n.viewExamBooklet,
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            onPressed: onOpenPdfBooklet,
                          ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          icon: const Icon(
                            Icons.fact_check_outlined,
                            size: 14,
                          ),
                          label: Text(
                            context.l10n.reviewAllQuestionsAction,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          onPressed: () => onOpenReview(0),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  context.l10n.questionsMatrixSubtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),

                // Status Legends
                Row(
                  children: [
                    _buildLegendPill(
                      context.l10n.statusCorrect,
                      AppColors.success,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    _buildLegendPill(
                      context.l10n.statusIncorrect,
                      AppColors.error,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    _buildLegendPill(
                      context.l10n.statusSkipped,
                      AppColors.warning,
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.s14),

                // Questions Grid Tiles
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: List.generate(questions.length, (index) {
                    final q = questions[index];
                    final ans = answers.firstWhere(
                      (a) => a.questionId == q.id,
                      orElse: () => ExamAnswerEntity(
                        id: '',
                        attemptId: attemptId,
                        questionId: q.id,
                        answeredAt: DateTime.now(),
                      ),
                    );

                    Color chipColor;
                    Color chipBg;
                    IconData chipIcon;

                    if (ans.isCorrect == true) {
                      chipColor = AppColors.success;
                      chipBg = AppColors.success.withValues(alpha: 0.12);
                      chipIcon = Icons.check;
                    } else if (ans.selectedOptionId != null &&
                        ans.isCorrect == false) {
                      chipColor = AppColors.error;
                      chipBg = AppColors.error.withValues(alpha: 0.12);
                      chipIcon = Icons.close;
                    } else {
                      chipColor = AppColors.warning;
                      chipBg = AppColors.warning.withValues(alpha: 0.12);
                      chipIcon = Icons.remove;
                    }

                    return InkWell(
                      onTap: () => onOpenReview(index),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                      child: Container(
                        width: 54,
                        height: 48,
                        decoration: BoxDecoration(
                          color: chipBg,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSmall,
                          ),
                          border: Border.all(
                            color: chipColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: chipColor,
                              ),
                            ),
                            Icon(
                              chipIcon,
                              size: 13,
                              color: chipColor,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (isLoadingDetails) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.s16),
          child: CircularProgressIndicator(),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
