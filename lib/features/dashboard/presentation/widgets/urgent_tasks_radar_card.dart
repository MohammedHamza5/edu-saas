import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/student_dashboard_stats.dart';

class UrgentTasksRadarCard extends StatelessWidget {
  final List<UrgentTaskItem> tasks;

  const UrgentTasksRadarCard({
    super.key,
    required this.tasks,
  });

  String _formatDueRemaining(BuildContext context, DateTime dueAt) {
    final now = DateTime.now();
    final diff = dueAt.difference(now);

    if (diff.isNegative) {
      return context.l10n.overdue;
    } else if (diff.inHours < 24) {
      final hours = diff.inHours > 0 ? diff.inHours : 1;
      return context.l10n.dueInHours(hours);
    } else if (diff.inDays == 1) {
      return context.l10n.dueTomorrow;
    } else {
      return context.l10n.dueInDays(diff.inDays);
    }
  }

  Color _getUrgencyColor(DateTime? dueAt) {
    if (dueAt == null) return AppColors.primary;
    final now = DateTime.now();
    final diff = dueAt.difference(now);
    if (diff.isNegative || diff.inHours < 24) {
      return AppColors.error;
    } else if (diff.inDays <= 2) {
      return AppColors.warning;
    }
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (tasks.isEmpty) {
      return AppCard(
        variant: AppCardVariant.elevated,
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.success,
                size: 26,
              ),
            ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.noUrgentTasks,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.noUrgentTasksSubtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: const Icon(
                  Icons.alarm_on_rounded,
                  color: AppColors.warning,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.urgentTasksTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      context.l10n.urgentTasksSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),

          // List of Tasks
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tasks.length.clamp(0, 3),
            separatorBuilder: (_, __) => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.s8),
              child: Divider(height: 1, color: AppColors.border),
            ),
            itemBuilder: (ctx, index) {
              final task = tasks[index];
              final isAssignment = task.taskType == 'assignment';
              final urgencyColor = _getUrgencyColor(task.dueAt);

              return InkWell(
                onTap: () {
                  if (isAssignment) {
                    context.go(AppRoutes.studentAssignments);
                  } else {
                    context.go(AppRoutes.studentExams);
                  }
                },
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      // Icon badge
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: (isAssignment ? AppColors.primary : const Color(0xFF7C3AED))
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                        ),
                        child: Icon(
                          isAssignment
                              ? Icons.assignment_rounded
                              : Icons.quiz_rounded,
                          size: 18,
                          color: isAssignment ? AppColors.primary : const Color(0xFF7C3AED),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),

                      // Title and Group name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${task.groupName} • ${isAssignment ? context.l10n.taskTypeAssignment : context.l10n.taskTypeExam}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Due badge
                      if (task.dueAt != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: urgencyColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                            border: Border.all(
                              color: urgencyColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            _formatDueRemaining(context, task.dueAt!),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: urgencyColor,
                            ),
                          ),
                        ),
                      const SizedBox(width: AppSpacing.s8),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
