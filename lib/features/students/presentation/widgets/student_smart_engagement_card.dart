import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/student_360_entity.dart';

/// Smart engagement card displaying active vs idle telemetry, quality badge,
/// and daily login metrics.
class StudentSmartEngagementCard extends StatelessWidget {
  final Student360Entity stats;

  const StudentSmartEngagementCard({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final quality = stats.engagementQuality;
    final (qualityLabel, qualityColor, qualityIcon) = switch (quality) {
      EngagementQuality.active => (
        context.l10n.qualityActive,
        AppColors.success,
        Icons.verified_rounded,
      ),
      EngagementQuality.moderate => (
        context.l10n.qualityModerate,
        AppColors.warning,
        Icons.timelapse_rounded,
      ),
      EngagementQuality.ghostPresence => (
        context.l10n.qualityGhostPresence,
        AppColors.error,
        Icons.warning_amber_rounded,
      ),
      EngagementQuality.noData => (
        context.l10n.qualityNoData,
        AppColors.textMuted,
        Icons.bedtime_outlined,
      ),
    };

    final activeMins = stats.todayActiveMinutes;
    final idleMins = stats.todayIdleMinutes;
    final activeRatio = (stats.todayActiveRatio * 100).round();

    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 420;
              final badgeWidget = Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: qualityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                    color: qualityColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(qualityIcon, size: 13, color: qualityColor),
                    const SizedBox(width: 4),
                    Text(
                      qualityLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: qualityColor,
                      ),
                    ),
                  ],
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.s8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSmall,
                            ),
                          ),
                          child: const Icon(
                            Icons.insights_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        Expanded(
                          child: Text(
                            context.l10n.smartTelemetryTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    Text(
                      context.l10n.smartTelemetryDesc,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    badgeWidget,
                  ],
                );
              }

              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.smartTelemetryTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          context.l10n.smartTelemetryDesc,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  badgeWidget,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.s16),
          // Progress bar of active vs idle
          if (activeMins > 0 || idleMins > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Expanded(
                      flex: activeMins > 0 ? activeMins : 1,
                      child: Container(color: AppColors.success),
                    ),
                    if (idleMins > 0)
                      Expanded(
                        flex: idleMins,
                        child: Container(
                          color: AppColors.warning.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.l10n.activeMinutesWithRatio(
                        activeMins,
                        activeRatio,
                      ),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.l10n.idleMinutesWithCount(idleMins),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
          ],
          // Metrics Grid
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MiniTelemetryItem(
                    icon: Icons.timer_outlined,
                    label: context.l10n.activeTodayLabel,
                    value: context.l10n.minutesShort(activeMins),
                    valueColor: AppColors.success,
                  ),
                ),
                Container(width: 1, height: 30, color: AppColors.border),
                Expanded(
                  child: _MiniTelemetryItem(
                    icon: Icons.pause_circle_outline,
                    label: context.l10n.idleTodayLabel,
                    value: context.l10n.minutesShort(idleMins),
                    valueColor: AppColors.warning,
                  ),
                ),
                Container(width: 1, height: 30, color: AppColors.border),
                Expanded(
                  child: _MiniTelemetryItem(
                    icon: Icons.login_rounded,
                    label: context.l10n.firstLoginLabel,
                    value: stats.firstSeenToday != null
                        ? _formatTimeOnly(context, stats.firstSeenToday!)
                        : '—',
                  ),
                ),
                Container(width: 1, height: 30, color: AppColors.border),
                Expanded(
                  child: _MiniTelemetryItem(
                    icon: Icons.date_range_rounded,
                    label: context.l10n.active7DaysLabel,
                    value: context.l10n.minutesShort(
                      stats.totalActiveMinutes7d,
                    ),
                    valueColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTimeOnly(BuildContext context, DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12
        ? context.l10n.pmPeriod
        : context.l10n.amPeriod;
    return '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period';
  }
}

class _MiniTelemetryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _MiniTelemetryItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: valueColor ?? AppColors.textPrimary,
          ),
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
