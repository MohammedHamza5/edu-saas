import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class VideoResumeBanner extends StatelessWidget {
  final String formattedTime;
  final VoidCallback onResume;
  final VoidCallback onDismiss;

  const VideoResumeBanner({
    super.key,
    required this.formattedTime,
    required this.onResume,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: AppSpacing.s16,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(
            AppSpacing.radiusFull,
          ),
          border: Border.all(
            color: AppColors.primaryLight.withAlpha(120),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.history_rounded,
              color: AppColors.primaryLight,
              size: 16,
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              context.l10n.resumeFromMinute(formattedTime),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryLight,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
              ),
              onPressed: onResume,
              child: Text(
                context.l10n.resumeAction,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white70,
                size: 14,
              ),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
