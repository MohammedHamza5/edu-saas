import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/cache_manager.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../content/domain/entities/content_entity.dart';
import '../../../content/domain/entities/file_attachment_entity.dart';
import '../../../content/domain/entities/lesson_assignment_entity.dart';
import '../../../content/presentation/widgets/material_viewer_sheet.dart';
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';
import 'exam_review_page.dart';
import 'exam_taking_page.dart';

class ExamResultPage extends StatefulWidget {
  final ExamEntity exam;
  final ExamAttemptEntity attempt;
  final bool? isLectureExam;
  final LessonAssignmentEntity? nextLesson;
  final int? nextLessonIndex;
  final int? totalLessonsCount;

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
    try {
      final res = await InjectionContainer.contentRepository
          .getGroupCourseProgress(
            groupId: widget.exam.groupId,
            studentId: InjectionContainer.supabaseClient.auth.currentUser?.id,
          );
      if (!mounted) return;
      if (res.isSuccess && res.dataOrNull != null) {
        final allLessons = res.dataOrNull!;
        // Filter strictly to video lectures so exams never appear as lectures
        final videoLessons = allLessons
            .where((l) => l.type == ContentType.video)
            .toList();
        if (videoLessons.isNotEmpty) {
          final cIdx = videoLessons.indexWhere(
            (l) =>
                (widget.exam.linkedLessonId != null &&
                    l.contentId == widget.exam.linkedLessonId) ||
                l.lessonExamId == widget.exam.id ||
                l.attachedExams.any((e) => e.examId == widget.exam.id),
          );
          if (cIdx >= 0 && cIdx < videoLessons.length - 1) {
            final next = videoLessons[cIdx + 1];
            if (next.contentId != widget.exam.linkedLessonId &&
                next.lessonExamId != widget.exam.id &&
                !next.attachedExams.any((e) => e.examId == widget.exam.id)) {
              setState(() {
                _nextLesson = next;
                _nextLessonIndex = cIdx + 2;
                _totalLessonsCount = videoLessons.length;
                _isLoadingNextLesson = false;
              });
              return;
            }
          }
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoadingNextLesson = false);
    }
  }

  void _goToNextLesson(LessonAssignmentEntity nextLesson) {
    AppCache.content.clear();
    AppCache.exams.clear();
    _examsCubit?.exitExamTaking();

    final encodedTitle = nextLesson.lessonExamTitle != null
        ? Uri.encodeComponent(nextLesson.lessonExamTitle!)
        : '';
    final encodedGroupName = widget.exam.groupName != null
        ? Uri.encodeComponent(widget.exam.groupName!)
        : '';
    final lIdx = _nextLessonIndex ?? nextLesson.sortOrder;
    final tLessons = _totalLessonsCount ?? 1;

    context.go(
      '${AppRoutes.videoPlayer}?id=${nextLesson.contentId}&associatedExamId=${nextLesson.lessonExamId ?? ''}&associatedExamTitle=$encodedTitle&groupId=${widget.exam.groupId}&groupName=$encodedGroupName&lessonIndex=$lIdx&totalLessons=$tLessons',
    );
  }

