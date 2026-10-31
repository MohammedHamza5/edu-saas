import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../content/domain/entities/lesson_assignment_entity.dart';
import '../../domain/entities/exam_entity.dart';
import '../utils/exam_asset_preloader.dart';
import '../widgets/exam_intro_action_section.dart';
import '../widgets/exam_intro_rules_box.dart';
import '../widgets/exam_intro_stats_grid.dart';

/// Exam introduction coordinator page presenting guidelines, duration, scoring, and starting/resuming attempts.
class ExamIntroPage extends StatelessWidget {
  final ExamEntity exam;
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
      if (days == 0)
        if (minutes > 0 || hours == 0) l10n.examLateMinutes(minutes),
    ];
    return l10n.examLateBanner(parts.join(l10n.examLateJoiner));
  }

  @override
  Widget build(BuildContext context) {
    final effectiveAttempt = exam.myLatestAttempt ??
        (exam.hasAttempted || exam.myBestScore != null
            ? ExamAttemptEntity(
                id: '',
                examId: exam.id,
                examVersionId: exam.activeVersion?.id ?? '',
                studentId: '',
                startedAt: DateTime.now(),
                submittedAt: DateTime.now(),
                score: exam.myBestScore ?? 0,
                percentage: exam.maxScore > 0
                    ? ((exam.myBestScore ?? 0) / exam.maxScore) * 100
                    : 0,
                status: AttemptStatus.submitted,
              )
            : null);
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
            ExamIntroStatsGrid(
              exam: exam,
              isUntimed: isUntimed,
              isLectureExam: isLectureExam,
              isPassed: isPassed,
            ),

            const SizedBox(height: AppSpacing.s24),

            // Instructions Box
            ExamIntroRulesBox(
              isUntimed: isUntimed,
              isLectureExam: isLectureExam,
            ),

            const SizedBox(height: AppSpacing.s32),

            // Late Warning Banner
            if (_lateText(context) case final lateText?) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.s16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusMedium),
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

            // Action Section (Start, Retake, View Results, or Ineligible Banner)
            ExamIntroActionSection(
              canTake: canTake,
              exam: exam,
              hasActive: hasActive,
              isPassed: isPassed,
              isUntimed: isUntimed,
              isLectureExam: isLectureExam,
              effectiveAttempt: effectiveAttempt,
              nextLesson: nextLesson,
              nextLessonIndex: nextLessonIndex,
              totalLessonsCount: totalLessonsCount,
            ),
          ],
        ),
      ),
    );
  }
}
