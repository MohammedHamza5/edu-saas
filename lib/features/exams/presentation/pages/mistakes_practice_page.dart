import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../domain/entities/mistake_entities.dart';
import '../cubit/mistakes_cubit.dart';
import '../cubit/mistakes_state.dart';

class MistakesPracticePage extends StatefulWidget {
  final String? sourceExamId;

  const MistakesPracticePage({super.key, this.sourceExamId});

  @override
  State<MistakesPracticePage> createState() => _MistakesPracticePageState();
}

class _MistakesPracticePageState extends State<MistakesPracticePage> {
  int _currentIndex = 0;
  final Map<String, String> _selectedAnswers = {}; // questionId -> optionId

  @override
  void initState() {
    super.initState();
    // Load unresolved mistakes for practice
    context.read<MistakesCubit>().loadMistakes(
          examId: widget.sourceExamId,
          onlyUnresolved: true,
        );
  }

  void _openImageDialog(BuildContext context, String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.s16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    height: 250,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  void _submitPractice() {
    final cubit = context.read<MistakesCubit>();
    final answersList = _selectedAnswers.entries
        .map((e) => {
              'question_id': e.key,
              'selected_option_id': e.value,
            })
        .toList();
    cubit.submitPractice(answersList);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.practiceExamTitle),
        elevation: 0,
        centerTitle: false,
      ),
      body: BlocConsumer<MistakesCubit, MistakesState>(
        listener: (context, state) {
          if (state is MistakesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is MistakesLoading || state is MistakesInitial) {
            return const AppLoadingView();
          }

          if (state is MistakesPracticeSubmitting) {
            return AppLoadingView(message: l10n.submittingPractice);
          }

          if (state is MistakesPracticeCompleted) {
            return _buildResultsView(context, state.result);
          }

          if (state is MistakesError) {
            return AppErrorView(
              message: state.message,
              onRetry: () => context.read<MistakesCubit>().loadMistakes(
                    examId: widget.sourceExamId,
                    onlyUnresolved: true,
                  ),
            );
          }

          if (state is MistakesLoaded) {
            final questions = state.questions;
            if (questions.isEmpty) {
              return AppEmptyView(
                message: l10n.noMistakesFound,
                subtitle: l10n.noMistakesFoundSub,
                icon: Icons.celebration_rounded,
                actionText: l10n.backToMistakesBank,
                onAction: () => context.go(AppRoutes.studentMistakes),
              );
            }

            final currentQuestion = questions[_currentIndex];
            final total = questions.length;

            return ResponsiveContainer(
              child: Column(
                children: [
                  // Progress indicator & Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                      vertical: AppSpacing.s8,
                    ),
                    color: theme.colorScheme.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.questionProgressLabel(
                                _currentIndex + 1,
                                total,
                              ),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            Text(
                              currentQuestion.sourceExamTitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        LinearProgressIndicator(
                          value: (_currentIndex + 1) / total,
                          backgroundColor:
                              theme.colorScheme.primary.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Question Area (Scrollable)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Stem
                          if (currentQuestion.questionText.isNotEmpty) ...[
                            Text(
                              currentQuestion.questionText,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s16),
                          ],

                          // Image if present
                          if (currentQuestion.imageUrl != null &&
                              currentQuestion.imageUrl!.isNotEmpty) ...[
                            GestureDetector(
                              onTap: () => _openImageDialog(
                                context,
                                currentQuestion.imageUrl!,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMedium,
                                ),
                                child: Container(
                                  constraints:
                                      const BoxConstraints(maxHeight: 260),
                                  width: double.infinity,
                                  color: Colors.black.withValues(alpha: 0.04),
                                  child: Image.network(
                                    currentQuestion.imageUrl!,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (_, child, progress) {
                                      if (progress == null) return child;
                                      return const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(
                                            AppSpacing.s24,
                                          ),
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) => const Padding(
                                      padding: EdgeInsets.all(AppSpacing.s16),
                                      child: Icon(
                                        Icons.broken_image,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s16),
                          ],

                          // Instruction
                          Text(
                            l10n.practiceExamInstruction,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s16),

                          // Options
                          ...currentQuestion.options.map((opt) {
                            final isSelected =
                                _selectedAnswers[currentQuestion.questionId] ==
                                    opt.id;
                            return Container(
                              margin:
                                  const EdgeInsets.only(bottom: AppSpacing.s8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.08,
                                      )
                                    : theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMedium,
                                ),
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : Colors.grey.withValues(alpha: 0.25),
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                              ),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedAnswers[
                                        currentQuestion.questionId] = opt.id;
                                  });
                                },
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMedium,
                                ),
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
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
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
                    ),
                  ),

                  // Bottom Navigation Bar
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Previous Button
                        if (_currentIndex > 0)
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _currentIndex--;
                              });
                            },
                            icon: const Icon(Icons.arrow_back),
                            label: Text(l10n.previousQuestionAction),
                          )
                        else
                          const SizedBox.shrink(),

                        // Next or Submit Button
                        if (_currentIndex < total - 1)
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _currentIndex++;
                              });
                            },
                            icon: const Icon(Icons.arrow_forward),
                            label: Text(l10n.nextQuestionAction),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: _submitPractice,
                            icon: const Icon(Icons.check_circle_outline),
                            label: Text(l10n.submitPracticeExam),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s24,
                                vertical: AppSpacing.s16,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildResultsView(
    BuildContext context,
    MistakePracticeResultEntity result,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isFullyPassed = result.correctCount == result.totalQuestions;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: ResponsiveContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Result Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.s32),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                border: Border.all(
                  color: isFullyPassed
                      ? AppColors.success.withValues(alpha: 0.5)
                      : AppColors.warning.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    isFullyPassed
                        ? Icons.celebration_rounded
                        : Icons.stars_rounded,
                    size: 64,
                    color: isFullyPassed ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Text(
                    l10n.practiceResultsTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    '${result.percentage.toStringAsFixed(0)}%',
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isFullyPassed ? AppColors.success : AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    isFullyPassed
                        ? l10n.practiceSuccessSummary(
                            result.correctCount,
                            result.totalQuestions,
                          )
                        : l10n.practicePartialSummary(result.correctCount),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s24),

            // Question Details Feedback
            Text(
              l10n.examResultsTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: result.results.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.s8),
              itemBuilder: (context, index) {
                final feedback = result.results[index];
                final isCorrect = feedback.isCorrect;

                return Container(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusMedium,
                    ),
                    border: Border.all(
                      color: isCorrect
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isCorrect
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: isCorrect ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(width: AppSpacing.s16),
                      Expanded(
                        child: Text(
                          '${l10n.questionProgressLabel(index + 1, result.totalQuestions)}: ${isCorrect ? l10n.statusMastered : l10n.statusNeedsReview}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                isCorrect ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.s32),

            // Actions
            ElevatedButton.icon(
              onPressed: () => context.go(AppRoutes.studentMistakes),
              icon: const Icon(Icons.arrow_back),
              label: Text(l10n.backToMistakesBank),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
              ),
            ),
            if (!isFullyPassed) ...[
              const SizedBox(height: AppSpacing.s8),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentIndex = 0;
                    _selectedAnswers.clear();
                  });
                  context.read<MistakesCubit>().loadMistakes(
                        examId: widget.sourceExamId,
                        onlyUnresolved: true,
                      );
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.retakeMistakesPractice),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s48),
          ],
        ),
      ),
    );
  }
}