  void _goToLecturesScreen() {
    AppCache.content.clear();
    AppCache.exams.clear();
    _examsCubit?.exitExamTaking();

    if (widget.exam.groupId.isNotEmpty) {
      context.go('/student/groups/${widget.exam.groupId}/content');
    } else {
      context.go(AppRoutes.studentDashboard);
    }
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
        unawaited(
          Navigator.of(context).pushReplacement<void, void>(
            MaterialPageRoute<void>(
              builder: (_) => BlocProvider.value(
                value: cubit,
                child: ExamTakingPage(
                  isLectureExam: isLecture,
                  nextLesson: _nextLesson,
                  nextLessonIndex: _nextLessonIndex,
                  totalLessonsCount: _totalLessonsCount,
                ),
              ),
            ),
          ),
        );
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
    if (!widget.exam.hasAttachedPdf) return;
    final file = FileAttachmentEntity(
      id: widget.exam.pdfFileId ?? '',
      tenantId: widget.exam.tenantId,
      contentId: widget.exam.id,
      storagePath: widget.exam.pdfStoragePath!,
      fileName: widget.exam.pdfFileName ?? 'exam_booklet.pdf',
      mimeType: 'application/pdf',
      fileSize: widget.exam.pdfFileSize ?? 0,
      createdAt: DateTime.now(),
    );
    final content = ContentEntity(
      id: widget.exam.id,
      tenantId: widget.exam.tenantId,
      title: widget.exam.pdfFileName ?? widget.exam.title,
      type: ContentType.pdf,
      status: ContentStatus.published,
      sortOrder: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      file: file,
    );

    MaterialViewerSheet.show(
      context,
      content: content,
      onGetSignedUrl: (path) => context.read<ExamsCubit>().getSignedPdfUrl(
            path,
            storageProvider: widget.exam.pdfStorageProvider,
          ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    if (d.inHours > 0) {
      final hours = d.inHours;
      return '${hours.toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _getSubmissionExplanation(
    BuildContext context,
    ExamSubmissionReason reason,
  ) {
    switch (reason) {
      case ExamSubmissionReason.studentSubmitted:
        return context.l10n.submissionExplanationStudent;
      case ExamSubmissionReason.timeExpired:
        return context.l10n.submissionExplanationTimeout;
      case ExamSubmissionReason.forcedExit:
        return context.l10n.submissionExplanationForcedExit;
      case ExamSubmissionReason.securityViolations:
        return context.l10n.submissionExplanationViolations;
      case ExamSubmissionReason.tabClosed:
        return context.l10n.submissionExplanationTabClosed;
      case ExamSubmissionReason.systemTimeout:
        return context.l10n.submissionExplanationSystem;
    }
  }

  _GradeTier _getGradeTier(BuildContext context, double percentage, bool isPassed) {
    if (percentage >= 90) {
      return _GradeTier(
        label: context.l10n.performanceGradeExcellent,
        color: AppColors.success,
        icon: Icons.military_tech_rounded,
        badgeText: '90%+',
      );
    } else if (percentage >= 80) {
      return _GradeTier(
        label: context.l10n.performanceGradeVeryGood,
        color: const Color(0xFF2563EB),
        icon: Icons.star_rounded,
        badgeText: '80%+',
      );
    } else if (percentage >= 70) {
      return _GradeTier(
        label: context.l10n.performanceGradeGood,
        color: const Color(0xFF0D9488),
        icon: Icons.thumb_up_alt_rounded,
        badgeText: '70%+',
      );
    } else if (isPassed) {
      return _GradeTier(
        label: context.l10n.performanceGradePass,
        color: AppColors.success,
        icon: Icons.check_circle_rounded,
        badgeText: 'PASS',
      );
    } else {
      return _GradeTier(
        label: context.l10n.performanceGradeNeedsImprovement,
        color: AppColors.error,
        icon: Icons.trending_up_rounded,
        badgeText: 'RETRY',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLecture = widget.isLectureExam ??
        (widget.exam.isLectureExam || widget.exam.isLinkedToLesson);
    final score = _attempt.score ?? 0;
    final maxScore = widget.exam.maxScore > 0 ? widget.exam.maxScore : 100;
    final passingScore = widget.exam.passingScore;
    final isPassed = _attempt.isPassed(passingScore);

    final percentage = _attempt.percentage ??
        (maxScore > 0 ? (score / maxScore) * 100 : 0.0);
    final gradeTier = _getGradeTier(context, percentage, isPassed);

    final questions = _attempt.questions;
    final answers = _attempt.answers;
    final totalQuestions = questions.isNotEmpty
        ? questions.length
        : (widget.exam.totalQuestions > 0
            ? widget.exam.totalQuestions
            : _attempt.answeredCount);

    final correctCount = answers.where((a) => a.isCorrect == true).length;
    final incorrectCount =
        answers.where((a) => a.selectedOptionId != null && a.isCorrect == false).length;
    final answeredCount =
        answers.where((a) => a.selectedOptionId != null).length;
    final skippedCount = (totalQuestions > answeredCount)
        ? (totalQuestions - answeredCount)
        : 0;

    final duration = _attempt.submittedAt?.difference(_attempt.startedAt);

    final dateFormat = DateFormat('yyyy/MM/dd - hh:mm a');

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
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.s20),
                child: Column(
                  children: [
                    // Top Icon & Grade Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s12,
                            vertical: AppSpacing.s6,
                          ),
                          decoration: BoxDecoration(
                            color: gradeTier.color.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusFull),
                            border: Border.all(
                              color: gradeTier.color.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                gradeTier.icon,
                                color: gradeTier.color,
                                size: 16,
                              ),
                              const SizedBox(width: AppSpacing.s6),
                              Text(
                                gradeTier.label,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: gradeTier.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    // Verdict Title
                    Text(
                      isPassed
                          ? context.l10n.congratulationsPassed
                          : context.l10n.sorryNotPassed,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: isPassed ? AppColors.success : AppColors.error,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),

                    Text(
                      widget.exam.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.s20),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: AppSpacing.s20),

                    // Prominent Academic Score Typography
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$score',
                          style: TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            color:
                                isPassed ? AppColors.success : AppColors.error,
                          ),
                        ),
                        Text(
                          ' / $maxScore',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.s4),

                    // Percentage & Pass Status
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s12,
                        vertical: AppSpacing.s4,
                      ),
                      decoration: BoxDecoration(
                        color: (isPassed ? AppColors.success : AppColors.error)
                            .withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSmall),
                      ),
                      child: Text(
                        context.l10n.percentageLabel(
                          percentage.toStringAsFixed(1),
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isPassed ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.s16),

                    // Linear Passing Indicator Bar
                    if (passingScore != null) ...[
                      Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (maxScore > 0 ? (score / maxScore) : 0.0)
                                  .clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor: AppColors.surfaceVariant,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isPassed ? AppColors.success : AppColors.error,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.l10n.requiredPassingScore(
                                  passingScore,
                                  maxScore,
                                ),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              Text(
                                context.l10n.passingThresholdLabel(
                                  ((passingScore / maxScore) * 100).round(),
                                ),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: isPassed
                                      ? AppColors.success
                                      : AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: AppSpacing.s16),

                    // Subtitle message (Guidance & next steps)
                    Text(
                      isPassed
                          ? context.l10n.examPassedSubtitle
                          : context.l10n.examFailedSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.s16),

              // 2. Submission Details & Reason Banner
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.s8),
                          decoration: BoxDecoration(
                            color: _attempt.submissionReason.color
                                .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _attempt.submissionReason.icon,
                            color: _attempt.submissionReason.color,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.submissionReasonLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              Text(
                                _attempt.submissionReason
                                    .localizedLabel(context),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _attempt.submissionReason.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s8,
                            vertical: AppSpacing.s4,
                          ),
                          decoration: BoxDecoration(
                            color: _attempt.status.color.withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSmall),
                          ),
                          child: Text(
                            _attempt.status.localizedLabel(context),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _attempt.status.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s10),
                    Text(
                      _getSubmissionExplanation(
                        context,
                        _attempt.submissionReason,
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const Divider(
                      height: AppSpacing.s20,
                      color: AppColors.border,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.l10n.examSubmissionDateTitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          _attempt.submittedAt != null
                              ? dateFormat.format(_attempt.submittedAt!)
                              : context.l10n.justNow,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.s16),

              // 3. Performance Micro-KPIs Grid
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      context.l10n.detailedPerformanceAnalytics,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          context,
                          title: context.l10n.correctAnswersMetric,
                          value: '$correctCount',
                          subtitle: context.l10n.questions,
                          color: AppColors.success,
                          icon: Icons.check_circle_outline_rounded,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: _buildKpiCard(
                          context,
                          title: context.l10n.incorrectAnswersMetric,
                          value: '$incorrectCount',
                          subtitle: context.l10n.questions,
                          color: AppColors.error,
                          icon: Icons.cancel_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          context,
                          title: context.l10n.skippedAnswersMetric,
                          value: '$skippedCount',
                          subtitle: context.l10n.questions,
                          color: AppColors.warning,
                          icon: Icons.pause_circle_outline_rounded,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: _buildKpiCard(
                          context,
                          title: context.l10n.timeSpentMetric,
                          value: duration != null
                              ? _formatDuration(duration)
                              : '--:--',
                          subtitle: widget.exam.isUntimed
                              ? context.l10n.unlimitedTime
                              : context.l10n.minutesDuration(
                                  widget.exam.durationMinutes,
                                ),
                          color: AppColors.primary,
                          icon: Icons.timer_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.s16),

              // 4. Interactive Answer Sheet Matrix
              if (questions.isNotEmpty) ...[
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
                              if (widget.exam.hasAttachedPdf)
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
                                  onPressed: _openPdfBooklet,
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
                                onPressed: () => _openReview(),
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
                              attemptId: _attempt.id,
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
                            onTap: () => _openReview(initialQuestionIndex: index),
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
              ] else if (_isLoadingDetails) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.s16),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.s24),

              // 5. Contextual Action Bar
              if (isLecture) ...[
                if (isPassed) ...[
                  if (_nextLesson != null) ...[
                    AppButton(
                      text: context.l10n.goToNextLectureSpecific(
                        _nextLesson!.title,
                      ),
                      icon: Icons.play_circle_outline_rounded,
                      isLoading: _isLoadingNextLesson,
                      onPressed: () => _goToNextLesson(_nextLesson!),
                    ),
                    const SizedBox(height: AppSpacing.s10),
                  ],
                  if (widget.exam.hasAttachedPdf) ...[
                    AppButton(
                      text: context.l10n.viewExamBooklet,
                      icon: Icons.picture_as_pdf_rounded,
                      variant: AppButtonVariant.secondary,
                      onPressed: _openPdfBooklet,
                    ),
                    const SizedBox(height: AppSpacing.s10),
                  ],
                  AppButton(
                    text: context.l10n.reviewAllQuestionsAction,
                    icon: Icons.fact_check_outlined,
                    variant: _nextLesson != null
                        ? AppButtonVariant.secondary
                        : AppButtonVariant.primary,
                    onPressed: () => _openReview(),
                  ),
                  const SizedBox(height: AppSpacing.s10),
                  AppButton(
                    text: context.l10n.backToLecturesList,
                    icon: Icons.menu_book_rounded,
                    variant: AppButtonVariant.secondary,
                    onPressed: _goToLecturesScreen,
                  ),
                  if (widget.exam.allowRetake) ...[
                    const SizedBox(height: AppSpacing.s8),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(
                        context.l10n.retakeToImproveScore,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: _handleRetake,
                    ),
                  ],
                ] else ...[
                  // Lecture exam failed: Prominent Retry button!
                  AppButton(
                    text: context.l10n.tryAgainExamAction,
                    icon: Icons.replay_rounded,
                    isLoading: _isRetaking,
                    onPressed: _handleRetake,
                  ),
                  const SizedBox(height: AppSpacing.s10),
                  if (widget.exam.hasAttachedPdf) ...[
                    AppButton(
                      text: context.l10n.viewExamBooklet,
                      icon: Icons.picture_as_pdf_rounded,
                      variant: AppButtonVariant.secondary,
                      onPressed: _openPdfBooklet,
                    ),
                    const SizedBox(height: AppSpacing.s10),
                  ],
                  AppButton(
                    text: context.l10n.reviewAllQuestionsAction,
                    icon: Icons.fact_check_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _openReview(),
                  ),
                  const SizedBox(height: AppSpacing.s10),
                  AppButton(
                    text: context.l10n.backToLecturesList,
                    icon: Icons.menu_book_rounded,
                    variant: AppButtonVariant.secondary,
                    onPressed: _goToLecturesScreen,
                  ),
                ],
              ] else ...[
                // Non-lecture exam (general course exam)
                if (widget.exam.hasAttachedPdf) ...[
                  AppButton(
                    text: context.l10n.viewExamBooklet,
                    icon: Icons.picture_as_pdf_rounded,
                    variant: AppButtonVariant.secondary,
                    onPressed: _openPdfBooklet,
                  ),
                  const SizedBox(height: AppSpacing.s10),
                ],
                AppButton(
                  text: context.l10n.reviewAllQuestionsAction,
                  icon: Icons.fact_check_outlined,
                  onPressed: () => _openReview(),
                ),
                if (widget.exam.allowRetake) ...[
                  const SizedBox(height: AppSpacing.s10),
                  AppButton(
                    text: context.l10n.retakeToImproveScore,
                    icon: Icons.replay_rounded,
                    variant: AppButtonVariant.secondary,
                    isLoading: _isRetaking,
                    onPressed: _handleRetake,
                  ),
                ],
                const SizedBox(height: AppSpacing.s10),
                AppButton(
                  text: context.l10n.backToExamsList,
                  icon: Icons.home_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: () {
                    _examsCubit?.exitExamTaking();
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      context.go(AppRoutes.studentExams);
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendPill(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _GradeTier {
  final String label;
  final Color color;
  final IconData icon;
  final String badgeText;

  const _GradeTier({
    required this.label,
    required this.color,
    required this.icon,
    required this.badgeText,
  });
}
