import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/forensic_watermark_overlay.dart';
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_state.dart';
import 'exam_taking_navigation_bar.dart';
import 'exam_taking_question_card.dart';

/// The active Question View pane during an exam, rendering progress bar,
/// question metadata, attached PDF ribbon, question card, and navigation bar.
class ExamTakingQuestionsView extends StatelessWidget {
  final ExamTakingState state;
  final int questionIndex;
  final ExamQuestionEntity question;
  final bool isDesktop;
  final bool showDesktopPdfPane;
  final VoidCallback onOpenPdfBooklet;
  final VoidCallback onToggleFlagGuess;
  final VoidCallback onToggleVault;
  final void Function(String optionId) onSelectOption;
  final void Function(String optionId) onToggleEliminateOption;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onReviewGrid;
  final VoidCallback onSubmit;

  const ExamTakingQuestionsView({
    super.key,
    required this.state,
    required this.questionIndex,
    required this.question,
    required this.isDesktop,
    required this.showDesktopPdfPane,
    required this.onOpenPdfBooklet,
    required this.onToggleFlagGuess,
    required this.onToggleVault,
    required this.onSelectOption,
    required this.onToggleEliminateOption,
    required this.onPrevious,
    required this.onNext,
    required this.onReviewGrid,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return ForensicWatermarkOverlay(
      child: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: state.totalQuestions > 0
                ? (state.currentQuestionIndex + 1) / state.totalQuestions
                : 0,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.primary,
            ),
            minHeight: 4,
          ),

          // Attached PDF quick ribbon (for mobile or when desktop PDF pane is closed)
          if (state.exam.hasAttachedPdf && (!isDesktop || !showDesktopPdfPane))
            Container(
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s8,
                AppSpacing.s16,
                0,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s12,
                vertical: AppSpacing.s8,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.picture_as_pdf_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      state.exam.pdfFileName ?? context.l10n.attachedExamPdf,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s8,
                        vertical: 4,
                      ),
                    ),
                    onPressed: onOpenPdfBooklet,
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: Text(
                      context.l10n.viewExamBooklet,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Question Header info
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.questionProgress(
                    questionIndex + 1,
                    state.totalQuestions,
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  context.l10n.solvedCount(
                    state.answeredCount,
                    state.totalQuestions,
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Question Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question Card
                  ExamTakingQuestionCard(
                    question: question,
                    questionIndex: questionIndex,
                    totalQuestions: state.totalQuestions,
                    selectedOptionId: state.answers[question.id],
                    eliminatedOptionIds:
                        state.eliminatedOptions[question.id] ?? const {},
                    isFlaggedAsGuess: state.isCurrentQuestionFlaggedAsGuess,
                    isSubmitting: state.isSubmitting,
                    onToggleFlagGuess: onToggleFlagGuess,
                    onToggleVault: onToggleVault,
                    onSelectOption: onSelectOption,
                    onToggleEliminateOption: onToggleEliminateOption,
                  ),
                ],
              ),
            ),
          ),

          // Bottom Navigation Control Bar
          ExamTakingNavigationBar(
            hasPrevious: questionIndex > 0,
            hasNext: state.hasNext,
            isSubmitting: state.isSubmitting,
            onPrevious: onPrevious,
            onReviewGrid: onReviewGrid,
            onNext: onNext,
            onSubmit: onSubmit,
          ),
        ],
      ),
    );
  }
}
