import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class OptionImageView extends StatelessWidget {
  final String imageUrl;

  const OptionImageView({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      child: kIsWeb
          ? Image.network(
              imageUrl,
              height: 90,
              fit: BoxFit.contain,
              loadingBuilder: (ctx, child, progress) {
                if (progress == null) return child;
                return _buildPlaceholder();
              },
              errorBuilder: (ctx, _, __) => const SizedBox.shrink(),
            )
          : CachedNetworkImage(
              imageUrl: imageUrl,
              height: 90,
              memCacheWidth: 400,
              memCacheHeight: 200,
              maxWidthDiskCache: 600,
              fit: BoxFit.contain,
              placeholder: (ctx, _) => _buildPlaceholder(),
              errorWidget: (ctx, _, __) => const SizedBox.shrink(),
            ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 90,
      width: 90,
      color: AppColors.surfaceVariant.withValues(alpha: 0.3),
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
