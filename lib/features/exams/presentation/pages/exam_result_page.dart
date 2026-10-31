import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../content/domain/entities/content_entity.dart';
import '../../../content/domain/entities/lesson_assignment_entity.dart';
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';
import '../utils/exam_result_coordinator.dart';
import '../widgets/exam_pacing_radar_card.dart';
import '../widgets/exam_result_action_bar.dart';
import '../widgets/exam_result_hero_card.dart';
import '../widgets/exam_result_performance_kpis_grid.dart';
import '../widgets/exam_result_questions_matrix.dart';
import '../widgets/exam_result_submission_reason_card.dart';
import 'exam_review_page.dart';

class ExamResultPage extends StatefulWidget {
  final ExamEntity exam;
  final ExamAttemptEntity attempt;
  final bool? isLectureExam;
  final LessonAssignmentEntity? nextLesson;
  final int? nextLessonIndex;
  final int? totalLessonsCount;

  /// Optional builder to decouple ExamResultPage from ExamTakingPage (preventing circular dependencies).
  static Widget Function(
    BuildContext context,
    ExamsCubit cubit,
    bool isLecture,
    LessonAssignmentEntity? nextLesson,
    int? nextLessonIndex,
    int? totalLessonsCount,
  )? retakeBuilder;

  const ExamResultPage({
    super.key,
    required this.exam,
    required this.attempt,
    this.isLectureExam,
    this.nextLesson,
    this.nextLessonIndex,
    this.totalLessonsCount,
  });

  @override
  State<ExamResultPage> createState() => _ExamResultPageState();
}

