import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import 'interactive_lightbox_dialog.dart';

class ExamImageViewer extends StatelessWidget {
  final String imageUrl;
  final Map<String, dynamic>? imageMeta;
  final String? caption;

  const ExamImageViewer({
    super.key,
    required this.imageUrl,
    this.imageMeta,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final alignmentStr = imageMeta?['alignment'] as String? ?? 'center';
    final widthPercent = (imageMeta?['width_percent'] as num?)?.toInt() ?? 50;
    final enableZoom = imageMeta?['enable_zoom'] as bool? ?? true;

    Alignment align = Alignment.center;
    if (alignmentStr == 'right') align = Alignment.centerRight;
    if (alignmentStr == 'left') align = Alignment.centerLeft;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          // On mobile screens (< 600px), always scale gracefully to at least 90%
          final screenW = constraints.maxWidth;
          final effectivePercent = screenW < 500 ? 100 : widthPercent;
          final targetWidth = screenW * (effectivePercent / 100);

          return Align(
            alignment: align,
            child: SizedBox(
              width: targetWidth,
              child: InkWell(
                onTap: enableZoom
                    ? () => InteractiveLightboxDialog.show(
                          context,
                          imageUrl: imageUrl,
                          title: caption,
                        )
                    : null,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                          color: AppColors.surfaceVariant.withValues(alpha: 0.3),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          memCacheWidth: 800,
                          memCacheHeight: 800,
                          maxWidthDiskCache: 1200,
                          fit: BoxFit.contain,
                          placeholder: (ctx, _) => Container(
                            height: 180,
                            color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (ctx, _, __) => Container(
                            height: 100,
                            color: AppColors.error.withValues(alpha: 0.08),
                            child: const Center(
                              child: Icon(Icons.broken_image_rounded, color: AppColors.error),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (enableZoom)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.zoom_in_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
