import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Preview renderer for attached local memory bytes or remote cached network images.
/// Uses resilient Image.network on Flutter Web to avoid CanvasKit WebGL context exhaustion
/// and downscaling black box artifacts when rendering many questions simultaneously.
class ExamImageAttachmentPreview extends StatelessWidget {
  final Uint8List? localBytes;
  final String? imageUrl;
  final String alignment;
  final int widthPercent;

  const ExamImageAttachmentPreview({
    super.key,
    this.localBytes,
    this.imageUrl,
    required this.alignment,
    required this.widthPercent,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final displayW = constraints.maxWidth * (widthPercent / 100);
        Alignment align = Alignment.center;
        if (alignment == 'right') align = Alignment.centerRight;
        if (alignment == 'left') align = Alignment.centerLeft;

        return Align(
          alignment: align,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 280),
              width: displayW,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                border: Border.all(color: AppColors.border),
              ),
              child: localBytes != null
                  ? Image.memory(
                      localBytes!,
                      fit: BoxFit.contain,
                    )
                  : (imageUrl != null && imageUrl!.trim().isNotEmpty)
                      ? _buildRemoteImage(context, imageUrl!.trim())
                      : const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRemoteImage(BuildContext context, String url) {
    if (kIsWeb) {
      return Image.network(
        url,
        key: ValueKey(url),
        fit: BoxFit.contain,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 140,
            color: Colors.white,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (ctx, _, __) => Container(
          height: 100,
          color: AppColors.error.withValues(alpha: 0.1),
          child: Center(
            child: Text(
              context.l10n.failedToLoadImage,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    return CachedNetworkImage(
      key: ValueKey(url),
      imageUrl: url,
      memCacheWidth: 800,
      maxWidthDiskCache: 1000,
      fit: BoxFit.contain,
      placeholder: (ctx, _) => Container(
        height: 140,
        color: Colors.white,
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (ctx, _, __) => Container(
        height: 100,
        color: AppColors.error.withValues(alpha: 0.1),
        child: Center(
          child: Text(
            context.l10n.failedToLoadImage,
            style: const TextStyle(
              color: AppColors.error,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

