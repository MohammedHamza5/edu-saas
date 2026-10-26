import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/utils/exam_security_util.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../content/domain/entities/lesson_assignment_entity.dart';
import '../../domain/entities/exam_entity.dart';
import '../../domain/entities/saved_question_entity.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';
import '../utils/exam_asset_preloader.dart';
import '../widgets/bluebook/bluebook_review_grid_modal.dart';
import '../widgets/desmos_embed_view.dart';
import '../widgets/dock/exam_adaptive_tools_pane.dart';
import '../widgets/dock/exam_dock_state.dart';
import '../widgets/exam_taking_app_bar.dart';
import '../widgets/exam_taking_overlays.dart';
import '../widgets/exam_taking_pdf_booklet.dart';
import '../widgets/exam_taking_questions_view.dart';
import '../widgets/exam_taking_submission_dialogs.dart';
import '../widgets/scratchpad/exam_scratchpad_overlay.dart';
import 'exam_result_page.dart';

class ExamTakingPage extends StatefulWidget {
  final bool isLectureExam;
  final LessonAssignmentEntity? nextLesson;
  final int? nextLessonIndex;
  final int? totalLessonsCount;

  const ExamTakingPage({
    super.key,
    this.isLectureExam = false,
    this.nextLesson,
    this.nextLessonIndex,
    this.totalLessonsCount,
  });

  @override
  State<ExamTakingPage> createState() => _ExamTakingPageState();
}

