import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/video_entity.dart';

class VideoLessonNotesCard extends StatelessWidget {
  final VideoEntity? video;

  const VideoLessonNotesCard({
    super.key,
    required this.video,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            video?.title ?? context.l10n.defaultLessonTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: [
              Icon(
                video?.isYouTube == true
                    ? Icons.play_circle_fill_rounded
                    : Icons.verified_user_rounded,
                size: 14,
                color: video?.isYouTube == true
                    ? const Color(0xFFFF0000)
                    : AppColors.primary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  video?.isYouTube == true
                      ? context.l10n.videoSourceBadgeYouTube
                      : context.l10n.protectedStreamCdnNotice,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (video?.description != null && video!.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s12),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.s12),
            Text(
              context.l10n.lessonNotesAndTopics,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.s6),
            Text(
              video!.description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
