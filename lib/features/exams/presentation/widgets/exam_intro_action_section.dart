import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../content/domain/entities/lesson_assignment_entity.dart';
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';
import '../pages/exam_result_page.dart';
import '../pages/exam_taking_page.dart';

/// Interactive action section with start, retake, view results, and eligibility banners.
class ExamIntroActionSection extends StatelessWidget {
  final bool canTake;
  final ExamEntity exam;
  final bool hasActive;
  final bool isPassed;
  final bool isUntimed;
  final bool isLectureExam;
  final ExamAttemptEntity? effectiveAttempt;
  final LessonAssignmentEntity? nextLesson;
  final int? nextLessonIndex;
  final int? totalLessonsCount;

  const ExamIntroActionSection({
    super.key,
    required this.canTake,
    required this.exam,
    required this.hasActive,
    required this.isPassed,
    required this.isUntimed,
    required this.isLectureExam,
    this.effectiveAttempt,
    this.nextLesson,
    this.nextLessonIndex,
    this.totalLessonsCount,
  });

  void _navigateToResults(BuildContext context, ExamAttemptEntity attempt) {
    final cubit = context.read<ExamsCubit>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: ExamResultPage(
            exam: exam,
            attempt: attempt,
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

  @override
  Widget build(BuildContext context) {
    if (canTake) {
      return Column(
        children: [
          if (exam.hasAttempted &&
              exam.myLatestAttempt != null &&
              !hasActive) ...[
            // Banner showing previous attempt results
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: AppSpacing.s16),
              padding: const EdgeInsets.all(AppSpacing.s14),
              decoration: BoxDecoration(
                color: (isPassed ? AppColors.success : AppColors.warning)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
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
                      content:
                          Text(context.l10n.errorExamAlreadySubmittedMessage),
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
                AppFeedback.showError(context, state.message);
              }
            },
            builder: (context, state) {
              final isLoading = state is ExamsLoading;
              final hasAttempt = exam.hasAttempted &&
                  exam.myLatestAttempt != null &&
                  !hasActive;

              return Column(
                children: [
                  if (hasAttempt) ...[
                    // Primary: View Results & Solutions
                    AppButton(
                      text: context.l10n.viewExamResultAction,
                      icon: Icons.fact_check_outlined,
                      onPressed: () =>
                          _navigateToResults(context, exam.myLatestAttempt!),
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

                              if (!context.mounted) return;
                              if (success) {
                                await Navigator.of(context)
                                    .pushReplacement<void, void>(
                                  MaterialPageRoute<void>(
                                    builder: (_) => BlocProvider.value(
                                      value: cubit,
                                      child: ExamTakingPage(
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

                              if (!context.mounted) return;
                              if (success) {
                                await Navigator.of(context)
                                    .pushReplacement<void, void>(
                                  MaterialPageRoute<void>(
                                    builder: (_) => BlocProvider.value(
                                      value: cubit,
                                      child: ExamTakingPage(
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
                            },
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      );
    }

    // Ineligible Case
    return Column(
      children: [
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
        if (effectiveAttempt != null) ...[
          const SizedBox(height: AppSpacing.s16),
          AppButton(
            text: context.l10n.viewExamResultAction,
            icon: Icons.fact_check_outlined,
            onPressed: () => _navigateToResults(context, effectiveAttempt!),
          ),
        ],
      ],
    );
  }
}
