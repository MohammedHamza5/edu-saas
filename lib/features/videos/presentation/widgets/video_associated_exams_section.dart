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
import 'attached_exams_next_lesson_bar.dart';
import 'attached_quiz_card_item.dart';

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
  final void Function(
    LessonAssignmentEntity lesson,
    int displayIndex,
    int totalCount,
  ) onOpenLesson;
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
                return AttachedQuizCardItem(
                  attached: attached,
                  examDetails: attachedExamDetails[attached.examId],
                  isVideoCompleted: isVideoCompleted,
                  onOpenQuizResult: onOpenQuizResult,
                  onStartLessonQuiz: onStartLessonQuiz,
                );
              }),

              // Sequential Next Lesson Navigation
              if (allRequiredPassed && nextLesson != null)
                AttachedExamsNextLessonBar(
                  nextLesson: nextLesson,
                  nextLessonIndex: nextLessonIndex ?? 2,
                  totalLessonsCount: courseLessons.length,
                  onOpenLesson: onOpenLesson,
                  onReviewLesson: () => onSeekTo?.call(0),
                ),
            ],
          ),
        );
      },
    );
  }
}
