import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/video_folder_entity.dart';

class VideoBankBreadcrumbsBar extends StatelessWidget {
  final double hPadding;
  final bool isInsideFolder;
  final List<VideoFolderEntity> breadcrumbs;
  final VoidCallback onNavigateUp;
  final ValueChanged<int> onNavigateToBreadcrumb;

  const VideoBankBreadcrumbsBar({
    super.key,
    required this.hPadding,
    required this.isInsideFolder,
    required this.breadcrumbs,
    required this.onNavigateUp,
    required this.onNavigateToBreadcrumb,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: hPadding,
        vertical: AppSpacing.s8,
      ),
      color: AppColors.surfaceVariant.withValues(alpha: 0.3),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (isInsideFolder)
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: 18,
                ),
                tooltip: l10n.backTooltip,
                onPressed: onNavigateUp,
              ),
            InkWell(
              onTap: () => onNavigateToBreadcrumb(-1),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.home_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.rootFolderTitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            for (int i = 0; i < breadcrumbs.length; i++) ...[
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppColors.textMuted,
              ),
              InkWell(
                onTap: () => onNavigateToBreadcrumb(i),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Text(
                    breadcrumbs[i].name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: i == breadcrumbs.length - 1
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: i == breadcrumbs.length - 1
                          ? AppColors.textPrimary
                          : AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
