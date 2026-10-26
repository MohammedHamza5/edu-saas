import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../content/domain/entities/attached_lesson_exam_entity.dart';
import '../../../content/domain/entities/content_entity.dart';
import '../../../content/domain/entities/lesson_assignment_entity.dart';
import '../../../exams/domain/entities/exam_entity.dart';
import '../../domain/entities/video_entity.dart';

class VideoAssociatedExamsSection extends StatelessWidget {
  final ValueNotifier<int> livePositionSecs;
  final ValueNotifier<int> liveDurationSecs;
  final VideoEntity? currentVideo;
  final bool isTeacher;
  final bool isInitiallyCompleted;
  final bool videoCompletedLocally;
  final List<AttachedLessonExamEntity> attachedExams;
  final Map<String, ExamEntity> attachedExamDetails;
  final List<LessonAssignmentEntity> courseLessons;
  final String videoId;
  final void Function(LessonAssignmentEntity lesson, int displayIndex, int totalCount) onOpenLesson;
  final void Function(String examId) onOpenQuizResult;
  final void Function(String examId) onStartLessonQuiz;
  final void Function(int seconds)? onSeekTo;

  const VideoAssociatedExamsSection({
    super.key,
    required this.livePositionSecs,
    required this.liveDurationSecs,
    required this.currentVideo,
    required this.isTeacher,
    required this.isInitiallyCompleted,
    required this.videoCompletedLocally,
    required this.attachedExams,
    required this.attachedExamDetails,
    required this.courseLessons,
    required this.videoId,
    required this.onOpenLesson,
    required this.onOpenQuizResult,
    required this.onStartLessonQuiz,
    this.onSeekTo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localVideo = currentVideo;
    return AnimatedBuilder(
      animation: Listenable.merge([livePositionSecs, liveDurationSecs]),
      builder: (context, _) {
        final livePos = livePositionSecs.value;
        final liveDur = liveDurationSecs.value > 0
            ? liveDurationSecs.value
            : ((localVideo != null && localVideo.duration > 0)
                  ? localVideo.duration
                  : 0);
        final pct = liveDur > 0 ? (livePos / liveDur) * 100 : 0.0;
        final isVideoCompleted =
            isTeacher ||
            isInitiallyCompleted ||
            videoCompletedLocally ||
            pct >= 90.0;

        final attachedList = attachedExams;
        if (attachedList.isEmpty) return const SizedBox.shrink();

        // Helper to check whether an attached exam is passed
        bool checkIsPassed(AttachedLessonExamEntity e) {
          final details = attachedExamDetails[e.examId];
          final passingScore = e.passingScore;
          final attempt = details?.myLatestAttempt;
          if (attempt != null && attempt.isSubmitted) {
            return attempt.isPassed(passingScore);
          }
          return e.isPassed;
        }

        final requiredExams = attachedList.where((e) => e.isRequired).toList();
        final totalRequired = requiredExams.length;
        final passedRequiredCount = requiredExams.where(checkIsPassed).length;
        final allRequiredPassed =
            totalRequired == 0 || passedRequiredCount == totalRequired;

        // Find next lesson if available
        LessonAssignmentEntity? nextLesson;
        int? nextLessonIndex;
        if (courseLessons.isNotEmpty) {
          final cIdx = courseLessons.indexWhere(
            (l) => l.contentId == videoId,
          );
          if (cIdx >= 0 && cIdx < courseLessons.length - 1) {
            final candidate = courseLessons[cIdx + 1];
            if (candidate.type == ContentType.video &&
                candidate.contentId != videoId) {
              nextLesson = candidate;
              nextLessonIndex = cIdx + 2;
            }
          }
        }

        final Color headerColor = allRequiredPassed
            ? AppColors.success
            : (isVideoCompleted ? AppColors.primary : AppColors.warning);

        return AppCard(
          variant: AppCardVariant.elevated,
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: Title & Overall Progress Pill
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      color: headerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.attachedQuizzesSection,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (totalRequired > 1) ...[
                          const SizedBox(height: 2),
                          Text(
                            context.l10n.requiredQuizzesCompletedProgress(
                              passedRequiredCount,
                              totalRequired,
                            ),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: headerColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                      border: Border.all(color: headerColor.withAlpha(60)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          allRequiredPassed
                              ? Icons.check_circle_rounded
                              : (isVideoCompleted
                                    ? Icons.quiz_rounded
                                    : Icons.lock_outline_rounded),
                          size: 11,
                          color: headerColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          totalRequired > 1
                              ? '$passedRequiredCount / $totalRequired'
                              : (allRequiredPassed
                                    ? 'COMPLETED'
                                    : isVideoCompleted
                                    ? 'QUIZ'
                                    : 'LOCKED'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: headerColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Subtitle Banner
              if (allRequiredPassed) ...[
                Text(
                  '🎉 ${context.l10n.allRequiredQuizzesPassedCongrats}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ] else if (isVideoCompleted) ...[
                Text(
                  context.l10n.attachedQuizzesSectionSubtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else ...[
                Text(
                  context.l10n.completeVideoToUnlockQuiz,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.s12),

              // Vertical list of Quiz Cards
              ...attachedList.map((attached) {
                final examDetails = attachedExamDetails[attached.examId];
                final latestAttempt = examDetails?.myLatestAttempt;
                final passingScore =
                    (examDetails?.passingScore != null &&
                        examDetails!.passingScore! > 0)
                    ? examDetails.passingScore!
                    : attached.passingScore;
                final isSubmitted =
                    latestAttempt != null && latestAttempt.isSubmitted;
                final isPassed =
                    (isSubmitted && latestAttempt.isPassed(passingScore)) ||
                    attached.isPassed;
                final isFailed = isSubmitted && !isPassed;
                final scorePct =
                    latestAttempt?.percentage?.toInt() ??
                    attached.bestScore?.toInt();
                final resolvedQuestionsCount =
                    (examDetails != null && examDetails.totalQuestions > 0)
                    ? examDetails.totalQuestions
                    : attached.questionsCount;
                final quizTitle = (examDetails?.title.isNotEmpty == true)
                    ? examDetails!.title
                    : (attached.examTitle.isNotEmpty
                          ? attached.examTitle
                          : context.l10n.associatedExamBadge);

                Color itemColor;
                if (isPassed) {
                  itemColor = AppColors.success;
                } else if (isFailed) {
                  itemColor = AppColors.error;
                } else if (isVideoCompleted) {
                  itemColor = AppColors.primary;
                } else {
                  itemColor = AppColors.textMuted;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.s10),
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withAlpha(25),
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusMedium,
                    ),
                    border: Border.all(color: itemColor.withAlpha(70)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: itemColor.withAlpha(20),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSmall,
                              ),
                            ),
                            child: Icon(
                              isPassed
                                  ? Icons.verified_rounded
                                  : isFailed
                                  ? Icons.cancel_rounded
                                  : isVideoCompleted
                                  ? Icons.quiz_rounded
                                  : Icons.lock_rounded,
                              size: 20,
                              color: itemColor,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        quizTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: attached.isRequired
                                            ? AppColors.error.withAlpha(20)
                                            : AppColors.primary.withAlpha(20),
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusFull,
                                        ),
                                        border: Border.all(
                                          color: attached.isRequired
                                              ? AppColors.error.withAlpha(50)
                                              : AppColors.primary.withAlpha(50),
                                        ),
                                      ),
                                      child: Text(
                                        attached.isRequired
                                            ? context
                                                  .l10n
                                                  .requiredForProgression
                                            : context.l10n.optionalPractice,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: attached.isRequired
                                              ? AppColors.error
                                              : AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Text(
                                      resolvedQuestionsCount > 0
                                          ? '$resolvedQuestionsCount ${context.l10n.questions} · ${context.l10n.passingScoreTitle}: $passingScore%'
                                          : '${context.l10n.passingScoreTitle}: $passingScore%',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    if (scorePct != null) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '· ${context.l10n.quizScoreBadge(scorePct)}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: isPassed
                                              ? AppColors.success
                                              : AppColors.error,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s10),
                      // Action button per quiz
                      if (isPassed) ...[
                        ElevatedButton.icon(
                          icon: const Icon(Icons.fact_check_outlined, size: 14),
                          label: Text(
                            context.l10n.viewExamResultAction,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 12,
                            ),
                            minimumSize: const Size.fromHeight(32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSmall,
                              ),
                            ),
                          ),
                          onPressed: () => onOpenQuizResult(attached.examId),
                        ),
                        if (examDetails?.allowRetake == true) ...[
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.refresh_rounded, size: 14),
                            label: Text(
                              context.l10n.retryLessonQuizAction,
                              style: const TextStyle(fontSize: 11),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 12,
                              ),
                              minimumSize: const Size.fromHeight(32),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSmall,
                                ),
                              ),
                            ),
                            onPressed: () => onStartLessonQuiz(attached.examId),
                          ),
                        ],
                      ] else if (isFailed) ...[
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh_rounded, size: 14),
                          label: Text(
                            context.l10n.retryLessonQuizAction,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 12,
                            ),
                            minimumSize: const Size.fromHeight(32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSmall,
                              ),
                            ),
                          ),
                          onPressed: () => onStartLessonQuiz(attached.examId),
                        ),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.fact_check_outlined, size: 14),
                          label: Text(
                            context.l10n.viewExamResultAction,
                            style: const TextStyle(fontSize: 11),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 12,
                            ),
                            minimumSize: const Size.fromHeight(32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSmall,
                              ),
                            ),
                          ),
                          onPressed: () => onOpenQuizResult(attached.examId),
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          icon: Icon(
                            isVideoCompleted
                                ? Icons.play_arrow_rounded
                                : Icons.lock_outline_rounded,
                            size: 14,
                          ),
                          label: Text(
                            isVideoCompleted
                                ? context.l10n.takeLessonQuizAction
                                : context.l10n.completeVideoToUnlockQuiz,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isVideoCompleted
                                ? AppColors.primary
                                : AppColors.surfaceVariant,
                            foregroundColor: isVideoCompleted
                                ? Colors.white
                                : AppColors.textMuted,
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 12,
                            ),
                            minimumSize: const Size.fromHeight(32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSmall,
                              ),
                            ),
                          ),
                          onPressed: isVideoCompleted
                              ? () => onStartLessonQuiz(attached.examId)
                              : null,
                        ),
                      ],
                    ],
                  ),
                );
              }),

              // Sequential Next Lesson Navigation
              if (allRequiredPassed && nextLesson != null) ...[
                const SizedBox(height: AppSpacing.s6),
                Text(
                  context.l10n.nextLessonLabel(nextLesson.title),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: Text(context.l10n.continueToNextLessonAction),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s12,
                      horizontal: AppSpacing.s16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMedium,
                      ),
                    ),
                  ),
                  onPressed: () => onOpenLesson(
                    nextLesson!,
                    nextLessonIndex ?? 2,
                    courseLessons.length,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.replay_rounded, size: 16),
                  label: Text(context.l10n.reviewLessonAction),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s10,
                      horizontal: AppSpacing.s16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMedium,
                      ),
                    ),
                  ),
                  onPressed: () => onSeekTo?.call(0),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

}
