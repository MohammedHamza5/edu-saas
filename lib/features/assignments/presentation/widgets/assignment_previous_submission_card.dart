import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/assignment_entity.dart';
import '../extensions/submission_status_ui_extensions.dart';

/// Card showing status, score, attempt, and teacher feedback of previous submission
class AssignmentPreviousSubmissionCard extends StatelessWidget {
  final AssignmentEntity assignment;
  final AssignmentSubmissionEntity mySub;
  final DateFormat dateFormat;

  const AssignmentPreviousSubmissionCard({
    super.key,
    required this.assignment,
    required this.mySub,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isReviewed = mySub.isReviewed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.submissionStatusCardTitle,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.s16),
          backgroundColor: isReviewed
              ? AppColors.success.withValues(alpha: 0.05)
              : AppColors.surface,
          borderColor: isReviewed ? AppColors.success : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        mySub.status.icon,
                        color: mySub.status.color,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Text(
                        mySub.status.localizedLabel(context),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: mySub.status.color,
                        ),
                      ),
                    ],
                  ),
                  if (isReviewed && mySub.score != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s12,
                        vertical: AppSpacing.s6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSmall,
                        ),
                      ),
                      child: Text(
                        l10n.gradeScorePrefix(
                          mySub.score.toString(),
                          assignment.maxScore.toString(),
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                l10n.submittedAtDateAttempt(
                  dateFormat.format(mySub.submittedAt),
                  mySub.attemptNumber.toString(),
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),

              // Teacher Feedback if available
              if (mySub.teacherFeedback != null &&
                  mySub.teacherFeedback!.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: AppSpacing.s12),
                Row(
                  children: [
                    const Icon(
                      Icons.rate_review_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.s6),
                    Text(
                      l10n.teacherFeedbackTitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s6),
                Text(
                  mySub.teacherFeedback!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s20),
      ],
    );
  }
}
