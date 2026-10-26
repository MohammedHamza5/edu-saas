import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/exam_entity.dart';

/// Available filter states for student exams
enum StudentExamFilter { all, available, inProgress, completed }

/// Statistical and performance summary card at the top of the student exams page
class StudentExamsOverviewHub extends StatelessWidget {
  final List<ExamEntity> allExams;
  final StudentExamFilter activeFilter;
  final ValueChanged<StudentExamFilter> onFilterChanged;

  const StudentExamsOverviewHub({
    super.key,
    required this.allExams,
    required this.activeFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final totalCount = allExams.length;
    final completedCount = allExams.where((e) => e.isFullyCompleted).length;
    final inProgressCount = allExams.where((e) => e.hasActiveAttempt).length;
    final availableCount = allExams
        .where(
          (e) => !e.hasAttempted || (!e.isFullyCompleted && !e.hasActiveAttempt),
        )
        .length;
    final overallProgress = totalCount > 0
        ? (completedCount / totalCount).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s6),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                    ),
                    child: Icon(
                      Icons.insights_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Flexible(
                    child: Text(
                      context.l10n.studentExamsOverviewTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: AppSpacing.s4,
                ),
                decoration: BoxDecoration(
                  color: (completedCount == totalCount && totalCount > 0)
                      ? AppColors.success.withValues(alpha: 0.12)
                      : Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      (completedCount == totalCount && totalCount > 0)
                          ? Icons.check_circle_rounded
                          : Icons.pie_chart_outline_rounded,
                      size: 13,
                      color: (completedCount == totalCount && totalCount > 0)
                          ? AppColors.success
                          : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(overallProgress * 100).toInt()}% ${context.l10n.studentExamsOverallProgress}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: (completedCount == totalCount && totalCount > 0)
                            ? AppColors.success
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            child: LinearProgressIndicator(
              value: overallProgress,
              minHeight: 6,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                overallProgress >= 1.0
                    ? AppColors.success
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          LayoutBuilder(
            builder: (context, kpiConstraints) {
              final isVeryNarrow = kpiConstraints.maxWidth < 340;
              if (isVeryNarrow) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildKpiTile(
                            title: context.l10n.studentExamsStatsTotal,
                            count: totalCount,
                            icon: Icons.assignment_outlined,
                            color: Theme.of(context).colorScheme.primary,
                            isSelected: activeFilter == StudentExamFilter.all,
                            onTap: () => onFilterChanged(StudentExamFilter.all),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: _buildKpiTile(
                            title: context.l10n.studentExamsStatsCompleted,
                            count: completedCount,
                            icon: Icons.check_circle_rounded,
                            color: AppColors.success,
                            isSelected:
                                activeFilter == StudentExamFilter.completed,
                            onTap: () =>
                                onFilterChanged(StudentExamFilter.completed),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildKpiTile(
                            title: context.l10n.studentExamsStatsInProgress,
                            count: inProgressCount,
                            icon: Icons.hourglass_top_rounded,
                            color: AppColors.warning,
                            isSelected:
                                activeFilter == StudentExamFilter.inProgress,
                            onTap: () =>
                                onFilterChanged(StudentExamFilter.inProgress),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: _buildKpiTile(
                            title: context.l10n.studentExamsStatsAvailable,
                            count: availableCount,
                            icon: Icons.rocket_launch_outlined,
                            color: const Color(0xFF0284C7),
                            isSelected:
                                activeFilter == StudentExamFilter.available,
                            onTap: () =>
                                onFilterChanged(StudentExamFilter.available),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _buildKpiTile(
                      title: context.l10n.studentExamsStatsTotal,
                      count: totalCount,
                      icon: Icons.assignment_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      isSelected: activeFilter == StudentExamFilter.all,
                      onTap: () => onFilterChanged(StudentExamFilter.all),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: _buildKpiTile(
                      title: context.l10n.studentExamsStatsCompleted,
                      count: completedCount,
                      icon: Icons.check_circle_rounded,
                      color: AppColors.success,
                      isSelected: activeFilter == StudentExamFilter.completed,
                      onTap: () => onFilterChanged(StudentExamFilter.completed),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: _buildKpiTile(
                      title: context.l10n.studentExamsStatsInProgress,
                      count: inProgressCount,
                      icon: Icons.hourglass_top_rounded,
                      color: AppColors.warning,
                      isSelected: activeFilter == StudentExamFilter.inProgress,
                      onTap: () => onFilterChanged(StudentExamFilter.inProgress),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: _buildKpiTile(
                      title: context.l10n.studentExamsStatsAvailable,
                      count: availableCount,
                      icon: Icons.rocket_launch_outlined,
                      color: const Color(0xFF0284C7),
                      isSelected: activeFilter == StudentExamFilter.available,
                      onTap: () => onFilterChanged(StudentExamFilter.available),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKpiTile({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s6,
          vertical: AppSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : AppColors.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.4)
                : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
