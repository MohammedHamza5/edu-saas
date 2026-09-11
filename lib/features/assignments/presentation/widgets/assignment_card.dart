import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/assignment_entity.dart';

class AssignmentCard extends StatelessWidget {
  final AssignmentEntity assignment;
  final VoidCallback onTap;
  final bool isTeacher;

  const AssignmentCard({
    super.key,
    required this.assignment,
    required this.onTap,
    this.isTeacher = false,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd - hh:mm a');
    final isOverdue = assignment.isOverdue;

    return AppCard(
      onTap: onTap,
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: Title + Group / Status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (assignment.groupName != null) ...[
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        context.l10n.groupLabelPrefix(assignment.groupName!),
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

          if (assignment.instructions != null &&
              assignment.instructions!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(
              assignment.instructions!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: AppSpacing.s16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.s12),

          // Footer row: Due date & Meta info
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: isOverdue ? AppColors.error : AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.s4),
              Expanded(
                child: Text(
                  assignment.dueAt != null
                      ? context.l10n.dueAtPrefix(
                          dateFormat.format(assignment.dueAt!),
                        )
                      : context.l10n.noDueDate,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                    color: isOverdue ? AppColors.error : AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: AppSpacing.s4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: Text(
                  context.l10n.maxScorePoints(assignment.maxScore.toString()),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),

          // Teacher progress row: Submissions vs Reviewed count
          if (isTeacher) ...[
            const SizedBox(height: AppSpacing.s8),
            Row(
              children: [
                const Icon(
                  Icons.people_outline,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.s4),
                Expanded(
                  child: Text(
                    context.l10n.teacherAssignmentStats(
                      assignment.submissionsCount.toString(),
                      assignment.reviewedCount.toString(),
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

  Widget _buildStatusBadge(BuildContext context) {
    if (isTeacher) {
      final hasPending = assignment.submissionsCount > assignment.reviewedCount;
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: hasPending
              ? AppColors.warning.withValues(alpha: 0.15)
              : AppColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        ),
        child: Text(
          hasPending
              ? context.l10n.pendingReview
              : context.l10n.statusCompleted,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: hasPending ? AppColors.warning : AppColors.success,
          ),
        ),
      );
    }

    // Student view status
    final sub = assignment.mySubmission;
    if (sub == null) {
      final isOverdue = assignment.isOverdue;
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: isOverdue
              ? AppColors.error.withValues(alpha: 0.15)
              : AppColors.info.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        ),
        child: Text(
          isOverdue ? context.l10n.pastDue : context.l10n.actionRequired,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isOverdue ? AppColors.error : AppColors.info,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: sub.status.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(sub.status.icon, size: 12, color: sub.status.color),
          const SizedBox(width: AppSpacing.s4),
          Text(
            sub.isReviewed && sub.score != null
                ? '${sub.score}/${assignment.maxScore}'
                : sub.status.localizedLabel(context),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: sub.status.color,
            ),
          ),
        ],
      ),
    );
  }
}
