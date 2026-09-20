import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/exam_entity.dart';

class ExamCard extends StatelessWidget {
  final ExamEntity exam;
  final VoidCallback onTap;
  final bool isTeacher;

  const ExamCard({
    super.key,
    required this.exam,
    required this.onTap,
    this.isTeacher = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: Icon, Title, Status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.quiz_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (exam.groupName != null) ...[
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        context.l10n.groupColon(exam.groupName!),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              _buildStatusBadge(context),
            ],
          ),

          const SizedBox(height: AppSpacing.s16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.s12),

          // Meta tags row: Duration, Max score, Passing score
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s6,
            children: [
              _buildMetaTag(
                Icons.timer_outlined,
                context.l10n.minutesDuration(exam.durationMinutes),
              ),
              _buildMetaTag(
                Icons.grade_outlined,
                context.l10n.scorePoints(exam.maxScore),
              ),
              if (exam.passingScore != null)
                _buildMetaTag(
                  Icons.verified_outlined,
                  context.l10n.passingScoreLabel(exam.passingScore!),
                ),
            ],
          ),

          // Teacher meta: Version & Attempts
          if (isTeacher) ...[
            const SizedBox(height: AppSpacing.s8),
            Row(
              children: [
                const Icon(
                  Icons.history_edu_outlined,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.s4),
                Expanded(
                  child: Text(
                    context.l10n.examVersionAttempts(
                      exam.activeVersion?.versionNumber ?? 1,
                      exam.attemptsCount,
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    if (isTeacher) {
      final isPublished = exam.activeVersion?.isPublished ?? true;
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: (isPublished ? AppColors.success : AppColors.warning)
              .withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        ),
        child: Text(
          isPublished ? context.l10n.publishedBadge : context.l10n.draftBadge,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isPublished ? AppColors.success : AppColors.warning,
          ),
        ),
      );
    }

    // Student Status Badge
    final attempt = exam.myLatestAttempt;
    if (attempt == null) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        ),
        child: Text(
          context.l10n.availableToStart,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (attempt.isInProgress) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        ),
        child: Text(
          context.l10n.inProgressResume,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.warning,
          ),
        ),
      );
    }

    final isPassed = attempt.isPassed(exam.passingScore);
    final badgeColor = isPassed ? AppColors.success : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
      child: Text(
        attempt.score != null
            ? '${attempt.score}/${exam.maxScore}'
            : (isPassed ? context.l10n.passed : context.l10n.notPassed),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: badgeColor,
        ),
      ),
    );
  }
}