class _ExamTakingPageState extends State<ExamTakingPage>
    with WidgetsBindingObserver {
  int _securityViolationsCount = 0;
  bool _isPrivacyShieldActive = false;
  bool _isAutoSubmitting = false;
  ExamDockMode _dockMode = ExamDockMode.hidden;
  ExamDockTab _dockTab = ExamDockTab.calculator;
  DesmosCalculatorMode _desmosMode = DesmosCalculatorMode.graphing;
  bool _hasOpenedToolsEver = false;
  bool _showMobilePdfOverlay = false;
  bool _showDesktopPdfPane = true;
  static const int _maxAllowedViolations = 3;
  final ExamAssetPreloader _assetPreloader = ExamAssetPreloader();
  final Set<String> _savedQuestionIds = {};
  double? _customDockWidth;
  bool _isDraggingDockSplitter = false;

  @override
  void initState() {
    super.initState();
    ExamResultPage.retakeBuilder = (
      ctx,
      cubit,
      isLecture,
      nextLesson,
      nextIndex,
      totalCount,
    ) =>
        BlocProvider.value(
          value: cubit,
          child: ExamTakingPage(
            isLectureExam: isLecture,
            nextLesson: nextLesson,
            nextLessonIndex: nextIndex,
            totalLessonsCount: totalCount,
          ),
        );
    WidgetsBinding.instance.addObserver(this);
    setExamSecurityActive(true);
    _initSavedQuestions();
  }

  Future<void> _initSavedQuestions() async {
    try {
      final res =
          await InjectionContainer.savedQuestionsRepository.getSavedQuestions();
      if (res.isSuccess && res.dataOrNull != null && mounted) {
        setState(() {
          _savedQuestionIds.addAll(res.dataOrNull!.map((q) => q.questionId));
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _assetPreloader.dispose();
    setExamSecurityActive(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isPrivacyShieldActive && mounted) {
        setState(() {
          _isPrivacyShieldActive = false;
        });
      }
      return;
    }

    final isViolation =
        state == AppLifecycleState.hidden || state == AppLifecycleState.paused;

    if (isViolation) {
      if (!_isAutoSubmitting && mounted) {
        final cubit = context.read<ExamsCubit>();
        final currentState = cubit.state;
        if (currentState is ExamTakingState &&
            !currentState.isSubmitting &&
            !currentState.submitSuccess) {
          if (currentState.isUntimed || widget.isLectureExam) {
            return;
          }

          if (!_isPrivacyShieldActive) {
            setState(() {
              _isPrivacyShieldActive = true;
              _securityViolationsCount++;
            });

            if (_securityViolationsCount >= _maxAllowedViolations) {
              _isAutoSubmitting = true;
              cubit.submitExam(reason: ExamSubmissionReason.securityViolations);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.examAutoSubmittedDueToViolations),
                  backgroundColor: AppColors.error,
                  duration: const Duration(seconds: 5),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.examSecurityWarningSubtitle),
                  backgroundColor: AppColors.warning,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        }
      }
    }
  }

  void _confirmForcedExit(BuildContext context, ExamTakingState state) {
    ExamTakingSubmissionDialogs.confirmForcedExit(
      context,
      state: state,
      onConfirm: () {
        setState(() {
          _isAutoSubmitting = true;
        });
        context.read<ExamsCubit>().submitExam(
              reason: ExamSubmissionReason.forcedExit,
            );
      },
    );
  }

  void _confirmSubmit(BuildContext context, ExamTakingState state) {
    ExamTakingSubmissionDialogs.confirmSubmit(
      context,
      state: state,
      onConfirm: () {
        context.read<ExamsCubit>().submitExam(
              reason: ExamSubmissionReason.studentSubmitted,
            );
      },
    );
  }

  Future<void> _toggleCurrentQuestionVault(
    BuildContext context,
    ExamTakingState state,
  ) async {
    final q = state.currentQuestion;
    final isSaved = _savedQuestionIds.contains(q.id);

    if (isSaved) {
      setState(() => _savedQuestionIds.remove(q.id));
      await InjectionContainer.savedQuestionsRepository.removeSavedQuestion(q.id);
      if (context.mounted) {
        AppFeedback.showInfo(context, context.l10n.removedFromVaultSuccess);
      }
    } else {
      setState(() => _savedQuestionIds.add(q.id));
      final saved = SavedQuestionEntity(
        id: 'sq_${q.id}',
        questionId: q.id,
        examId: state.exam.id,
        examTitle: state.exam.title,
        questionText: q.questionText,
        questionImageUrl: q.imageUrl,
        options: q.options,
        savedAt: DateTime.now(),
        questionIndex: state.currentQuestionIndex + 1,
        isPdfQuestion: state.exam.hasAttachedPdf,
        pdfUrl: state.exam.pdfStoragePath,
      );
      await InjectionContainer.savedQuestionsRepository.saveQuestion(saved);
      if (context.mounted) {
        AppFeedback.showSuccess(context, context.l10n.savedToVaultSuccess);
      }
    }
  }

  void _openBluebookReviewGrid(BuildContext context, ExamTakingState state) {
    if (state.isSubmitting) return;
    final answeredIndices = <int>{};
    final flaggedIndices = <int>{};
    for (int i = 0; i < state.questions.length; i++) {
      final qId = state.questions[i].id;
      if (state.answers.containsKey(qId)) {
        answeredIndices.add(i);
      }
      if (state.flaggedGuesses.contains(qId)) {
        flaggedIndices.add(i);
      }
    }

    BluebookReviewGridModal.show(
      context,
      totalQuestions: state.questions.length,
      currentQuestionIndex: state.currentQuestionIndex,
      answeredIndices: answeredIndices,
      flaggedIndices: flaggedIndices,
      onQuestionSelected: (idx) {
        context.read<ExamsCubit>().goToQuestion(idx);
      },
      onConfirmFinish: () => _confirmSubmit(context, state),
    );
  }

  Widget _buildQuestionsViewWidget(
    BuildContext context,
    ExamTakingState state,
    int qIndex,
    ExamQuestionEntity question, {
    required bool isDesktop,
  }) {
    return ExamTakingQuestionsView(
      state: state,
      questionIndex: qIndex,
      question: question,
      isDesktop: isDesktop,
      showDesktopPdfPane: _showDesktopPdfPane,
      onOpenPdfBooklet: () {
        setState(() {
          if (isDesktop) {
            _showDesktopPdfPane = true;
          } else {
            _showMobilePdfOverlay = true;
          }
        });
      },
      onToggleFlagGuess: () =>
          context.read<ExamsCubit>().toggleFlagGuess(question.id),
      onToggleVault: () => _toggleCurrentQuestionVault(context, state),
      onSelectOption: (optionId) {
        context.read<ExamsCubit>().selectAnswer(question.id, optionId);
      },
      onToggleEliminateOption: (optionId) {
        context.read<ExamsCubit>().toggleEliminateOption(question.id, optionId);
      },
      onPrevious: () => context.read<ExamsCubit>().goToQuestion(qIndex - 1),
      onNext: () => context.read<ExamsCubit>().goToQuestion(qIndex + 1),
      onReviewGrid: () => _openBluebookReviewGrid(context, state),
      onSubmit: () => _confirmSubmit(context, state),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExamsCubit, ExamsState>(
      listenWhen: (previous, current) {
        if (previous.runtimeType != current.runtimeType) return true;
        if (previous is ExamTakingState && current is ExamTakingState) {
          return previous.currentQuestionIndex !=
                  current.currentQuestionIndex ||
              previous.submitSuccess != current.submitSuccess ||
              previous.errorMessage != current.errorMessage;
        }
        return true;
      },
      listener: (context, state) {
        if (state is ExamTakingState) {
          _assetPreloader.startOrUpdate(
            context: context,
            questions: state.questions,
            currentIndex: state.currentQuestionIndex,
          );
          if (state.submitSuccess && state.submitResult != null) {
            Navigator.of(context).pushReplacement<void, void>(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider.value(
                  value: context.read<ExamsCubit>(),
                  child: ExamResultPage(
                    exam: state.exam,
                    attempt: state.submitResult!.copyWith(
                      questions: state.questions,
                      answers: state.submitResult!.answers.isNotEmpty
                          ? state.submitResult!.answers
                          : state.answers.entries
                              .map(
                                (e) => ExamAnswerEntity(
                                  id: '',
                                  attemptId: state.submitResult!.id,
                                  questionId: e.key,
                                  selectedOptionId: e.value,
                                  answeredAt: DateTime.now(),
                                ),
                              )
                              .toList(),
                    ),
                    isLectureExam:
                        widget.isLectureExam ||
                        state.exam.isLectureExam ||
                        state.exam.isLinkedToLesson,
                    nextLesson: widget.nextLesson,
                    nextLessonIndex: widget.nextLessonIndex,
                    totalLessonsCount: widget.totalLessonsCount,
                  ),
                ),
              ),
            );
          } else if (state.errorMessage != null) {
            AppFeedback.showError(context, state.errorMessage!);
          }
        }
      },
      buildWhen: (previous, current) {
        if (previous.runtimeType != current.runtimeType) return true;
        if (previous is ExamTakingState && current is ExamTakingState) {
          return previous.currentQuestionIndex !=
                  current.currentQuestionIndex ||
              previous.answers != current.answers ||
              previous.answeredCount != current.answeredCount ||
              previous.isSubmitting != current.isSubmitting ||
              previous.submitSuccess != current.submitSuccess;
        }
        return true;
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
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 56,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || state.isSubmitting) return;
            _confirmForcedExit(context, state);
          },
          child: Scaffold(
            appBar: ExamTakingAppBar(
              title: state.exam.title,
              hasAttachedPdf: state.exam.hasAttachedPdf,
              isPdfActive: _showMobilePdfOverlay || _showDesktopPdfPane,
              onTogglePdf: () {
                final isDesktop = MediaQuery.of(context).size.width >= 900;
                setState(() {
                  if (isDesktop) {
                    _showDesktopPdfPane = !_showDesktopPdfPane;
                  } else {
                    _showMobilePdfOverlay = !_showMobilePdfOverlay;
                  }
                });
              },
              isScratchpadOpen: state.isScratchpadOpen,
              onToggleScratchpad: () =>
                  context.read<ExamsCubit>().toggleScratchpad(),
              isFormulaActive: _dockMode.isVisible && _dockTab.isFormulas,
              onToggleFormula: () {
                final isDesktop = MediaQuery.of(context).size.width >= 900;
                setState(() {
                  _hasOpenedToolsEver = true;
                  if (_dockMode.isVisible && _dockTab.isFormulas) {
                    _dockMode = ExamDockMode.hidden;
                  } else {
                    _dockMode = isDesktop
                        ? ExamDockMode.docked
                        : ExamDockMode.floating;
                    _dockTab = ExamDockTab.formulas;
                  }
                });
              },
              isCalculatorActive: _dockMode.isVisible && _dockTab.isCalculator,
              onToggleCalculator: () {
                final isDesktop = MediaQuery.of(context).size.width >= 900;
                setState(() {
                  _hasOpenedToolsEver = true;
                  if (_dockMode.isVisible && _dockTab.isCalculator) {
                    _dockMode = ExamDockMode.hidden;
                  } else {
                    _dockMode = isDesktop
                        ? ExamDockMode.docked
                        : ExamDockMode.floating;
                    _dockTab = ExamDockTab.calculator;
                  }
                });
              },
              isQuestionSaved: _savedQuestionIds.contains(state.currentQuestion.id),
              isSubmitting: state.isSubmitting,
              onToggleVault: () => _toggleCurrentQuestionVault(context, state),
              onOpenReviewGrid: () => _openBluebookReviewGrid(context, state),
            ),
            floatingActionButton: (MediaQuery.of(context).size.width < 900 &&
                    state.exam.hasAttachedPdf &&
                    !_showMobilePdfOverlay &&
                    !state.isSubmitting)
                ? FloatingActionButton.extended(
                    onPressed: () {
                      setState(() {
                        _showMobilePdfOverlay = true;
                      });
                    },
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: Text(context.l10n.viewExamBooklet),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  )
                : null,
            body: Stack(
              fit: StackFit.expand,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 900;
                    final defaultDockWidth =
                        (constraints.maxWidth * 0.38).clamp(380.0, 560.0);
                    const minDockWidth = 320.0;
                    final maxDockWidth = constraints.maxWidth * 0.65;
                    final dockWidth = (_customDockWidth ?? defaultDockWidth)
                        .clamp(minDockWidth, maxDockWidth);
                    final isDocked = isDesktop && _dockMode.isDocked;
                    final rightPadding = isDocked ? dockWidth : 0.0;

                    Widget mainContent;
                    if (isDesktop &&
                        state.exam.hasAttachedPdf &&
                        _showDesktopPdfPane) {
                      mainContent = Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 52,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.s16,
                                    vertical: AppSpacing.s8,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: AppColors.surface,
                                    border: Border(
                                      bottom:
                                          BorderSide(color: AppColors.border),
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
                                          state.exam.pdfFileName ??
                                              state.exam.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.close_fullscreen_rounded,
                                          size: 18,
                                        ),
                                        tooltip: context.l10n.hideExamBooklet,
                                        onPressed: () {
                                          setState(() {
                                            _showDesktopPdfPane = false;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: ExamTakingPdfBooklet(
                                    exam: state.exam,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, color: AppColors.border),
                          Expanded(
                            flex: 48,
                            child: _buildQuestionsViewWidget(
                              context,
                              state,
                              qIndex,
                              question,
                              isDesktop: true,
                            ),
                          ),
                        ],
                      );
                    } else {
                      mainContent = Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildQuestionsViewWidget(
                            context,
                            state,
                            qIndex,
                            question,
                            isDesktop: isDesktop,
                          ),
                          if (!isDesktop &&
                              state.exam.hasAttachedPdf &&
                              _showMobilePdfOverlay)
                            ExamTakingPdfBooklet(
                              exam: state.exam,
                              isMobileOverlay: true,
                              currentQuestionIndex: qIndex,
                              totalQuestions: state.totalQuestions,
                              onCloseMobileOverlay: () {
                                setState(() {
                                  _showMobilePdfOverlay = false;
                                });
                              },
                            ),
                        ],
                      );
                    }

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          right: rightPadding,
                          child: mainContent,
                        ),
                        if (_hasOpenedToolsEver)
                          ExamAdaptiveToolsPane(
                            dockMode: _dockMode,
                            activeTab: _dockTab,
                            desmosMode: _desmosMode,
                            onDockModeChanged: (mode) =>
                                setState(() => _dockMode = mode),
                            onTabChanged: (tab) =>
                                setState(() => _dockTab = tab),
                            onDesmosModeChanged: (mode) =>
                                setState(() => _desmosMode = mode),
                            dockWidth: dockWidth,
                            isDesktop: isDesktop,
                            parentSize: Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            ),
                          ),
                        if (isDocked)
                          Positioned(
                            right: dockWidth - 6,
                            top: 0,
                            bottom: 0,
                            width: 12,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.resizeColumn,
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onHorizontalDragStart: (_) => setState(
                                    () => _isDraggingDockSplitter = true),
                                onHorizontalDragEnd: (_) => setState(
                                    () => _isDraggingDockSplitter = false),
                                onHorizontalDragCancel: () => setState(
                                    () => _isDraggingDockSplitter = false),
                                onHorizontalDragUpdate: (details) {
                                  setState(() {
                                    final cur =
                                        _customDockWidth ?? defaultDockWidth;
                                    _customDockWidth = (cur - details.delta.dx)
                                        .clamp(minDockWidth, maxDockWidth);
                                  });
                                },
                                child: Container(
                                  color: Colors.transparent,
                                  child: Center(
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 100),
                                      width: _isDraggingDockSplitter ? 4 : 2,
                                      decoration: BoxDecoration(
                                        color: _isDraggingDockSplitter
                                            ? AppColors.primary
                                            : AppColors.border
                                                .withValues(alpha: 0.8),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                // Digital Scratchpad Overlay (Transparent or Grid paper canvas)
                const ExamScratchpadOverlay(),
                if (state.isSubmitting)
                  const ExamSubmittingBlockingOverlay()
                else if (_isPrivacyShieldActive)
                  ExamPrivacyShieldOverlay(
                    isAutoSubmitting: _isAutoSubmitting,
                    securityViolationsCount: _securityViolationsCount,
                    maxAllowedViolations: _maxAllowedViolations,
                    onReturnToExam: () {
                      setState(() {
                        _isPrivacyShieldActive = false;
                      });
                    },
                  )
                else if (state.isExpired ||
                    (!state.isUntimed &&
                        state.remainingSeconds <= 0 &&
                        state.isSubmitting))
                  const ExamTimeExpiredOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }
}
