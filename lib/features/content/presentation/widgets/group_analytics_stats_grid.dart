import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// 4-card KPI metric grid for [GroupAnalyticsSheet].
class GroupAnalyticsStatsGrid extends StatelessWidget {
  final int totalActiveStudents;
  final int totalCourseViews;
  final int overallCourseProgress;
  final double? overallQuizzesAverage;

  const GroupAnalyticsStatsGrid({
    super.key,
    required this.totalActiveStudents,
    required this.totalCourseViews,
    required this.overallCourseProgress,
    this.overallQuizzesAverage,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 460;
        return GridView.count(
          crossAxisCount: isCompact ? 2 : 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppSpacing.s12,
          mainAxisSpacing: AppSpacing.s12,
          childAspectRatio: isCompact ? 1.3 : 1.15,
          children: [
            _buildMetricCard(
              title: l10n.activeStudentsCount,
              value: '$totalActiveStudents',
              icon: Icons.groups_rounded,
              color: AppColors.primary,
            ),
            _buildMetricCard(
              title: l10n.courseWatchEngagement,
              value: '$totalCourseViews',
              icon: Icons.play_circle_filled_rounded,
              color: const Color(0xFF0284C7),
            ),
            _buildMetricCard(
              title: l10n.overallCourseProgress,
              value: '$overallCourseProgress%',
              icon: Icons.trending_up_rounded,
              color: AppColors.success,
            ),
            _buildMetricCard(
              title: l10n.overallQuizzesAverage,
              value: overallQuizzesAverage != null
                  ? '${overallQuizzesAverage!.toStringAsFixed(0)}%'
                  : '--',
              icon: Icons.military_tech_rounded,
              color: const Color(0xFFD97706),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
