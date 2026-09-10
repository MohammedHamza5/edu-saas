import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/child_entity.dart';

class ParentAcademicOverviewCard extends StatelessWidget {
  final ChildAcademicSummary summary;

  const ParentAcademicOverviewCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final attendanceColor = summary.attendancePercentage >= 85
        ? AppColors.success
        : summary.attendancePercentage >= 70
        ? AppColors.warning
        : AppColors.error;

    final examScoreColor = summary.examsAverageScore >= 85
        ? AppColors.success
        : summary.examsAverageScore >= 70
        ? AppColors.warning
        : AppColors.error;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;

        final attendanceCard = RepaintBoundary(
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        context.l10n.attendanceRateLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.event_available_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  '${summary.attendancePercentage.toStringAsFixed(1)}%',
                  style: AppTypography.statFigureMedium.copyWith(
                    color: attendanceColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  child: LinearProgressIndicator(
                    value: (summary.attendancePercentage / 100).clamp(0.0, 1.0),
                    backgroundColor: attendanceColor.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(attendanceColor),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
                Text(
                  context.l10n.attendedClassesRatio(summary.presentCount, summary.totalClasses),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );

        final examCard = RepaintBoundary(
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        context.l10n.examsAverageLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.quiz_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  summary.examsCount > 0
                      ? '${summary.examsAverageScore.toStringAsFixed(1)}%'
                      : '—',
                  style: AppTypography.statFigureMedium.copyWith(
                    color: summary.examsCount > 0
                        ? examScoreColor
                        : AppColors.textSecondary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  child: LinearProgressIndicator(
                    value: summary.examsCount > 0
                        ? (summary.examsAverageScore / 100).clamp(0.0, 1.0)
                        : 0.0,
                    backgroundColor: examScoreColor.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(examScoreColor),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
                Text(
                  summary.examsCount > 0
                      ? context.l10n.verifiedExamsCount(summary.examsCount)
                      : context.l10n.noVerifiedExamsYet,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Two main stat cards
            if (isCompact) ...[
              attendanceCard,
              const SizedBox(height: AppSpacing.s12),
              examCard,
            ] else ...[
              Row(
                children: [
                  Expanded(child: attendanceCard),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(child: examCard),
                ],
              ),
            ],

            const SizedBox(height: AppSpacing.s16),

            // Enrolled groups chip section
            if (summary.enrolledGroups.isNotEmpty) ...[
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.groups_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Text(
                          context.l10n.enrolledStudyGroups,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Wrap(
                      spacing: AppSpacing.s8,
                      runSpacing: AppSpacing.s8,
                      children: summary.enrolledGroups.map((String groupName) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s12,
                            vertical: AppSpacing.s6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSmall,
                            ),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s6),
                              Text(
                                groupName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
            ],

            // Detailed Attendance Breakdown
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.pie_chart_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Text(
                        context.l10n.attendanceBreakdownTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Row(
                    children: [
                      _buildMiniStat(
                        context.l10n.statusPresent,
                        summary.presentCount,
                        AppColors.success,
                        Icons.check_circle_outline_rounded,
                      ),
                      _buildMiniStat(
                        context.l10n.statusAbsent,
                        summary.absentCount,
                        AppColors.error,
                        Icons.highlight_off_rounded,
                      ),
                      _buildMiniStat(
                        context.l10n.statusLate,
                        summary.lateCount,
                        AppColors.warning,
                        Icons.access_time_rounded,
                      ),
                      _buildMiniStat(
                        context.l10n.statusExcused,
                        summary.excusedCount,
                        AppColors.info,
                        Icons.info_outline_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMiniStat(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: RepaintBoundary(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(height: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
