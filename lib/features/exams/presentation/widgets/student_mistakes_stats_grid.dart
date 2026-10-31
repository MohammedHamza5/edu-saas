import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../cubit/mistakes_state.dart';

class StudentMistakesStatsGrid extends StatelessWidget {
  final MistakesLoaded state;

  const StudentMistakesStatsGrid({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = state.summary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 600;
        final cardList = [
          _buildStatCard(
            context,
            label: l10n.unresolvedMistakesCount,
            count: summary.unresolvedCount,
            color: AppColors.warning,
            icon: Icons.pending_actions_rounded,
          ),
          _buildStatCard(
            context,
            label: l10n.resolvedMistakesCount,
            count: summary.resolvedCount,
            color: AppColors.success,
            icon: Icons.check_circle_rounded,
          ),
          _buildStatCard(
            context,
            label: l10n.totalMistakesCount,
            count: summary.totalMistakes,
            color: AppColors.info,
            icon: Icons.analytics_outlined,
          ),
          _buildBreakdownCard(
            context,
            wrongCount: state.unresolvedWrongCountInList,
            skippedCount: state.unresolvedSkippedCountInList,
          ),
        ];

        if (isSmall) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cardList[0]),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(child: cardList[1]),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              Row(
                children: [
                  Expanded(child: cardList[2]),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(child: cardList[3]),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cardList[0]),
            const SizedBox(width: AppSpacing.s8),
            Expanded(child: cardList[1]),
            const SizedBox(width: AppSpacing.s8),
            Expanded(child: cardList[2]),
            const SizedBox(width: AppSpacing.s8),
            Expanded(child: cardList[3]),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$count',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Icon(icon, color: color, size: 22),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard(
    BuildContext context, {
    required int wrongCount,
    required int skippedCount,
  }) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l10n.mistakesTypeBreakdown,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: Text(
                  '❌ $wrongCount',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: Text(
                  '⏸️ $skippedCount',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
