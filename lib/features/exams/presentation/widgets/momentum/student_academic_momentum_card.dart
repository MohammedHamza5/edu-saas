import 'package:flutter/material.dart';
import 'package:edu_saas/core/extensions/localized_context_extension.dart';
import 'package:edu_saas/core/theme/app_colors.dart';
import 'package:edu_saas/core/theme/app_spacing.dart';
import 'package:edu_saas/core/widgets/app_card.dart';
import 'package:edu_saas/features/exams/domain/entities/academic_momentum_entity.dart';
import 'mastery_badges_sheet.dart';
import 'predicted_score_band_widget.dart';
import 'streak_fire_widget.dart';

class StudentAcademicMomentumCard extends StatelessWidget {
  final AcademicMomentumEntity momentum;

  const StudentAcademicMomentumCard({
    super.key,
    required this.momentum,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return AppCard(
      variant: AppCardVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Streak Fire Header
          StreakFireWidget(momentum: momentum),
          const SizedBox(height: AppSpacing.s12),

          // 2. Predicted SAT Score Band
          PredictedScoreBandWidget(momentum: momentum),
          const SizedBox(height: AppSpacing.s12),

          // 3. Badges Row Header & Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.earnedBadgesTitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              InkWell(
                onTap: () => MasteryBadgesSheet.show(context, momentum.badges),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.viewAllBadges,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF4F46E5)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s6),

          // 4. Badges Preview Wrap
          Wrap(
            spacing: AppSpacing.s6,
            runSpacing: AppSpacing.s6,
            children: momentum.badges.map((badge) {
              return _buildMiniBadgeChip(context, badge);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadgeChip(BuildContext context, AcademicBadgeEntity badge) {
    final l10n = context.l10n;
    final (label, icon) = _getBadgeLabelAndIcon(badge.type, l10n);

    return InkWell(
      onTap: () => MasteryBadgesSheet.show(context, momentum.badges),
      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: badge.isUnlocked
              ? const Color(0xFF4F46E5).withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          border: Border.all(
            color: badge.isUnlocked
                ? const Color(0xFF4F46E5).withValues(alpha: 0.35)
                : Colors.grey.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: badge.isUnlocked ? const Color(0xFF4F46E5) : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: badge.isUnlocked ? FontWeight.bold : FontWeight.normal,
                color: badge.isUnlocked ? const Color(0xFF4F46E5) : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, IconData) _getBadgeLabelAndIcon(AcademicBadgeType type, dynamic l10n) {
    switch (type) {
      case AcademicBadgeType.gauntletSlayer:
        return (l10n.badgeGauntletSlayer as String, Icons.shield_rounded);
      case AcademicBadgeType.consistencyKing:
        return (l10n.badgeConsistencyKing as String, Icons.local_fire_department_rounded);
      case AcademicBadgeType.speedDemon:
        return (l10n.badgeSpeedDemon as String, Icons.bolt_rounded);
      case AcademicBadgeType.highAchiever:
        return (l10n.badgeHighAchiever as String, Icons.stars_rounded);
    }
  }
}
