import 'package:flutter/material.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../domain/entities/exam_entity.dart';
import '../../domain/entities/saved_question_entity.dart';
import '../widgets/exam_review_header_section.dart';
import '../widgets/exam_review_navigation_footer.dart';
import '../widgets/exam_review_question_view.dart';

class ExamReviewPage extends StatefulWidget {
  final String attemptId;
  final ExamEntity? exam;
  final ExamAttemptEntity? initialAttempt;
  final int initialQuestionIndex;

  const ExamReviewPage({
    super.key,
    required this.attemptId,
    this.exam,
    this.initialAttempt,
    this.initialQuestionIndex = 0,
  });

  @override
  State<ExamReviewPage> createState() => _ExamReviewPageState();
}

class _ExamReviewPageState extends State<ExamReviewPage> {
  ExamAttemptEntity? _attempt;
  bool _isLoading = true;
  String? _errorMessage;
  int _currentQuestionIndex = 0;
  final Set<String> _savedQuestionIds = {};

  @override
  void initState() {
    super.initState();
    _currentQuestionIndex = widget.initialQuestionIndex;
    _initSavedQuestions();
    if (widget.initialAttempt != null &&
        widget.initialAttempt!.questions.isNotEmpty) {
      _attempt = widget.initialAttempt;
      if (_currentQuestionIndex >= _attempt!.questions.length) {
        _currentQuestionIndex = 0;
      }
      _isLoading = false;
    } else {
      _loadReview();
    }
  }

  Future<void> _initSavedQuestions() async {
    try {
      final res = await InjectionContainer.savedQuestionsRepository.getSavedQuestions();
      if (res.isSuccess && res.dataOrNull != null && mounted) {
        setState(() {
          _savedQuestionIds.addAll(res.dataOrNull!.map((q) => q.questionId));
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleSaveQuestionToVault(
    ExamQuestionEntity question,
    ExamAnswerEntity? answer,
    int qIndex,
  ) async {
    final isSaved = _savedQuestionIds.contains(question.id);
    if (isSaved) {
      setState(() => _savedQuestionIds.remove(question.id));
      await InjectionContainer.savedQuestionsRepository.removeSavedQuestion(question.id);
      if (!mounted || !context.mounted) return;
      AppFeedback.showInfo(context, context.l10n.removedFromVaultSuccess);
    } else {
      setState(() => _savedQuestionIds.add(question.id));
      final correctOpt = question.options.cast<QuestionOptionEntity?>().firstWhere(
        (QuestionOptionEntity? o) => o?.isCorrect == true,
        orElse: () => null,
      );
      final isMistake = answer?.isCorrect != true;

      final saved = SavedQuestionEntity(
        id: 'sq_${question.id}',
        questionId: question.id,
        examId: widget.exam?.id ?? _attempt?.examId ?? '',
        examTitle: widget.exam?.title ?? '',
        questionText: question.questionText,
        questionImageUrl: question.imageUrl,
        options: question.options,
        savedAt: DateTime.now(),
        userAnswerOptionId: answer?.selectedOptionId,
        correctOptionId: correctOpt?.id,
        questionIndex: qIndex + 1,
        isPdfQuestion: widget.exam?.hasAttachedPdf == true,
        pdfUrl: widget.exam?.pdfStoragePath,
        isMastered: !isMistake,
        difficultyRating: isMistake
            ? QuestionDifficultyRating.hard
            : QuestionDifficultyRating.easy,
      );
      await InjectionContainer.savedQuestionsRepository.saveQuestion(saved);
      if (!mounted || !context.mounted) return;
      AppFeedback.showSuccess(context, context.l10n.savedToMistakeVaultSuccess);
    }
  }

  Future<void> _loadReview() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await InjectionContainer.examsRepository.getAttemptDetails(
      widget.attemptId,
    );

    if (!mounted) return;

    res.when(
      onSuccess: (attempt) {
        setState(() {
          _attempt = attempt;
          if (_currentQuestionIndex >= attempt.questions.length &&
              attempt.questions.isNotEmpty) {
            _currentQuestionIndex = 0;
          }
          _isLoading = false;
        });
      },
      onFailure: (failure) {
        setState(() {
          _errorMessage = failure.message;
          _isLoading = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviewExamTitle), centerTitle: true),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: AppLoadingView.signature());
    }

    if (_errorMessage != null) {
      return Center(
        child: AppErrorView(message: _errorMessage!, onRetry: _loadReview),
      );
    }

    final attempt = _attempt;
    if (attempt == null || attempt.questions.isEmpty) {
      return Center(
        child: AppEmptyView(
          message: context.l10n.noAnswersRecorded,
          icon: Icons.quiz_outlined,
        ),
      );
    }

    final questions = attempt.questions;
    final currentIndex = _currentQuestionIndex.clamp(0, questions.length - 1);
    final question = questions[currentIndex];
    final answer = attempt.answers.cast<ExamAnswerEntity?>().firstWhere(
      (a) => a?.questionId == question.id,
      orElse: () => null,
    );

    final maxScore =
        widget.exam?.maxScore ??
        questions.fold<int>(0, (sum, q) => sum + q.points);
    final passScore = widget.exam?.passingScore;
    final isPassed = attempt.isPassed(passScore);

    return Column(
      children: [
        ExamReviewHeaderSection(
          title: widget.exam?.title ?? context.l10n.reviewExamTitle,
          isPassed: isPassed,
          submissionReason: attempt.submissionReason,
          scoreText:
              '${attempt.score ?? 0} / $maxScore (${(attempt.percentage ?? 0).toStringAsFixed(1)}%)',
          questions: questions,
          answers: attempt.answers,
          currentIndex: currentIndex,
          onSelectQuestion: (idx) {
            setState(() => _currentQuestionIndex = idx);
          },
        ),
        Expanded(
          child: ExamReviewQuestionView(
            question: question,
            answer: answer,
            currentIndex: currentIndex,
            totalQuestions: questions.length,
            isSavedInVault: _savedQuestionIds.contains(question.id),
            onToggleSaveVault: () => _toggleSaveQuestionToVault(
              question,
              answer,
              currentIndex,
            ),
          ),
        ),
        ExamReviewNavigationFooter(
          currentIndex: currentIndex,
          totalQuestions: questions.length,
          onPrevious: () {
            setState(() => _currentQuestionIndex = currentIndex - 1);
          },
          onNext: () {
            setState(() => _currentQuestionIndex = currentIndex + 1);
          },
          onFinish: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
