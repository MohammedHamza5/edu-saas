import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/assignment_entity.dart';

/// Card displaying assignment metadata, deadline, and instructions
class AssignmentDetailsInfoCard extends StatelessWidget {
  final AssignmentEntity assignment;
  final DateFormat dateFormat;

  const AssignmentDetailsInfoCard({
    super.key,
    required this.assignment,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isOverdue = assignment.isOverdue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Assignment Info Card
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assignment.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (assignment.groupName != null) ...[
                          const SizedBox(height: AppSpacing.s4),
                          Text(
                            l10n.groupLabelPrefix(assignment.groupName!),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s10,
                      vertical: AppSpacing.s6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                    ),
                    child: Text(
                      l10n.maxScorePoints(assignment.maxScore.toString()),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: AppSpacing.s12),

              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: isOverdue ? AppColors.error : AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.s6),
                  Expanded(
                    child: Text(
                      assignment.dueAt != null
                          ? l10n.deadlinePrefix(
                              dateFormat.format(assignment.dueAt!),
                            )
                          : l10n.noDueDateSpecified,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isOverdue ? FontWeight.bold : FontWeight.normal,
                        color: isOverdue
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),

              if (assignment.allowLateSubmission) ...[
                const SizedBox(height: AppSpacing.s6),
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 14,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: AppSpacing.s6),
                    Text(
                      l10n.lateSubmissionAllowedNotice,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.info,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.s16),

        // Instructions Card
        if (assignment.instructions != null &&
            assignment.instructions!.trim().isNotEmpty) ...[
          Text(
            l10n.instructionsAndProblemsTitle,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Text(
              assignment.instructions!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s20),
        ],
      ],
    );
  }
}
