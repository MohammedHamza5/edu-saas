import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/content_entity.dart';
import 'content_item_card_helpers.dart';

/// Renders file attachments, supplementary PDFs, and teacher video status/upload buttons.
class ContentItemCardAttachmentsView extends StatelessWidget {
  final ContentEntity content;
  final bool isTeacher;
  final bool hasFile;
  final ValueChanged<String>? onOpenFile;
  final VoidCallback? onUploadVideo;

  const ContentItemCardAttachmentsView({
    super.key,
    required this.content,
    required this.isTeacher,
    required this.hasFile,
    this.onOpenFile,
    this.onUploadVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Attachment File Link (if attached for document/image)
        if (hasFile) ...[
          const SizedBox(height: AppSpacing.s6),
          InkWell(
            onTap: onOpenFile != null
                ? () => onOpenFile!(content.file!.storagePath)
                : null,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.attach_file_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${content.file!.fileName} (${content.file!.formattedFileSize})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Supplementary PDF Material (for Video lessons)
        if (content.type == ContentType.video && content.file != null) ...[
          const SizedBox(height: AppSpacing.s8),
          InkWell(
            onTap: onOpenFile != null
                ? () => onOpenFile!(content.file!.storagePath)
                : null,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s8,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(12),
                borderRadius: BorderRadius.circular(
                  AppSpacing.radiusSmall,
                ),
                border: Border.all(
                  color: AppColors.primary.withAlpha(40),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.picture_as_pdf_rounded,
                    size: 14,
                    color: Color(0xFFEA580C),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      '${context.l10n.videoMaterialPdfBadge}: ${content.file!.fileName} (${content.file!.formattedFileSize})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onOpenFile != null) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.open_in_new_rounded,
                      size: 12,
                      color: AppColors.primary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],

        // Video Status / Upload Action for Teacher
        if (isTeacher && content.type == ContentType.video) ...[
          const SizedBox(height: AppSpacing.s8),
          // Case A: video already uploaded → show status badge
          if (content.hasVideo)
            ContentVideoStatusBadge(
              status: content.videoStatus ?? 'uploading',
              onReplace: onUploadVideo,
            )
          // Case B: no video yet → show upload button
          else if (onUploadVideo != null)
            InkWell(
              onTap: onUploadVideo,
              borderRadius: BorderRadius.circular(
                AppSpacing.radiusSmall,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(
                    AppSpacing.radiusSmall,
                  ),
                  border: Border.all(
                    color: AppColors.primary.withAlpha(60),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_upload_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.l10n.uploadVideoAction,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}
