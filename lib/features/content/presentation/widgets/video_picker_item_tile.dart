import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/content_entity.dart';

/// Single item tile in the video picker sheet with thumbnail, selection indicator,
/// and group assignment badges.
class VideoPickerItemTile extends StatelessWidget {
  final ContentEntity video;
  final bool isSelected;
  final bool isAlreadyAdded;
  final VoidCallback onTap;

  const VideoPickerItemTile({
    super.key,
    required this.video,
    required this.isSelected,
    required this.isAlreadyAdded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final youtubeId = video.videoProviderId;
    final thumbUrl = (youtubeId != null && youtubeId.isNotEmpty)
        ? 'https://img.youtube.com/vi/$youtubeId/mqdefault.jpg'
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : isAlreadyAdded
                  ? AppColors.success.withValues(alpha: 0.04)
                  : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.5)
                : isAlreadyAdded
                    ? AppColors.success.withValues(alpha: 0.35)
                    : AppColors.border.withValues(alpha: 0.5),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 72,
                height: 48,
                color: isAlreadyAdded
                    ? AppColors.success.withValues(alpha: 0.08)
                    : AppColors.primary.withValues(alpha: 0.08),
                child: thumbUrl != null
                    ? CachedNetworkImage(
                        imageUrl: thumbUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          isAlreadyAdded
                              ? Icons.task_alt_rounded
                              : Icons.play_circle_fill_rounded,
                          color: isAlreadyAdded
                              ? AppColors.success
                              : AppColors.primary,
                          size: 24,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    video.videoProvider == 'youtube'
                        ? context.l10n.videoSourceYoutube
                        : context.l10n.videoSourceBunny,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  if (isAlreadyAdded) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 13,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              context.l10n.videoAlreadyAddedToThisGroup,
                              style: const TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (video.assignedGroupNames.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.videoAddedToGroups(
                        video.assignedGroupNames.join('، '),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.videoNotAddedToAnyGroup,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 22,
              )
            else
              const Icon(
                Icons.radio_button_unchecked_rounded,
                color: AppColors.border,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
