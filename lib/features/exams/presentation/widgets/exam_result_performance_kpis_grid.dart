import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/exam_entity.dart';

class ExamResultPerformanceKpisGrid extends StatelessWidget {
  final int correctCount;
  final int incorrectCount;
  final int skippedCount;
  final Duration? duration;
  final ExamEntity exam;

  const ExamResultPerformanceKpisGrid({
    super.key,
    required this.correctCount,
    required this.incorrectCount,
    required this.skippedCount,
    required this.duration,
    required this.exam,
  });

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    if (d.inHours > 0) {
      final hours = d.inHours;
      return '${hours.toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            context.l10n.detailedPerformanceAnalytics,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                context,
                title: context.l10n.correctAnswersMetric,
                value: '$correctCount',
                subtitle: context.l10n.questions,
                color: AppColors.success,
                icon: Icons.check_circle_outline_rounded,
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: _buildKpiCard(
                context,
                title: context.l10n.incorrectAnswersMetric,
                value: '$incorrectCount',
                subtitle: context.l10n.questions,
                color: AppColors.error,
                icon: Icons.cancel_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                context,
                title: context.l10n.skippedAnswersMetric,
                value: '$skippedCount',
                subtitle: context.l10n.questions,
                color: AppColors.warning,
                icon: Icons.pause_circle_outline_rounded,
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: _buildKpiCard(
                context,
                title: context.l10n.timeSpentMetric,
                value: duration != null ? _formatDuration(duration!) : '--:--',
                subtitle: exam.isUntimed
                    ? context.l10n.unlimitedTime
                    : context.l10n.minutesDuration(
                        exam.durationMinutes,
                      ),
                color: AppColors.primary,
                icon: Icons.timer_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
