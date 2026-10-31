import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Preview renderer for attached local memory bytes or remote cached network images.
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
              child: localBytes != null
                  ? Image.memory(
                      localBytes!,
                      fit: BoxFit.contain,
                    )
                  : (imageUrl != null && imageUrl!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: imageUrl!,
                          memCacheWidth: 600,
                          memCacheHeight: 600,
                          maxWidthDiskCache: 800,
                          fit: BoxFit.contain,
                          placeholder: (ctx, _) => Container(
                            height: 140,
                            color: AppColors.surfaceVariant,
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
                        )
                      : const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
