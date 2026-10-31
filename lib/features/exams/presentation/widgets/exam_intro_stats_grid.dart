import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/exam_entity.dart';

/// Key exam statistics grid displaying duration, max score, passing score, and retake policy.
class ExamIntroStatsGrid extends StatelessWidget {
  final ExamEntity exam;
  final bool isUntimed;
  final bool isLectureExam;
  final bool isPassed;

  const ExamIntroStatsGrid({
    super.key,
    required this.exam,
    required this.isUntimed,
    required this.isLectureExam,
    required this.isPassed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
      ],
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
