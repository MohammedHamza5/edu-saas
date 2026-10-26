import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/video_entity.dart';

class VideoPlayerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? groupName;
  final VideoEntity? currentVideo;
  final int? lessonIndex;
  final int? totalLessons;
  final VoidCallback onBack;

  const VideoPlayerAppBar({
    super.key,
    this.groupName,
    this.currentVideo,
    this.lessonIndex,
    this.totalLessons,
    required this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isYouTube = currentVideo?.isYouTube == true;

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            groupName ?? currentVideo?.title ?? l10n.watchLessonTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (lessonIndex != null && totalLessons != null)
            Text(
              '${l10n.lessonXofY(lessonIndex!, totalLessons!)} · ${currentVideo?.title ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.normal,
              ),
            )
          else if (currentVideo?.title != null && groupName != null)
            Text(
              currentVideo!.title!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsetsDirectional.only(end: AppSpacing.s16),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s10,
            vertical: AppSpacing.s4,
          ),
          decoration: BoxDecoration(
            color: isYouTube
                ? const Color(0xFFFF0000).withAlpha(15)
                : AppColors.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(
              color: isYouTube
                  ? const Color(0xFFFF0000).withAlpha(60)
                  : AppColors.primary.withAlpha(60),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isYouTube
                    ? Icons.play_circle_fill_rounded
                    : Icons.lock_outline_rounded,
                size: 13,
                color: isYouTube
                    ? const Color(0xFFFF0000)
                    : AppColors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                isYouTube
                    ? l10n.videoSourceBadgeYouTube
                    : l10n.secureCdnBadge,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isYouTube
                      ? const Color(0xFFFF0000)
                      : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
      leading: BackButton(onPressed: onBack),
    );
  }
}
