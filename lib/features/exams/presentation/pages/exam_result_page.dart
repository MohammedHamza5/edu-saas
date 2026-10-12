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
import '../../../content/domain/entities/lesson_assignment_entity.dart';
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_cubit.dart';
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
  LessonAssignmentEntity? _nextLesson;
  int? _nextLessonIndex;
  int? _totalLessonsCount;
  bool _isLoadingNextLesson = false;
  bool _isRetaking = false;

  @override
  void initState() {
    super.initState();
    _nextLesson = widget.nextLesson;
    _nextLessonIndex = widget.nextLessonIndex;
    _totalLessonsCount = widget.totalLessonsCount;

    final isLecture = widget.isLectureExam ??
        (widget.exam.isLectureExam || widget.exam.isLinkedToLesson);
    final isPassed = widget.attempt.isPassed(widget.exam.passingScore);

    if (isLecture &&
        isPassed &&
        _nextLesson == null &&
        widget.exam.groupId.isNotEmpty) {
      _fetchNextLesson();
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
        final lessons = res.dataOrNull!;
        if (lessons.isNotEmpty) {
          final cIdx = lessons.indexWhere(
            (l) =>
                (widget.exam.linkedLessonId != null &&
                    l.contentId == widget.exam.linkedLessonId) ||
                l.lessonExamId == widget.exam.id ||
                l.attachedExams.any((e) => e.examId == widget.exam.id),
          );
          if (cIdx >= 0 && cIdx < lessons.length - 1) {
            setState(() {
              _nextLesson = lessons[cIdx + 1];
              _nextLessonIndex = cIdx + 2;
              _totalLessonsCount = lessons.length;
              _isLoadingNextLesson = false;
            });
            return;
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

    if (widget.exam.groupId.isNotEmpty) {
      context.go('/student/groups/${widget.exam.groupId}/content');
    } else {
      context.go(AppRoutes.studentDashboard);
    }
  }

  Future<void> _handleRetake() async {
    if (_isRetaking) return;
    setState(() => _isRetaking = true);

    final cubit = context.read<ExamsCubit>();
    final success = await cubit.startExamTaking(
      widget.exam,
      isLectureExam: true,
    );

    if (mounted) {
      setState(() => _isRetaking = false);
      if (success) {
        unawaited(
          Navigator.of(context).pushReplacement<void, void>(
            MaterialPageRoute<void>(
              builder: (_) => BlocProvider.value(
                value: cubit,
                child: ExamTakingPage(
                  isLectureExam: true,
                  nextLesson: _nextLesson,
                  nextLessonIndex: _nextLessonIndex,
                  totalLessonsCount: _totalLessonsCount,
                ),
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLecture = widget.isLectureExam ??
        (widget.exam.isLectureExam || widget.exam.isLinkedToLesson);
    final isPassed = widget.attempt.isPassed(widget.exam.passingScore);
    final dateFormat = DateFormat('yyyy/MM/dd - hh:mm a');
    final score = widget.attempt.score ?? 0;
    final percentage =
        widget.attempt.percentage ??
        (widget.exam.maxScore > 0 ? (score / widget.exam.maxScore) * 100 : 0.0);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: isLecture
                ? context.l10n.backToLecturesList
                : context.l10n.backToExamsList,
            onPressed: () {
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
          padding: const EdgeInsets.all(AppSpacing.s20),
          child: Column(
            children: [
              // Hero Result Card
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.s24),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: (isPassed ? AppColors.success : AppColors.error)
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          isPassed
                              ? Icons.emoji_events_outlined
                              : Icons.sentiment_dissatisfied_outlined,
                          color: isPassed ? AppColors.success : AppColors.error,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    Text(
                      isPassed
                          ? context.l10n.congratulationsPassed
                          : context.l10n.sorryNotPassed,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isPassed ? AppColors.success : AppColors.error,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s6),

                    Text(
                      widget.exam.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.s20),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: AppSpacing.s20),

                    // Score Numbers (Large Academic Typography)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$score',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color:
                                isPassed ? AppColors.success : AppColors.error,
                          ),
                        ),
                        Text(
                          ' / ${widget.exam.maxScore}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      context.l10n.percentageLabel(
                        percentage.toStringAsFixed(1),
                      ),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (widget.exam.passingScore != null) ...[
                      const SizedBox(height: AppSpacing.s6),
                      Text(
                        context.l10n.requiredPassingScore(
                          widget.exam.passingScore!,
                          widget.exam.maxScore,
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    if (isPassed && isLecture) ...[
                      const SizedBox(height: AppSpacing.s16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s16,
                          vertical: AppSpacing.s12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text('🚀', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: AppSpacing.s8),
                            Expanded(
                              child: Text(
                                _nextLesson != null
                                    ? context.l10n.quizPassedUnlockNext
                                    : context
                                          .l10n
                                          .allLecturesCompletedCongratulations,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (!isPassed && isLecture) ...[
                      const SizedBox(height: AppSpacing.s16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s16,
                          vertical: AppSpacing.s12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text('💡', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: AppSpacing.s8),
                            Expanded(
                              child: Text(
                                context.l10n.quizFailedEncouragement,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.s16),

              // Attempt details card
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Column(
                  children: [
                    _buildDetailRow(
                      context.l10n.examSubmissionDateTitle,
                      widget.attempt.submittedAt != null
                          ? dateFormat.format(widget.attempt.submittedAt!)
                          : context.l10n.justNow,
                    ),
                    const Divider(
                      height: AppSpacing.s16,
                      color: AppColors.border,
                    ),
                    _buildDetailRow(
                      context.l10n.attemptStatusLabel,
                      widget.attempt.status.localizedLabel(context),
                      valueColor: widget.attempt.status.color,
                    ),
                    if (widget.exam.allowRetake || isLecture) ...[
                      const Divider(
                        height: AppSpacing.s16,
                        color: AppColors.border,
                      ),
                      _buildDetailRow(
                        context.l10n.retakePolicyLabel,
                        context.l10n.retakeAllowedBestScore,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.s32),

              if (isLecture) ...[
                if (isPassed) ...[
                  if (_nextLesson != null) ...[
                    AppButton(
                      text: context.l10n.goToNextLectureAction,
                      icon: Icons.play_circle_outline_rounded,
                      isLoading: _isLoadingNextLesson,
                      onPressed: () => _goToNextLesson(_nextLesson!),
                    ),
                  ] else if (_isLoadingNextLesson) ...[
                    AppButton(
                      text: context.l10n.goToNextLectureAction,
                      icon: Icons.play_circle_outline_rounded,
                      isLoading: true,
                      onPressed: null,
                    ),
                  ] else ...[
                    AppButton(
                      text: context.l10n.backToLecturesList,
                      icon: Icons.menu_book_rounded,
                      onPressed: _goToLecturesScreen,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s12),
                  AppButton(
                    text: context.l10n.reviewExamAnswersAction,
                    icon: Icons.fact_check_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ExamReviewPage(
                            attemptId: widget.attempt.id,
                            exam: widget.exam,
                            initialAttempt: widget.attempt,
                          ),
                        ),
                      );
                    },
                  ),
                  if (_nextLesson != null) ...[
                    const SizedBox(height: AppSpacing.s12),
                    AppButton(
                      text: context.l10n.backToLecturesList,
                      icon: Icons.menu_book_rounded,
                      variant: AppButtonVariant.secondary,
                      onPressed: _goToLecturesScreen,
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
                  const SizedBox(height: AppSpacing.s12),
                  AppButton(
                    text: context.l10n.reviewExamAnswersAction,
                    icon: Icons.fact_check_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ExamReviewPage(
                            attemptId: widget.attempt.id,
                            exam: widget.exam,
                            initialAttempt: widget.attempt,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  AppButton(
                    text: context.l10n.backToLecturesList,
                    icon: Icons.menu_book_rounded,
                    variant: AppButtonVariant.secondary,
                    onPressed: _goToLecturesScreen,
                  ),
                ],
              ] else ...[
                // Non-lecture exam (general course exam)
                AppButton(
                  text: context.l10n.reviewExamAnswersAction,
                  icon: Icons.fact_check_outlined,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ExamReviewPage(
                          attemptId: widget.attempt.id,
                          exam: widget.exam,
                          initialAttempt: widget.attempt,
                        ),
                      ),
                    );
                  },
                ),
                if (widget.exam.allowRetake) ...[
                  const SizedBox(height: AppSpacing.s12),
                  AppButton(
                    text: context.l10n.tryAgainExamAction,
                    icon: Icons.replay_rounded,
                    isLoading: _isRetaking,
                    onPressed: _handleRetake,
                  ),
                ],
                const SizedBox(height: AppSpacing.s12),
                AppButton(
                  text: context.l10n.backToExamsList,
                  icon: Icons.home_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: () {
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

  static Widget _buildDetailRow(
    String title,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
