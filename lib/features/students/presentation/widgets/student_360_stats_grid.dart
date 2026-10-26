import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/extensions/responsive_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/responsive_grid.dart';
import '../../domain/entities/student_360_entity.dart';

/// Section title helper with standard academic typography.
class StudentSectionTitle extends StatelessWidget {
  final String text;

  const StudentSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppColors.textSecondary,
      letterSpacing: 0.3,
    ),
  );
}

/// Academic performance stats grid (attendance, assignments, exams, videos).
class Student360StatsGrid extends StatelessWidget {
  final Student360Entity stats;

  const Student360StatsGrid({
    super.key,
    required this.stats,
  });

  static Color pctColor(double pct) {
    if (pct >= 75) return AppColors.success;
    if (pct >= 50) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StudentSectionTitle(context.l10n.statsOverviewTitle),
        const SizedBox(height: AppSpacing.s8),
        ResponsiveGrid(
          mobileColumns: 2,
          tabletColumns: 2,
          desktopColumns: 4,
          largeDesktopColumns: 4,
          spacing: AppSpacing.s12,
          runSpacing: AppSpacing.s12,
          children: [
            Student360StatCard(
              icon: Icons.fact_check_rounded,
              label: context.l10n.attendanceRateLabel,
              value: '${stats.attendancePercentage.toStringAsFixed(0)}%',
              progress: (stats.attendancePercentage / 100).clamp(0.0, 1.0),
              color: pctColor(stats.attendancePercentage),
            ),
            Student360StatCard(
              icon: Icons.assignment_turned_in_rounded,
              label: context.l10n.submittedHomeworksLabel,
              value: '${stats.assignmentsSubmitted}',
              subtitle: context.l10n.reviewedSubtitle(
                stats.assignmentsReviewed,
              ),
              progress: stats.assignmentsSubmitted > 0
                  ? (stats.assignmentsReviewed / stats.assignmentsSubmitted)
                      .clamp(0.0, 1.0)
                  : null,
              color: AppColors.info,
            ),
            Student360StatCard(
              icon: Icons.quiz_rounded,
              label: context.l10n.examAverageLabel,
              value: '${stats.examAverage.toStringAsFixed(0)}%',
              progress: (stats.examAverage / 100).clamp(0.0, 1.0),
              color: pctColor(stats.examAverage),
            ),
            Student360StatCard(
              icon: Icons.play_circle_rounded,
              label: context.l10n.videoCompletionLabel,
              value: '${stats.videoCompletionPercentage.toStringAsFixed(0)}%',
              progress: (stats.videoCompletionPercentage / 100).clamp(0.0, 1.0),
              color: pctColor(stats.videoCompletionPercentage),
            ),
          ],
        ),
      ],
    );
  }
}

/// Compact stat card with progress bar.
class Student360StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final double? progress;
  final Color color;

  const Student360StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = context.screenWidth < 360;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppSpacing.s6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            value,
            style: (isCompact
                    ? AppTypography.headingLarge
                    : AppTypography.statFigureLarge)
                .copyWith(color: color),
          ),
          if (progress != null) ...[
            const SizedBox(height: AppSpacing.s6),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              child: LinearProgressIndicator(
                value: progress!,
                backgroundColor: AppColors.background,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 4,
              ),
            ),
          ],
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
