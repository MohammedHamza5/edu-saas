import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/exam_parent_dispatch_entity.dart';
import '../cubit/exam_dispatch_state.dart';

/// Hero KPI statistics banner displaying exam summary and 4 key metric tiles.
class ExamDispatchHeroBanner extends StatelessWidget {
  final ExamDispatchMetaEntity exam;
  final ExamDispatchStatsEntity stats;
  final ExamDispatchLoaded state;

  const ExamDispatchHeroBanner({
    super.key,
    required this.exam,
    required this.stats,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final notifiedCount = state.notifiedCount;
    final totalAssigned = stats.totalAssignedStudents;
    final submittedCount = stats.submittedCount;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exam Title & Groups Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: const Icon(
                  Icons.assignment_turned_in_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${context.l10n.scorePoints(exam.maxScore)}${exam.passingScore != null ? ' • ${context.l10n.passingScoreLabel}: ${exam.passingScore}%' : ''}${exam.primaryGroupName != null ? ' • ${exam.primaryGroupName}' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),

          // 4 KPI Metric Cards Grid
          Row(
            children: [
              // Submissions
              Expanded(
                child: _buildMetricTile(
                  title: context.l10n.metricSubmissionsRateTitle,
                  value: '$submittedCount / $totalAssigned',
                  subtitle: '${stats.submissionRate.toStringAsFixed(0)}%',
                  accentColor: const Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),

              // Average Score
              Expanded(
                child: _buildMetricTile(
                  title: context.l10n.metricAverageScoreTitle,
                  value: '${stats.averageScore} / ${exam.maxScore}',
                  subtitle: '${stats.averagePercentage.toStringAsFixed(0)}%',
                  accentColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),

              // Pass Rate
              Expanded(
                child: _buildMetricTile(
                  title: context.l10n.metricPassRateTitle,
                  value: '${stats.passedCount} / $submittedCount',
                  subtitle: '${stats.passRate.toStringAsFixed(0)}%',
                  accentColor: AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),

              // WhatsApp Dispatched
              Expanded(
                child: _buildMetricTile(
                  title: context.l10n.metricWhatsAppDispatchedTitle,
                  value: '$notifiedCount / $totalAssigned',
                  subtitle: context.l10n.notifiedBadgeShort,
                  accentColor: const Color(0xFF16A34A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
