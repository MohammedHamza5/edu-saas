import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/file_attachment_entity.dart';

/// Card showing description and file attachment details (file name, size, mime type).
class MaterialViewerMetadataCard extends StatelessWidget {
  final String? description;
  final FileAttachmentEntity? file;
  final Color color;
  final bool isPdf;
  final bool isImage;

  const MaterialViewerMetadataCard({
    super.key,
    required this.description,
    required this.file,
    required this.color,
    required this.isPdf,
    required this.isImage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (description != null && description!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s12),
          AppCard(
            variant: AppCardVariant.standard,
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: Text(
              description!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
        if (file != null) ...[
          const SizedBox(height: AppSpacing.s16),
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
                        file!.fileName,
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
                if (file!.fileSize > 0) ...[
                  const Divider(height: AppSpacing.s16),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: AppSpacing.s12,
                    runSpacing: 4,
                    children: [
                      Text(
                        context.l10n.fileSizeLabel(file!.formattedFileSize),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        context.l10n.fileTypeLabel(
                          file!.mimeType.split('/').last.toUpperCase(),
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
