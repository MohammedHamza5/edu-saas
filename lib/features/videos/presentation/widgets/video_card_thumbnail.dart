import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/library_video_entity.dart';

/// Video thumbnail preview with status badges, provider indicator, duration, and play overlay.
class VideoCardThumbnail extends StatelessWidget {
  final LibraryVideoEntity video;
  final bool isHovered;
  final VoidCallback onPreview;
  final VoidCallback? onSync;

  const VideoCardThumbnail({
    super.key,
    required this.video,
    required this.isHovered,
    required this.onPreview,
    this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (video.thumbnailUrl != null)
            CachedNetworkImage(
              imageUrl: video.thumbnailUrl!,
              memCacheWidth: 400,
              maxWidthDiskCache: 600,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _thumbFallback(),
            )
          else
            _thumbFallback(),

          // Play Button overlay
          if (video.isReady)
            Positioned.fill(
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: isHovered ? 1.0 : 0.75,
                  child: InkWell(
                    onTap: onPreview,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Duration Badge
          if (video.duration > 0)
            PositionedDirectional(
              bottom: 6,
              end: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
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

          // Status Badge
          PositionedDirectional(
            top: 6,
            start: 6,
            child: _buildStatusBadge(context),
          ),

          // Provider Badge
          PositionedDirectional(
            top: 6,
            end: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                video.isBunny
                    ? l10n.videoSourceBunny
                    : l10n.videoSourceYoutube,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final l10n = context.l10n;
    if (video.isReady) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.success,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          l10n.statusReady,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (video.isProcessing) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onSync,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.statusProcessing,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (onSync != null) ...[
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.refresh_rounded,
                    size: 10,
                    color: Colors.white,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        l10n.statusFailed,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _thumbFallback() {
    return Container(
      color: AppColors.surfaceVariant,
      child: const Center(
        child: Icon(
          Icons.videocam_rounded,
          size: 36,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
