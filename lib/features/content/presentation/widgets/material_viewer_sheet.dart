import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../domain/entities/content_entity.dart';

/// An academic, highly polished modal sheet or dialog to view and download
/// educational materials, notes, and attachments with secure signed URLs.
class MaterialViewerSheet extends StatefulWidget {
  final ContentEntity content;
  final Future<String?> Function(String storagePath) onGetSignedUrl;

  const MaterialViewerSheet({
    super.key,
    required this.content,
    required this.onGetSignedUrl,
  });

  /// Shows as a bottom sheet on mobile and as an AlertDialog on tablet/desktop.
  static Future<void> show(
    BuildContext context, {
    required ContentEntity content,
    required Future<String?> Function(String storagePath) onGetSignedUrl,
  }) async {
    final width = MediaQuery.of(context).size.width;
    if (width >= 600) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: MaterialViewerSheet(
              content: content,
              onGetSignedUrl: onGetSignedUrl,
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => MaterialViewerSheet(
          content: content,
          onGetSignedUrl: onGetSignedUrl,
        ),
      );
    }
  }

  @override
  State<MaterialViewerSheet> createState() => _MaterialViewerSheetState();
}

class _MaterialViewerSheetState extends State<MaterialViewerSheet> {
  bool _isLoadingUrl = false;
  String? _signedUrl;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUrl();
  }

  Future<void> _fetchUrl() async {
    final storagePath = widget.content.file?.storagePath;
    if (storagePath == null || storagePath.isEmpty) return;

    setState(() {
      _isLoadingUrl = true;
      _errorMessage = null;
    });

    try {
      final url = await widget.onGetSignedUrl(storagePath);
      if (mounted) {
        setState(() {
          _isLoadingUrl = false;
          _signedUrl = url;
          if (url == null) {
            _errorMessage = context.l10n.secureUrlErrorFallback;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUrl = false;
          _errorMessage = context.l10n.secureUrlGenericError;
        });
      }
    }
  }

  Future<void> _copyUrl() async {
    if (_signedUrl == null) return;
    await Clipboard.setData(ClipboardData(text: _signedUrl!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(context.l10n.secureUrlCopied),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = widget.content.file;
    final isPdf = widget.content.type == ContentType.pdf;
    final isImage = widget.content.type == ContentType.image;

    final color = switch (widget.content.type) {
      ContentType.pdf => const Color(0xFFEA580C),
      ContentType.video => AppColors.primary,
      ContentType.image => Colors.purple,
      ContentType.assignment => AppColors.warning,
      ContentType.exam => AppColors.success,
    };

    final icon = switch (widget.content.type) {
      ContentType.pdf => Icons.picture_as_pdf_rounded,
      ContentType.video => Icons.play_circle_fill_rounded,
      ContentType.image => Icons.image_rounded,
      ContentType.assignment => Icons.assignment_rounded,
      ContentType.exam => Icons.quiz_rounded,
    };

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLarge),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle pill for bottom sheet
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.s16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  border: Border.all(color: color.withAlpha(60)),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.content.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Wrap(
                      spacing: AppSpacing.s6,
                      runSpacing: AppSpacing.s4,
                      children: [
                        AppBadge(
                          label: widget.content.type.localizedLabel(context),
                          variant: AppBadgeVariant.neutral,
                        ),
                        if (file != null)
                          AppBadge(
                            label: file.formattedFileSize,
                            variant: AppBadgeVariant.neutral,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: context.l10n.closeTooltip,
              ),
            ],
          ),

          if (widget.content.description != null &&
              widget.content.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s12),
            AppCard(
              variant: AppCardVariant.standard,
              padding: const EdgeInsets.all(AppSpacing.s12),
              child: Text(
                widget.content.description!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.s16),

          // File metadata card
          if (file != null) ...[
            AppCard(
              variant: AppCardVariant.standard,
              padding: const EdgeInsets.all(AppSpacing.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isPdf
                            ? Icons.description_rounded
                            : isImage
                            ? Icons.photo_library_rounded
                            : Icons.file_present_rounded,
                        color: color,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          file.fileName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: AppSpacing.s16),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: AppSpacing.s12,
                    runSpacing: 4,
                    children: [
                      Text(
                        context.l10n.fileSizeLabel(file.formattedFileSize),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        context.l10n.fileTypeLabel(
                          file.mimeType.split('/').last.toUpperCase(),
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.s16),

          // State of URL loading or action
          if (_isLoadingUrl) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppLoadingView.compact(size: 18),
                    const SizedBox(width: AppSpacing.s8),
                    Flexible(
                      child: Text(
                        context.l10n.preparingSecureUrl,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_errorMessage != null) ...[
            Container(
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
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    onPressed: _fetchUrl,
                    tooltip: context.l10n.retryAction,
                  ),
                ],
              ),
            ),
          ] else if (_signedUrl != null) ...[
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
                    imageUrl: _signedUrl!,
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
                        onPressed: _copyUrl,
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      AppButton(
                        text: context.l10n.copySecureUrlAction,
                        icon: Icons.copy_rounded,
                        variant: AppButtonVariant.secondary,
                        onPressed: _copyUrl,
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
                        onPressed: _copyUrl,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: AppButton(
                        text: context.l10n.downloadOrOpenFile,
                        icon: Icons.open_in_new_rounded,
                        onPressed: _copyUrl,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],

          const SizedBox(height: AppSpacing.s12),

          // Academic security notice
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s10,
              vertical: AppSpacing.s6,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(10),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              border: Border.all(color: AppColors.primary.withAlpha(25)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.s6),
                Expanded(
                  child: Text(
                    context.l10n.contentSecurityDisclaimer,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.primary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
