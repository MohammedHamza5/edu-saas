import 'package:flutter/material.dart';
import 'package:edu_saas/core/extensions/localized_context_extension.dart';
import 'package:edu_saas/core/theme/app_colors.dart';
import 'package:edu_saas/core/theme/app_spacing.dart';
import 'package:edu_saas/features/exams/domain/entities/academic_momentum_entity.dart';

class MasteryBadgesSheet extends StatelessWidget {
  final List<AcademicBadgeEntity> badges;

  const MasteryBadgesSheet({
    super.key,
    required this.badges,
  });

  static void show(BuildContext context, List<AcademicBadgeEntity> badges) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLarge),
        ),
      ),
      builder: (_) => MasteryBadgesSheet(badges: badges),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s20,
          vertical: AppSpacing.s16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(
              l10n.allBadgesDialogTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s16),
            ...badges.map((b) => _buildBadgeTile(context, b)),
            const SizedBox(height: AppSpacing.s12),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeTile(BuildContext context, AcademicBadgeEntity badge) {
    final l10n = context.l10n;
    final (title, desc, icon) = _getBadgeInfo(badge.type, l10n);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: badge.isUnlocked
            ? const Color(0xFF4F46E5).withValues(alpha: 0.06)
            : AppColors.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(
          color: badge.isUnlocked
              ? const Color(0xFF4F46E5).withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s8),
            decoration: BoxDecoration(
              color: badge.isUnlocked
                  ? const Color(0xFF4F46E5).withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            ),
            child: Icon(
              icon,
              size: 20,
              color: badge.isUnlocked ? const Color(0xFF4F46E5) : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badge.isUnlocked
                  ? AppColors.success.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            ),
            child: Text(
              badge.isUnlocked ? l10n.badgeUnlockedStatus : l10n.badgeLockedStatus,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: badge.isUnlocked ? AppColors.success : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (String, String, IconData) _getBadgeInfo(AcademicBadgeType type, dynamic l10n) {
    switch (type) {
      case AcademicBadgeType.gauntletSlayer:
        return (l10n.badgeGauntletSlayer as String, l10n.badgeGauntletSlayerDesc as String, Icons.shield_rounded);
      case AcademicBadgeType.consistencyKing:
        return (l10n.badgeConsistencyKing as String, l10n.badgeConsistencyKingDesc as String, Icons.local_fire_department_rounded);
      case AcademicBadgeType.speedDemon:
        return (l10n.badgeSpeedDemon as String, l10n.badgeSpeedDemonDesc as String, Icons.bolt_rounded);
      case AcademicBadgeType.highAchiever:
        return (l10n.badgeHighAchiever as String, l10n.badgeHighAchieverDesc as String, Icons.stars_rounded);
    }
  }
}
