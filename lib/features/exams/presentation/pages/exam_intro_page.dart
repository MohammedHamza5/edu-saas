import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';
import 'exam_result_page.dart';
import 'exam_taking_page.dart';
import '../../../content/domain/entities/lesson_assignment_entity.dart';
import '../utils/exam_asset_preloader.dart';

class ExamIntroPage extends StatelessWidget {
  final ExamEntity exam;

  /// امتحان مرتبط بمحاضرة: لا نافذة زمنية ولا تنبيه تأخير.
  final bool isLectureExam;
  final LessonAssignmentEntity? nextLesson;
  final int? nextLessonIndex;
  final int? totalLessonsCount;

  const ExamIntroPage({
    super.key,
    required this.exam,
    this.isLectureExam = false,
    this.nextLesson,
    this.nextLessonIndex,
    this.totalLessonsCount,
  });

  String? _lateText(BuildContext context) {
    final end = exam.endAt;
    if (isLectureExam || end == null) return null;
    final late = DateTime.now().difference(end);
    if (late.isNegative || late == Duration.zero) return null;
    final l10n = context.l10n;
    final days = late.inDays;
    final hours = late.inHours % 24;
    final minutes = late.inMinutes % 60;
    final parts = <String>[
      if (days > 0) l10n.examLateDays(days),
      if (hours > 0) l10n.examLateHours(hours),
      if (days == 0) if (minutes > 0 || hours == 0) l10n.examLateMinutes(minutes),
    ];
    return l10n.examLateBanner(parts.join(l10n.examLateJoiner));
  }

