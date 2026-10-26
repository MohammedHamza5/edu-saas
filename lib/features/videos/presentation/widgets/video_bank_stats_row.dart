import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class VideoBankStatsRow extends StatelessWidget {
  final int totalVideos;
  final int totalFolders;
  final int readyVideos;
  final int usedVideos;

  const VideoBankStatsRow({
    super.key,
    required this.totalVideos,
    required this.totalFolders,
    required this.readyVideos,
    required this.usedVideos,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        final card1 = _StatCard(
          icon: Icons.video_collection_outlined,
          value: '$totalVideos',
          label: l10n.videoBankCmsTitle,
          color: AppColors.primary,
        );
        final card2 = _StatCard(
          icon: Icons.folder_rounded,
          value: '$totalFolders',
          label: l10n.rootFolderTitle,
          color: Colors.amber.shade700,
        );
        final card3 = _StatCard(
          icon: Icons.check_circle_outline_rounded,
          value: '$readyVideos',
          label: l10n.statusReady,
          color: AppColors.success,
        );
        final card4 = _StatCard(
          icon: Icons.school_rounded,
          value: '$usedVideos',
          label: l10n.filterUsedInCourses,
          color: Colors.purple.shade600,
        );

        if (isMobile) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(child: card2),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              Row(
                children: [
                  Expanded(child: card3),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(child: card4),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: card1),
            const SizedBox(width: AppSpacing.s8),
            Expanded(child: card2),
            const SizedBox(width: AppSpacing.s8),
            Expanded(child: card3),
            const SizedBox(width: AppSpacing.s8),
            Expanded(child: card4),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
