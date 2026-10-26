import 'package:flutter/material.dart';
import 'package:edu_saas/core/extensions/localized_context_extension.dart';
import 'package:edu_saas/core/theme/app_colors.dart';
import 'package:edu_saas/core/theme/app_spacing.dart';
import 'package:edu_saas/features/exams/domain/entities/academic_momentum_entity.dart';

class StreakFireWidget extends StatelessWidget {
  final AcademicMomentumEntity momentum;

  const StreakFireWidget({
    super.key,
    required this.momentum,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final count = momentum.currentStreakDays;

    return Row(
      children: [
        // Flame Icon Container
        Container(
          padding: const EdgeInsets.all(AppSpacing.s10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: count > 0
                  ? [const Color(0xFFF97316), const Color(0xFFEA580C)]
                  : [Colors.grey.shade400, Colors.grey.shade600],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            boxShadow: count > 0
                ? [
                    BoxShadow(
                      color: const Color(0xFFF97316).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: const Icon(
            Icons.local_fire_department_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: AppSpacing.s12),

        // Text & Status
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.s8,
                runSpacing: 4,
                children: [
                  Text(
                    l10n.streakDaysCount(count),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: count > 0 ? const Color(0xFFEA580C) : AppColors.textSecondary,
                    ),
                  ),
                  if (momentum.longestStreakDays > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                      ),
                      child: Text(
                        l10n.longestStreakRecord(momentum.longestStreakDays),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                momentum.isTodayActive ? l10n.streakTodayDone : l10n.streakTodayPending,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: momentum.isTodayActive ? AppColors.success : AppColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: momentum.isTodayActive ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
