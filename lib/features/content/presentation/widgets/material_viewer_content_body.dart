import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/pdf_launcher_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loading_view.dart';
import 'secure_pdf_viewer.dart';

/// Renders the material content body (loading, error, cached image, secure PDF, or empty state).
class MaterialViewerContentBody extends StatelessWidget {
  final bool isLoadingUrl;
  final String? errorMessage;
  final String? signedUrl;
  final bool isDesktop;
  final bool isPdf;
  final bool isImage;
  final bool isTeacher;
  final String docTitle;
  final String watermarkText;
  final VoidCallback onRetry;
  final VoidCallback onCopyUrl;

  const MaterialViewerContentBody({
    super.key,
    required this.isLoadingUrl,
    required this.errorMessage,
    required this.signedUrl,
    required this.isDesktop,
    required this.isPdf,
    required this.isImage,
    required this.isTeacher,
    required this.docTitle,
    required this.watermarkText,
    required this.onRetry,
    required this.onCopyUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoadingUrl) {
      return Container(
        height: isDesktop ? 340 : 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withAlpha(20),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          border: Border.all(color: AppColors.border.withAlpha(60)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLoadingView.compact(size: 28),
            const SizedBox(height: AppSpacing.s12),
            Text(
              context.l10n.preparingSecureUrl,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.s8),
        decoration: BoxDecoration(
          color: AppColors.error.withAlpha(20),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 18,
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                errorMessage!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.error,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              onPressed: onRetry,
              tooltip: context.l10n.retryAction,
            ),
          ],
        ),
      );
    }

    if (signedUrl != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isImage) ...[
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.s16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                child: CachedNetworkImage(
                  imageUrl: signedUrl!,
                  fit: BoxFit.contain,
                  maxHeightDiskCache: 1000,
                  placeholder: (_, __) => const SizedBox(
                    height: 180,
                    child: Center(child: AppLoadingView.compact()),
                  ),
                  errorWidget: (_, __, ___) => const SizedBox(
                    height: 120,
                    child: Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        size: 36,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (isPdf) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: AppSpacing.s8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(16),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  border: Border.all(color: AppColors.primary.withAlpha(45)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.rocket_launch_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        context.l10n.openPdfInNewTabTooltip,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    AppButton(
                      text: context.l10n.openPdfInNewTab,
                      icon: Icons.open_in_new_rounded,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s12,
                        vertical: AppSpacing.s6,
                      ),
                      onPressed: () => PdfLauncherHelper.launchPdfUrl(
                        signedUrl!,
                        context: context,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: isDesktop ? 600 : 420,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                child: buildSecurePdfViewer(
                  pdfUrl: signedUrl!,
                  watermarkText: watermarkText,
                  docTitle: docTitle,
                ),
              ),
            ),
          ],
          if (isTeacher) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final isVeryNarrow = constraints.maxWidth < 340;
                if (isVeryNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppButton(
                        text: context.l10n.downloadOrOpenFile,
                        icon: Icons.open_in_new_rounded,
                        onPressed: () => PdfLauncherHelper.launchPdfUrl(
                          signedUrl!,
                          context: context,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      AppButton(
                        text: context.l10n.copySecureUrlAction,
                        icon: Icons.copy_rounded,
                        variant: AppButtonVariant.secondary,
                        onPressed: onCopyUrl,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: context.l10n.copySecureUrlAction,
                        icon: Icons.copy_rounded,
                        variant: AppButtonVariant.secondary,
                        onPressed: onCopyUrl,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: AppButton(
                        text: context.l10n.downloadOrOpenFile,
                        icon: Icons.open_in_new_rounded,
                        onPressed: () => PdfLauncherHelper.launchPdfUrl(
                          signedUrl!,
                          context: context,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withAlpha(20),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              context.l10n.emptyData,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
