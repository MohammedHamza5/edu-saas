import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/student_academic_report_entity.dart';

class AcademicReportStatsBar extends StatelessWidget {
  final bool isLoading;
  final StudentAcademicReportEntity? reportData;

  const AcademicReportStatsBar({
    super.key,
    required this.isLoading,
    required this.reportData,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.s8,
          horizontal: AppSpacing.s12,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              l10n.whatsappFetchingData,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (reportData == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          AcademicReportStatBadge(
            icon: Icons.ondemand_video_rounded,
            label: l10n.whatsappLecturesStat,
            value:
                '${reportData!.videosWatched}/${reportData!.totalAssignedVideos}',
            color: AppColors.info,
          ),
          AcademicReportStatBadge(
            icon: Icons.assignment_outlined,
            label: l10n.whatsappAssignmentsStat,
            value:
                '${reportData!.assignmentsSubmitted}/${reportData!.totalAssignedAssignments}',
            color: AppColors.warning,
          ),
          AcademicReportStatBadge(
            icon: Icons.quiz_outlined,
            label: l10n.whatsappExamsStat,
            value: '${reportData!.avgExamPercentage.round()}%',
            color: AppColors.primary,
          ),
          AcademicReportStatBadge(
            icon: Icons.schedule_rounded,
            label: l10n.whatsappStudyTimeStat,
            value: '${reportData!.activeStudyMinutes}m',
            color: AppColors.success,
          ),
        ],
      ),
    );
  }
}

class AcademicReportStatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const AcademicReportStatBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
