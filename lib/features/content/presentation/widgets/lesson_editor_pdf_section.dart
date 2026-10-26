import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/library_material_entity.dart';

/// Section in lesson editor for PDF handout attachment (from Library or device)
class LessonEditorPdfSection extends StatelessWidget {
  final bool removePdf;
  final LibraryMaterialEntity? selectedLibraryMaterial;
  final PlatformFile? pickedFile;
  final String? currentFileName;
  final VoidCallback onPickFromLibrary;
  final VoidCallback onPickPdf;
  final VoidCallback onRemoveLibraryMaterial;
  final VoidCallback onRemovePickedFile;

  const LessonEditorPdfSection({
    super.key,
    required this.removePdf,
    required this.selectedLibraryMaterial,
    required this.pickedFile,
    required this.currentFileName,
    required this.onPickFromLibrary,
    required this.onPickPdf,
    required this.onRemoveLibraryMaterial,
    required this.onRemovePickedFile,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.pdfHandoutSection,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AppSpacing.s10),
            if (!removePdf && selectedLibraryMaterial != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(
                    AppSpacing.radiusMedium,
                  ),
                  border: Border.all(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                      ),
                      child: const Icon(
                        Icons.folder_shared_rounded,
                        color: Color(0xFFEA580C),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  l10n.materialSelectedFromLibrary,
                                  style: const TextStyle(
                                    color: AppColors.success,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                selectedLibraryMaterial!.formattedFileSize,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            selectedLibraryMaterial!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        size: 18,
                      ),
                      tooltip: l10n.selectFromMaterialsLibrary,
                      onPressed: onPickFromLibrary,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.error,
                      ),
                      tooltip: l10n.deleteAction,
                      onPressed: onRemoveLibraryMaterial,
                    ),
                  ],
                ),
              )
            else if (!removePdf &&
                (pickedFile != null || currentFileName != null))
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(
                    AppSpacing.radiusMedium,
                  ),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Color(0xFFEA580C),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pickedFile?.name ?? currentFileName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (pickedFile != null)
                            Text(
                              '${(pickedFile!.size / 1024).toStringAsFixed(1)} KB (${l10n.newFileBadge})',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        size: 18,
                      ),
                      tooltip: l10n.replacePdf,
                      onPressed: onPickPdf,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.error,
                      ),
                      tooltip: l10n.deleteAction,
                      onPressed: onRemovePickedFile,
                    ),
                  ],
                ),
              )
            else
              Wrap(
                spacing: AppSpacing.s10,
                runSpacing: AppSpacing.s8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onPickFromLibrary,
                    icon: const Icon(
                      Icons.folder_shared_rounded,
                      size: 16,
                      color: Color(0xFFEA580C),
                    ),
                    label: Text(l10n.selectFromMaterialsLibrary),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEA580C),
                      side: const BorderSide(color: Color(0xFFEA580C)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onPickPdf,
                    icon: const Icon(
                      Icons.upload_file_rounded,
                      size: 16,
                    ),
                    label: Text(l10n.uploadFromDeviceAction),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
