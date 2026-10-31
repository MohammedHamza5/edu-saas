import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Empty state display for the video picker sheet when no videos exist in the library.
class VideoPickerEmptyView extends StatelessWidget {
  final VoidCallback onSelectFromBank;

  const VideoPickerEmptyView({
    super.key,
    required this.onSelectFromBank,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.video_library_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              l10n.videoLibraryEmpty,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              l10n.videoLibraryEmptySubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            OutlinedButton.icon(
              onPressed: onSelectFromBank,
              icon: const Icon(
                Icons.folder_open_rounded,
                size: 18,
              ),
              label: Text(l10n.selectFromBank),
            ),
          ],
        ),
      ),
    );
  }
}
