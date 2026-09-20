import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../domain/entities/video_entity.dart';
import '../../domain/entities/video_progress_entity.dart';

class VideoCard extends StatelessWidget {
  final VideoEntity video;
  final VideoProgressEntity? progress;
  final VoidCallback onTap;

  const VideoCard({
    super.key,
    required this.video,
    this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = progress?.percentage ?? 0.0;
    final isCompleted = progress?.completed ?? false;

    return AppCard(
      variant: AppCardVariant.elevated,
      onTap: video.status.isReady ? onTap : null,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Thumbnail / Video Banner ──────────────────────────────
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppSpacing.radiusMedium),
                    ),
                  ),
                  child: video.thumbnailUrl != null
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppSpacing.radiusMedium),
                          ),
                          child: Image.network(
                            video.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(context),
                          ),
                        )
                      : _buildPlaceholder(context),
                ),
              ),

              // Play Icon Ambient Overlay (when ready)
              if (video.status.isReady)
                Positioned.fill(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.s10),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white60, width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),

              // Duration Badge (Start-Bottom)
              if (video.duration > 0)
                PositionedDirectional(
                  bottom: AppSpacing.s8,
                  start: AppSpacing.s8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video.formattedDuration,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Status Indicator Overlay (Processing / Failed)
              if (!video.status.isReady)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppSpacing.radiusMedium),
                      ),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.s8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (video.status.isProcessing) ...[
                              const AppLoadingView.compact(
                                size: 22,
                                color: Colors.white,
                              ),
                              const SizedBox(height: AppSpacing.s6),
                              Text(
                                context.l10n.videoProcessingMessage,
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                              ),
                            ] else if (video.status.isFailed) ...[
                              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 26),
                              const SizedBox(height: AppSpacing.s4),
                              Text(
                                context.l10n.videoProcessingFailed,
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Completion Badge (Top-End)
              if (isCompleted)
                PositionedDirectional(
                  top: AppSpacing.s8,
                  end: AppSpacing.s8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_rounded, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.statusCompleted,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // ── Progress Bar ──────────────────────────────────────────
          if (percentage > 0 && !isCompleted)
            LinearProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),

          // ── Video Details ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title ?? context.l10n.videoLessonUntitled,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (video.description != null && video.description!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    video.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.s8),
                Row(
                  children: [
                        Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            video.isYouTube
                                ? Icons.play_circle_fill_rounded
                                : Icons.verified_rounded,
                            size: 13,
                            color: video.isYouTube
                                ? const Color(0xFFFF0000)
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              video.isYouTube
                                  ? context.l10n.videoSourceBadgeYouTube
                                  : context.l10n.secureCdnBadge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: video.isYouTube
                                    ? const Color(0xFFFF0000)
                                    : AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (percentage > 0) ...[
                      const SizedBox(width: AppSpacing.s8),
                      Text(
                        context.l10n.watchedPercentage(percentage.toInt()),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isCompleted ? AppColors.success : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: AppColors.primary.withAlpha(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_fill_rounded,
              color: AppColors.primary.withAlpha(160),
              size: 42,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.videoLessonPlaceholder,
              style: TextStyle(
                color: AppColors.primary.withAlpha(160),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
