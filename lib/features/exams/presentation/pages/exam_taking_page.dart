import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';
import '../widgets/question_option_tile.dart';
import '../widgets/sat_exam_tools_sheet.dart';
import 'exam_result_page.dart';

class ExamTakingPage extends StatelessWidget {
  const ExamTakingPage({super.key});

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _confirmSubmit(BuildContext context, ExamTakingState state) {
    final unanswered = state.totalQuestions - state.answeredCount;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.confirmSubmitExamTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.answeredQuestionsCount(state.answeredCount, state.totalQuestions)),
            if (unanswered > 0) ...[
              const SizedBox(height: AppSpacing.s8),
              Text(
                context.l10n.unansweredWarning(unanswered),
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s12),
            Text(context.l10n.confirmSubmitQuestion),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.continueSolving),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<ExamsCubit>().submitExam();
            },
            child: Text(context.l10n.yesSubmitExam, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExamsCubit, ExamsState>(
      listener: (context, state) {
        if (state is ExamTakingState) {
          if (state.submitSuccess && state.submitResult != null) {
            Navigator.of(context).pushReplacement<void, void>(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider.value(
                  value: context.read<ExamsCubit>(),
                  child: ExamResultPage(
                    exam: state.exam,
                    attempt: state.submitResult!,
                  ),
                ),
              ),
            );
          } else if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      },
      builder: (context, state) {
        if (state is ExamsError) {
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.examRulesAndGuidelines),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 56, color: AppColors.error),
                    const SizedBox(height: AppSpacing.s16),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.s24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: Text(context.l10n.backToExamsList),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (state is! ExamTakingState) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: const Center(child: AppLoadingView.signature()),
          );
        }

        final qIndex = state.currentQuestionIndex;
        final question = state.currentQuestion;
        final isUrgent = state.remainingSeconds < 300; // < 5 minutes

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              _confirmSubmit(context, state);
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(state.exam.title),
              centerTitle: false,
              actions: [
                // SAT Reference Formulas Sheet
                IconButton(
                  icon: const Icon(Icons.menu_book_rounded),
                  tooltip: context.l10n.referenceSheetTooltip,
                  onPressed: () => SatExamToolsSheet.showReferenceSheet(context),
                ),
                // Built-in SAT Calculator
                IconButton(
                  icon: const Icon(Icons.calculate_rounded),
                  tooltip: context.l10n.calculatorTooltip,
                  onPressed: () => SatExamToolsSheet.showCalculator(context),
                ),
                // Timer badge
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                    vertical: AppSpacing.s8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                    vertical: AppSpacing.s6,
                  ),
                  decoration: BoxDecoration(
                    color: isUrgent
                        ? AppColors.error.withValues(alpha: 0.15)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    border: isUrgent ? Border.all(color: AppColors.error) : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: isUrgent ? AppColors.error : AppColors.textPrimary,
                      ),
                      const SizedBox(width: AppSpacing.s6),
                      Text(
                        _formatDuration(state.remainingSeconds),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isUrgent ? AppColors.error : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                // Progress indicator
                LinearProgressIndicator(
                  value: state.totalQuestions > 0
                      ? (state.currentQuestionIndex + 1) / state.totalQuestions
                      : 0,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 4,
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
                        context.l10n.questionProgress(qIndex + 1, state.totalQuestions),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        context.l10n.solvedCount(state.answeredCount, state.totalQuestions),
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
                                      borderRadius:
                                          BorderRadius.circular(AppSpacing.radiusSmall),
                                    ),
                                    child: Text(
                                      question.questionType.localizedLabel(context),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    context.l10n.scorePoints(question.points),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.s12),
                              Text(
                                question.questionText,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppSpacing.s20),

                        // Options list
                        Text(
                          context.l10n.chooseCorrectAnswer,
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
                          final isSelected = state.answers[question.id] == option.id;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.s10),
                            child: QuestionOptionTile(
                              option: option,
                              index: optIdx,
                              isSelected: isSelected,
                              onTap: () {
                                context
                                    .read<ExamsCubit>()
                                    .selectAnswer(question.id, option.id);
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                // Bottom Navigation Control Bar
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: const Border(top: BorderSide(color: AppColors.border)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Previous button
                      if (state.hasPrevious)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              context.read<ExamsCubit>().goToQuestion(qIndex - 1);
                            },
                            icon: const Icon(Icons.arrow_forward, size: 16),
                            label: Text(context.l10n.previousQuestion),
                          ),
                        )
                      else
                        const Spacer(),

                      const SizedBox(width: AppSpacing.s12),

                      // Next or Submit button
                      if (state.hasNext)
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              context.read<ExamsCubit>().goToQuestion(qIndex + 1);
                            },
                            icon: const Icon(Icons.arrow_back, size: 16),
                            label: Text(context.l10n.nextQuestion),
                          ),
                        )
                      else
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: state.isSubmitting
                                ? null
                                : () => _confirmSubmit(context, state),
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: state.isSubmitting
                                ? const AppLoadingView.compact(
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : Text(context.l10n.submitExamNow),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
