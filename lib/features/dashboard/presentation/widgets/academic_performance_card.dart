import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/student_dashboard_stats.dart';

class AcademicPerformanceCard extends StatelessWidget {
  final StudentDashboardStats stats;

  const AcademicPerformanceCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: const Center(
                  child: Text(
                    '∑',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.academicMomentumTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stats.activeGroupName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.s16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  icon: Icons.percent_rounded,
                  color: AppColors.primary,
                  value: '${stats.examAverage.toStringAsFixed(1)}%',
                  label: context.l10n.statExamAverage,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  context,
                  icon: Icons.assignment_turned_in_rounded,
                  color: AppColors.success,
                  value: '${stats.assignmentsSubmitted}',
                  label: context.l10n.statAssignmentsDone,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  context,
                  icon: Icons.ondemand_video_rounded,
                  color: AppColors.warning,
                  value: '${stats.videoCompletionPercentage.toStringAsFixed(1)}%',
                  label: context.l10n.statVideoProgress,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: AppSpacing.s8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.statFigureLarge.copyWith(fontSize: 20),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
