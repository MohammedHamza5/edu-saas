import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/pdf_launcher_helper.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../domain/entities/content_entity.dart';

/// Header section of the MaterialViewerSheet displaying icon, title, metadata badges, and actions.
class MaterialViewerHeader extends StatelessWidget {
  final ContentEntity content;
  final Color color;
  final IconData icon;
  final bool isPdf;
  final bool isTeacher;
  final String? signedUrl;
  final VoidCallback onCopyUrl;
  final VoidCallback onClose;

  const MaterialViewerHeader({
    super.key,
    required this.content,
    required this.color,
    required this.icon,
    required this.isPdf,
    required this.isTeacher,
    required this.signedUrl,
    required this.onCopyUrl,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = content.file;

    return Row(
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
                content.title,
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
                    label: content.type.localizedLabel(context),
                    variant: AppBadgeVariant.neutral,
                  ),
                  if (file != null && file.fileSize > 0)
                    AppBadge(
                      label: file.formattedFileSize,
                      variant: AppBadgeVariant.neutral,
                    ),
                ],
              ),
            ],
          ),
        ),
        if (isPdf && signedUrl != null) ...[
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, size: 20),
            onPressed: () =>
                PdfLauncherHelper.launchPdfUrl(signedUrl!, context: context),
            tooltip: context.l10n.openPdfInNewTabTooltip,
          ),
        ],
        if (isTeacher && isPdf && signedUrl != null) ...[
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: onCopyUrl,
            tooltip: context.l10n.copySecureUrlAction,
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(140),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: onClose,
            tooltip: context.l10n.closeTooltip,
            padding: const EdgeInsets.all(AppSpacing.s8),
            constraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
          ),
        ),
      ],
    );
  }
}