class _ExamResultPageState extends State<ExamResultPage> {
  late ExamAttemptEntity _attempt;
  LessonAssignmentEntity? _nextLesson;
  int? _nextLessonIndex;
  int? _totalLessonsCount;
  bool _isLoadingNextLesson = false;
  bool _isLoadingDetails = false;
  bool _isRetaking = false;
  ExamsCubit? _examsCubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      _examsCubit ??= context.read<ExamsCubit>();
    } catch (_) {}
  }

  @override
  void dispose() {
    _examsCubit?.exitExamTaking();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _attempt = widget.attempt;
    _nextLesson = widget.nextLesson;
    _nextLessonIndex = widget.nextLessonIndex;
    _totalLessonsCount = widget.totalLessonsCount;

    // Defense-in-depth: Ensure nextLesson is strictly a video lecture and not self/exam
    if (_nextLesson != null) {
      if (_nextLesson!.type != ContentType.video ||
          _nextLesson!.contentId == widget.exam.linkedLessonId ||
          _nextLesson!.lessonExamId == widget.exam.id ||
          _nextLesson!.attachedExams.any((e) => e.examId == widget.exam.id)) {
        _nextLesson = null;
        _nextLessonIndex = null;
      }
    }

    final isLecture = widget.isLectureExam ??
        (widget.exam.isLectureExam || widget.exam.isLinkedToLesson);
    final isPassed = _attempt.isPassed(widget.exam.passingScore);

    if (isLecture &&
        isPassed &&
        _nextLesson == null &&
        widget.exam.groupId.isNotEmpty) {
      _fetchNextLesson();
    }

    // If questions or answers are missing, fetch with loading indicator.
    // If questions are already available (passed from taking page), fetch silently in background
    // without blocking or freezing the answer sheet matrix UI!
    if (_attempt.questions.isEmpty || _attempt.answers.isEmpty) {
      _fetchAttemptDetails(showLoading: true);
    } else {
      _fetchAttemptDetails(showLoading: false);
    }
  }

  Future<void> _fetchAttemptDetails({bool showLoading = false}) async {
    if (showLoading) {
      setState(() => _isLoadingDetails = true);
    }
    try {
      final res = await InjectionContainer.examsRepository.getAttemptDetails(
        _attempt.id,
      );
      if (!mounted) return;
      if (res.isSuccess && res.dataOrNull != null) {
        setState(() {
          final fresh = res.dataOrNull!;
          _attempt = fresh.copyWith(
            questions: fresh.questions.isNotEmpty
                ? fresh.questions
                : _attempt.questions,
            answers: fresh.answers.isNotEmpty
                ? fresh.answers
                : _attempt.answers,
          );
          _isLoadingDetails = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted && showLoading) {
      setState(() => _isLoadingDetails = false);
    }
  }

  Future<void> _fetchNextLesson() async {
    setState(() => _isLoadingNextLesson = true);
    final info = await ExamResultCoordinator.fetchNextLesson(
      exam: widget.exam,
      studentId: SupabaseService.currentUserId,
    );
    if (!mounted) return;
    if (info != null) {
      setState(() {
        _nextLesson = info.nextLesson;
        _nextLessonIndex = info.nextLessonIndex;
        _totalLessonsCount = info.totalLessonsCount;
        _isLoadingNextLesson = false;
      });
    } else {
      setState(() => _isLoadingNextLesson = false);
    }
  }

  void _goToNextLesson(LessonAssignmentEntity nextLesson) {
    ExamResultCoordinator.goToNextLesson(
      context,
      nextLesson: nextLesson,
      exam: widget.exam,
      nextLessonIndex: _nextLessonIndex,
      totalLessonsCount: _totalLessonsCount,
      examsCubit: _examsCubit,
    );
  }

  void _goToLecturesScreen() {
    ExamResultCoordinator.goToLecturesScreen(
      context,
      exam: widget.exam,
      examsCubit: _examsCubit,
    );
  }

  Future<void> _handleRetake() async {
    if (_isRetaking) return;
    setState(() => _isRetaking = true);

    final isLecture = widget.isLectureExam ??
        (widget.exam.isLectureExam || widget.exam.isLinkedToLesson);

    ExamsCubit cubit;
    try {
      cubit = context.read<ExamsCubit>();
    } catch (_) {
      cubit = InjectionContainer.createExamsCubit();
    }

    try {
      final success = await cubit.startExamTaking(
        widget.exam,
        isLectureExam: isLecture,
      );

      if (!mounted) return;

      if (success) {
        if (ExamResultPage.retakeBuilder != null) {
          unawaited(
            Navigator.of(context).pushReplacement<void, void>(
              MaterialPageRoute<void>(
                builder: (ctx) => ExamResultPage.retakeBuilder!(
                  ctx,
                  cubit,
                  isLecture,
                  _nextLesson,
                  _nextLessonIndex,
                  _totalLessonsCount,
                ),
              ),
            ),
          );
        } else {
          Navigator.of(context).pop();
        }
      } else {
        final errorMsg = cubit.state is ExamsError
            ? (cubit.state as ExamsError).message
            : context.l10n.errorOccurred;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRetaking = false);
      }
    }
  }

  void _openReview({int initialQuestionIndex = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExamReviewPage(
          attemptId: _attempt.id,
          exam: widget.exam,
          initialAttempt: _attempt,
          initialQuestionIndex: initialQuestionIndex,
        ),
      ),
    );
  }

  void _openPdfBooklet() {
    ExamResultCoordinator.openPdfBooklet(context, exam: widget.exam);
  }

  @override
  Widget build(BuildContext context) {
    final isLecture = widget.isLectureExam ??
        (widget.exam.isLectureExam || widget.exam.isLinkedToLesson);
    final stats = ExamResultStats.calculate(
      exam: widget.exam,
      attempt: _attempt,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _examsCubit?.exitExamTaking();
        if (isLecture) {
          _goToLecturesScreen();
        } else {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go(AppRoutes.studentExams);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.examResultTitle),
          centerTitle: true,
          actions: [
            if (widget.exam.hasAttachedPdf)
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded),
                tooltip: context.l10n.viewExamBooklet,
                onPressed: _openPdfBooklet,
              ),
          ],
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: isLecture
                ? context.l10n.backToLecturesList
                : context.l10n.backToExamsList,
            onPressed: () {
              _examsCubit?.exitExamTaking();
              if (isLecture) {
                _goToLecturesScreen();
              } else {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go(AppRoutes.studentExams);
                }
              }
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Hero Performance & Verdict Card
              ExamResultHeroCard(
                examTitle: widget.exam.title,
                score: stats.score,
                maxScore: stats.maxScore,
                percentage: stats.percentage,
                isPassed: stats.isPassed,
                passingScore: stats.passingScore,
              ),

              const SizedBox(height: AppSpacing.s16),

              // 2. Submission Details & Reason Banner
              ExamResultSubmissionReasonCard(
                attempt: _attempt,
              ),

              const SizedBox(height: AppSpacing.s16),

              // 3. Performance Micro-KPIs Grid
              ExamResultPerformanceKpisGrid(
                correctCount: stats.correctCount,
                incorrectCount: stats.incorrectCount,
                skippedCount: stats.skippedCount,
                duration: stats.duration,
                exam: widget.exam,
              ),

              // Pacing & Time Radar Analysis
              if (_attempt.questionTimes.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s16),
                ExamPacingRadarCard(
                  questionTimes: _attempt.questionTimes,
                  flaggedGuesses: _attempt.flaggedGuesses,
                  totalQuestions: stats.totalQuestions,
                ),
              ],

              const SizedBox(height: AppSpacing.s16),

              // 4. Interactive Answer Sheet Matrix
              ExamResultQuestionsMatrix(
                questions: _attempt.questions,
                answers: _attempt.answers,
                attemptId: _attempt.id,
                isLoadingDetails: _isLoadingDetails,
                hasAttachedPdf: widget.exam.hasAttachedPdf,
                onOpenReview: (idx) => _openReview(initialQuestionIndex: idx),
                onOpenPdfBooklet: _openPdfBooklet,
              ),

              const SizedBox(height: AppSpacing.s24),

              // 5. Contextual Action Bar
              ExamResultActionBar(
                isLecture: isLecture,
                isPassed: stats.isPassed,
                hasAttachedPdf: widget.exam.hasAttachedPdf,
                allowRetake: widget.exam.allowRetake,
                isLoadingNextLesson: _isLoadingNextLesson,
                isRetaking: _isRetaking,
                nextLesson: _nextLesson,
                onNextLesson: () => _goToNextLesson(_nextLesson!),
                onOpenPdfBooklet: _openPdfBooklet,
                onReview: () => _openReview(),
                onRetake: _handleRetake,
                onBack: () {
                  _examsCubit?.exitExamTaking();
                  if (isLecture) {
                    _goToLecturesScreen();
                  } else {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      context.go(AppRoutes.studentExams);
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