  @override
  Widget build(BuildContext context) {
    final isUntimed = isLectureExam || exam.isUntimed;
    final hasActive = exam.hasActiveAttempt;
    final isPassed = exam.myBestScore != null &&
        (exam.passingScore == null || exam.myBestScore! >= exam.passingScore!);
    final canTake = isUntimed
        ? (!isPassed || exam.allowRetake || hasActive)
        : exam.canTakeExam;

    final introQuestions = exam.activeVersion?.questions ?? const [];
    if (introQuestions.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ExamAssetPreloader().startOrUpdate(
            context: context,
            questions: introQuestions,
          );
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.examRulesAndGuidelines),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.s20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.quiz_outlined,
                      color: AppColors.primary,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Text(
                    exam.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (exam.groupName != null) ...[
                    const SizedBox(height: AppSpacing.s6),
                    Text(
                      context.l10n.groupColon(exam.groupName!),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.s20),

            // Key Stats Grid
            Row(
              children: [
                Expanded(
                  child: _buildInfoTile(
                    Icons.timer_outlined,
                    context.l10n.examDurationLabel,
                    isUntimed
                        ? context.l10n.unlimitedTime
                        : context.l10n.minutesDuration(exam.durationMinutes),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: _buildInfoTile(
                    Icons.grade_outlined,
                    context.l10n.maxScoreLabel,
                    context.l10n.scorePoints(exam.maxScore),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoTile(
                    Icons.verified_outlined,
                    context.l10n.passingScoreTitle,
                    exam.passingScore != null
                        ? context.l10n.scorePoints(exam.passingScore!)
                        : context.l10n.notSpecified,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: _buildInfoTile(
                    Icons.replay_outlined,
                    context.l10n.retakePolicy,
                    isLectureExam
                        ? (!isPassed
                            ? context.l10n.allowedUntilPassed
                            : (exam.allowRetake
                                ? context.l10n.allowedHighestScore
                                : context.l10n.notAllowed))
                        : (exam.allowRetake
                            ? context.l10n.allowedHighestScore
                            : context.l10n.notAllowed),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.s24),

            // Instructions Box
            Text(
              context.l10n.importantInstructionsBeforeStart,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isUntimed) ...[
                    _RuleItem(text: context.l10n.ruleUntimedLectureExam),
                    const SizedBox(height: AppSpacing.s8),
                    _RuleItem(text: context.l10n.ruleAutoSaveAnswers),
                    const SizedBox(height: AppSpacing.s8),
                    if (isLectureExam) ...[
                      _RuleItem(text: context.l10n.ruleRetakeAllowedNotice),
                      const SizedBox(height: AppSpacing.s8),
                    ],
                    _RuleItem(text: context.l10n.ruleDoNotCloseWindow),
                  ] else ...[
                    _RuleItem(text: context.l10n.ruleTimerStartsImmediately),
                    const SizedBox(height: AppSpacing.s8),
                    _RuleItem(text: context.l10n.ruleAutoSaveAnswers),
                    const SizedBox(height: AppSpacing.s8),
                    _RuleItem(text: context.l10n.ruleAutoSubmitOnTimeout),
                    const SizedBox(height: AppSpacing.s8),
                    _RuleItem(text: context.l10n.ruleDoNotCloseWindow),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.s32),

            if (_lateText(context) case final lateText?) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.s16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_outlined,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Text(
                        lateText,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
            ],

            // Action Button
            if (canTake) ...[
              if (exam.hasAttempted && exam.myLatestAttempt != null && !hasActive) ...[
                // Banner showing previous attempt results
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: AppSpacing.s16),
                  padding: const EdgeInsets.all(AppSpacing.s14),
                  decoration: BoxDecoration(
                    color: (isPassed ? AppColors.success : AppColors.warning)
                        .withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMedium),
                    border: Border.all(
                      color: isPassed ? AppColors.success : AppColors.warning,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPassed
                            ? Icons.emoji_events_rounded
                            : Icons.info_outline_rounded,
                        color: isPassed ? AppColors.success : AppColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.previousAttemptSummary,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              context.l10n.examScoreSummary(
                                exam.myBestScore ??
                                    exam.myLatestAttempt!.score ??
                                    0,
                                exam.maxScore,
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isPassed
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              BlocConsumer<ExamsCubit, ExamsState>(
                listener: (context, state) {
                  if (state is ExamsError) {
                    if (state.message.contains('ATTEMPTS_LIMIT_REACHED')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.errorExamAlreadySubmittedMessage),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                      if (exam.myLatestAttempt != null) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => BlocProvider.value(
                              value: context.read<ExamsCubit>(),
                              child: ExamResultPage(
                                exam: exam,
                                attempt: exam.myLatestAttempt!,
                                isLectureExam: isLectureExam ||
                                    exam.isLectureExam ||
                                    exam.isLinkedToLesson,
                                nextLesson: nextLesson,
                                nextLessonIndex: nextLessonIndex,
                                totalLessonsCount: totalLessonsCount,
                              ),
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
                builder: (context, state) {
                  final isLoading = state is ExamsLoading;
                  final hasAttempt =
                      exam.hasAttempted && exam.myLatestAttempt != null && !hasActive;

                  return Column(
                    children: [
                      if (hasAttempt) ...[
                        // Primary: View Results & Solutions
                        AppButton(
                          text: context.l10n.viewExamResultAction,
                          icon: Icons.fact_check_outlined,
                          onPressed: () {
                            final cubit = context.read<ExamsCubit>();
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => BlocProvider.value(
                                  value: cubit,
                                  child: ExamResultPage(
                                    exam: exam,
                                    attempt: exam.myLatestAttempt!,
                                    isLectureExam: isLectureExam ||
                                        exam.isLectureExam ||
                                        exam.isLinkedToLesson,
                                    nextLesson: nextLesson,
                                    nextLessonIndex: nextLessonIndex,
                                    totalLessonsCount: totalLessonsCount,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        // Secondary: Retake if allowed
                        AppButton(
                          text: isLectureExam && !isPassed
                              ? context.l10n.retakeExamNow
                              : context.l10n.retakeToImproveScore,
                          icon: Icons.replay_outlined,
                          variant: AppButtonVariant.secondary,
                          isLoading: isLoading,
                          onPressed: isLoading
                              ? null
                              : () async {
                                  final cubit = context.read<ExamsCubit>();
                                  final success = await cubit.startExamTaking(
                                    exam,
                                    isLectureExam: isUntimed,
                                  );

                                  if (context.mounted && success) {
                                    await Navigator.of(context).push<void>(
                                      MaterialPageRoute<void>(
                                        builder: (_) => BlocProvider.value(
                                          value: cubit,
                                          child: ExamTakingPage(
                                            isLectureExam: isLectureExam ||
                                                exam.isLectureExam ||
                                                exam.isLinkedToLesson,
                                            nextLesson: nextLesson,
                                            nextLessonIndex: nextLessonIndex,
                                            totalLessonsCount:
                                                totalLessonsCount,
                                          ),
                                        ),
                                      ),
                                    );
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  }
                                },
                        ),
                      ] else ...[
                        AppButton(
                          text: hasActive
                              ? context.l10n.resumeCurrentExam
                              : context.l10n.startExamNow,
                          icon: hasActive
                              ? Icons.play_arrow
                              : Icons.rocket_launch_outlined,
                          isLoading: isLoading,
                          onPressed: isLoading
                              ? null
                              : () async {
                                  final cubit = context.read<ExamsCubit>();
                                  final success = await cubit.startExamTaking(
                                    exam,
                                    isLectureExam: isUntimed,
                                  );

                                  if (context.mounted && success) {
                                    await Navigator.of(context).push<void>(
                                      MaterialPageRoute<void>(
                                        builder: (_) => BlocProvider.value(
                                          value: cubit,
                                          child: ExamTakingPage(
                                            isLectureExam: isLectureExam ||
                                                exam.isLectureExam ||
                                                exam.isLinkedToLesson,
                                            nextLesson: nextLesson,
                                            nextLessonIndex: nextLessonIndex,
                                            totalLessonsCount:
                                                totalLessonsCount,
                                          ),
                                        ),
                                      ),
                                    );
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  }
                                },
                        ),
                      ],
                    ],
                  );
                },
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.s16),
                decoration: BoxDecoration(
                  color: (isLectureExam && isPassed
                          ? AppColors.success
                          : AppColors.warning)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  border: Border.all(
                    color: isLectureExam && isPassed
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
                child: Column(
                  children: [
                    if (isLectureExam && isPassed) ...[
                      const Icon(
                        Icons.emoji_events_rounded,
                        color: AppColors.success,
                        size: 36,
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        context.l10n.examAlreadyPassedTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s6),
                      Text(
                        context.l10n.examAlreadyPassedSubtitle(
                          exam.myBestScore!,
                          exam.maxScore,
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ] else ...[
                      Text(
                        exam.myBestScore != null
                            ? context.l10n.examAlreadyCompletedNoRetake(
                                exam.myBestScore!,
                                exam.maxScore,
                              )
                            : context.l10n.examCannotBeTaken,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (exam.myLatestAttempt != null) ...[
                const SizedBox(height: AppSpacing.s16),
                AppButton(
                  text: context.l10n.viewExamResultAction,
                  icon: Icons.fact_check_outlined,
                  onPressed: () {
                    final cubit = context.read<ExamsCubit>();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BlocProvider.value(
                          value: cubit,
                          child: ExamResultPage(
                            exam: exam,
                            attempt: exam.myLatestAttempt!,
                            isLectureExam: isLectureExam ||
                                exam.isLectureExam ||
                                exam.isLinkedToLesson,
                            nextLesson: nextLesson,
                            nextLessonIndex: nextLessonIndex,
                            totalLessonsCount: totalLessonsCount,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.s6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  final String text;
  const _RuleItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Icon(
            Icons.check_circle_outline,
            size: 14,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
