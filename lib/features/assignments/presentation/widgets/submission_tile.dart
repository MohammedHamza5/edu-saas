import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/assignment_entity.dart';

class SubmissionTile extends StatelessWidget {
  final AssignmentSubmissionEntity submission;
  final int maxScore;
  final VoidCallback onTap;

  const SubmissionTile({
    super.key,
    required this.submission,
    required this.maxScore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd - hh:mm a');
    final isReviewed = submission.isReviewed;

    return AppCard(
      onTap: onTap,
      variant: AppCardVariant.standard,
      padding: const EdgeInsets.all(AppSpacing.s12),
      child: Row(
        children: [
          // Student Avatar / Initials
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              submission.studentName.isNotEmpty
                  ? submission.studentName.characters.first.toUpperCase()
                  : context.l10n.studentInitialDefault,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),

          // Student name & submission time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        submission.studentName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (submission.attemptNumber > 1) ...[
                      const SizedBox(width: AppSpacing.s6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                        ),
                        child: Text(
                          context.l10n.attemptNumberLabel(submission.attemptNumber.toString()),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  dateFormat.format(submission.submittedAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                if (submission.files.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s4),
                  Row(
                    children: [
                      const Icon(
                        Icons.attach_file,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        context.l10n.attachedFilesCount(submission.files.length.toString()),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.s8),

          // Status and Score display
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: AppSpacing.s4,
                ),
                decoration: BoxDecoration(
                  color: submission.status.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: Text(
                  submission.status.localizedLabel(context),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: submission.status.color,
                  ),
                ),
              ),
              if (isReviewed && submission.score != null) ...[
                const SizedBox(height: AppSpacing.s4),
                Text(
                  '${submission.score}/$maxScore',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(width: AppSpacing.s4),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
        ],
      ),
    );
  }
}
