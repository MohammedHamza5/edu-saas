import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../domain/entities/mistake_entities.dart';
import '../cubit/mistakes_cubit.dart';
import '../cubit/mistakes_state.dart';
import '../widgets/mistakes_practice_header.dart';
import '../widgets/mistakes_practice_navigation_footer.dart';
import '../widgets/mistakes_practice_question_card.dart';
import '../widgets/mistakes_practice_results_view.dart';

class MistakesPracticePage extends StatefulWidget {
  final String? sourceExamId;
  final String? typeFilter;
  final String? mode;

  const MistakesPracticePage({
    super.key,
    this.sourceExamId,
    this.typeFilter,
    this.mode,
  });

  @override
  State<MistakesPracticePage> createState() => _MistakesPracticePageState();
}

class _MistakesPracticePageState extends State<MistakesPracticePage> {
  int _currentIndex = 0;
  final Map<String, String> _selectedAnswers = {}; // questionId -> optionId
  final Map<String, List<MistakeOptionEntity>> _shuffledOptions = {};

  List<MistakeOptionEntity> _getOptionsFor(MistakeQuestionEntity question) {
    return _shuffledOptions.putIfAbsent(question.questionId, () {
      final list = List<MistakeOptionEntity>.from(question.options);
      list.shuffle();
      return list;
    });
  }

  @override
  void initState() {
    super.initState();
    context.read<MistakesCubit>().loadMistakes(
          examId: widget.sourceExamId,
          onlyUnresolved: false,
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

  void _handleRetake() {
    setState(() {
      _currentIndex = 0;
      _selectedAnswers.clear();
      _shuffledOptions.clear();
    });
    context.read<MistakesCubit>().loadMistakes(
          examId: widget.sourceExamId,
          onlyUnresolved: false,
          forceRefresh: true,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.mode == 'gauntlet'
              ? l10n.gauntletTitle
              : widget.mode == 'sprint_5'
                  ? l10n.sprintTitle
                  : widget.mode == 'resolved'
                      ? l10n.practiceModeHeaderResolved
                      : widget.mode == 'all'
                          ? l10n.practiceModeHeaderAll
                          : l10n.practiceModeHeaderUnresolved,
        ),
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
            return MistakesPracticeResultsView(
              result: state.result,
              onRetake: _handleRetake,
            );
          }

          if (state is MistakesError) {
            return AppErrorView(
              message: state.message,
              onRetry: () => context.read<MistakesCubit>().loadMistakes(
                    examId: widget.sourceExamId,
                    onlyUnresolved: false,
                  ),
            );
          }

          if (state is MistakesLoaded) {
            var questions = state.questions;
            if (widget.mode == 'resolved') {
              questions = questions.where((q) => q.isResolved).toList();
            } else if (widget.mode == 'all') {
              // all questions
            } else if (widget.mode == 'gauntlet') {
              // Zero-Mistake Gauntlet: only unresolved, sorted by most failed first
              questions = questions.where((q) => !q.isResolved).toList();
              questions.sort((a, b) => b.failureCount.compareTo(a.failureCount));
            } else if (widget.mode == 'sprint_5') {
              // 5-Question Rapid Sprint: take up to 5 questions (unresolved preferred)
              final unresolved = questions.where((q) => !q.isResolved).toList();
              questions = (unresolved.isNotEmpty ? unresolved : questions).take(5).toList();
            } else {
              // default: unresolved
              questions = questions.where((q) => !q.isResolved).toList();
            }

            if (widget.typeFilter == 'wrongOnly') {
              questions = questions.where((q) => q.isWrongAnswer).toList();
            } else if (widget.typeFilter == 'skippedOnly') {
              questions = questions.where((q) => q.isSkipped).toList();
            }

            if (questions.isEmpty) {
              return AppEmptyView(
                message: l10n.noMistakesFound,
                subtitle: l10n.noMistakesFoundSub,
                icon: Icons.celebration_rounded,
                actionText: l10n.backToMistakesBank,
                onAction: () => context.go(AppRoutes.studentMistakes),
              );
            }

            final currentQuestion =
                questions[_currentIndex.clamp(0, questions.length - 1)];
            final total = questions.length;

            return ResponsiveContainer(
              child: Column(
                children: [
                  MistakesPracticeHeader(
                    currentIndex: _currentIndex,
                    total: total,
                    mode: widget.mode,
                    currentQuestion: currentQuestion,
                  ),
                  Expanded(
                    child: MistakesPracticeQuestionCard(
                      question: currentQuestion,
                      options: _getOptionsFor(currentQuestion),
                      selectedOptionId:
                          _selectedAnswers[currentQuestion.questionId],
                      onSelectOption: (optId) {
                        setState(() {
                          _selectedAnswers[currentQuestion.questionId] = optId;
                        });
                      },
                    ),
                  ),
                  MistakesPracticeNavigationFooter(
                    currentIndex: _currentIndex,
                    total: total,
                    onPrevious: () {
                      setState(() {
                        _currentIndex--;
                      });
                    },
                    onNext: () {
                      setState(() {
                        _currentIndex++;
                      });
                    },
                    onSubmit: _submitPractice,
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
}
