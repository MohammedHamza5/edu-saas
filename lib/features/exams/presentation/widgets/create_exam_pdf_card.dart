import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';

class CreateExamPdfCard extends StatelessWidget {
  final bool hasPdf;
  final bool isCreating;
  final bool isUploadingPdf;
  final String? attachedPdfFileName;
  final int? attachedPdfFileSize;
  final String? attachedPdfStoragePath;
  final VoidCallback onPickFromLibrary;
  final VoidCallback onPickFromDevice;
  final VoidCallback onPreviewPdf;
  final VoidCallback onRemovePdf;
  final VoidCallback? onQuickBubbleSheet;

  const CreateExamPdfCard({
    super.key,
    required this.hasPdf,
    required this.isCreating,
    required this.isUploadingPdf,
    required this.attachedPdfFileName,
    required this.attachedPdfFileSize,
    required this.attachedPdfStoragePath,
    required this.onPickFromLibrary,
    required this.onPickFromDevice,
    required this.onPreviewPdf,
    required this.onRemovePdf,
    this.onQuickBubbleSheet,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Color(0xFFEA580C),
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.attachedExamPdf,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.attachedExamPdfDesc,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (isUploadingPdf)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          if (!hasPdf) ...[
            Wrap(
              spacing: AppSpacing.s12,
              runSpacing: AppSpacing.s10,
              children: [
                OutlinedButton.icon(
                  onPressed: isCreating || isUploadingPdf
                      ? null
                      : onPickFromLibrary,
                  icon: const Icon(Icons.folder_shared_rounded, size: 18),
                  label: Text(context.l10n.selectFromMaterialsLibrary),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isCreating || isUploadingPdf
                      ? null
                      : onPickFromDevice,
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: Text(context.l10n.uploadNewPdfFromDevice),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSmall),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Color(0xFFEA580C),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attachedPdfFileName ?? 'Exam Booklet.pdf',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (attachedPdfFileSize != null &&
                            attachedPdfFileSize! > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${(attachedPdfFileSize! / (1024 * 1024)).toStringAsFixed(2)} MB',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  if (attachedPdfStoragePath != null &&
                      attachedPdfStoragePath!.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined),
                      tooltip: context.l10n.previewPdfBooklet,
                      onPressed: onPreviewPdf,
                    ),
                  PopupMenuButton<String>(
                    tooltip: context.l10n.replacePdfBooklet,
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (val) {
                      if (val == 'library') {
                        onPickFromLibrary();
                      } else if (val == 'device') {
                        onPickFromDevice();
                      } else if (val == 'remove') {
                        onRemovePdf();
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'library',
                        child: Row(
                          children: [
                            const Icon(Icons.folder_shared_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(context.l10n.selectFromMaterialsLibrary),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'device',
                        child: Row(
                          children: [
                            const Icon(Icons.upload_file_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(context.l10n.uploadNewPdfFromDevice),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              context.l10n.removeAttachedPdf,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            // Fast Bubble Sheet Call-to-action
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.flash_on_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.quickBubbleSheetGenerator,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.quickBubbleSheetPrompt,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: isCreating ? null : onQuickBubbleSheet,
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                    label: Text(context.l10n.quickPresets),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
