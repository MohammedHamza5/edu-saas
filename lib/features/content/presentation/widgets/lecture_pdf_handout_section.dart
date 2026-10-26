import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/pdf_launcher_helper.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/library_material_entity.dart';

/// PDF handout attachment section inside lecture studio dialog.
class LecturePdfHandoutSection extends StatelessWidget {
  final LibraryMaterialEntity? selectedLibraryMaterial;
  final PlatformFile? pickedHandoutFile;
  final VoidCallback onPickFromMaterialsLibrary;
  final VoidCallback onPickHandoutPdf;
  final VoidCallback onClearLibraryMaterial;
  final VoidCallback onClearPickedHandoutFile;

  const LecturePdfHandoutSection({
    super.key,
    required this.selectedLibraryMaterial,
    required this.pickedHandoutFile,
    required this.onPickFromMaterialsLibrary,
    required this.onPickHandoutPdf,
    required this.onClearLibraryMaterial,
    required this.onClearPickedHandoutFile,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.picture_as_pdf_outlined,
                size: 18,
                color: Colors.redAccent,
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                context.l10n.handoutAttachmentSection,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          if (selectedLibraryMaterial != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Colors.redAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                context.l10n.materialSelectedFromLibrary,
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
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 20),
                    tooltip: context.l10n.previewMaterialAction,
                    onPressed: () async {
                      final currentContext = context;
                      try {
                        final res = await InjectionContainer
                            .materialsLibraryRepository
                            .getSignedUrl(
                          selectedLibraryMaterial!.storagePath,
                          storageProvider:
                              selectedLibraryMaterial!.storageProvider,
                        );
                        if (res.isSuccess && res.dataOrNull != null) {
                          if (!currentContext.mounted) return;
                          await PdfLauncherHelper.launchPdfUrl(
                            res.dataOrNull!,
                            context: currentContext,
                          );
                        }
                      } catch (_) {}
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: context.l10n.changeMaterialAction,
                    onPressed: onClearLibraryMaterial,
                  ),
                ],
              ),
            ),
          ] else if (pickedHandoutFile != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s12,
                vertical: AppSpacing.s10,
              ),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.description_rounded,
                    color: Colors.redAccent,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pickedHandoutFile!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${(pickedHandoutFile!.size / 1024).toStringAsFixed(1)} KB • ${context.l10n.uploadMaterialAction}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: onClearPickedHandoutFile,
                  ),
                ],
              ),
            ),
          ] else ...[
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(
                    Icons.folder_shared_rounded,
                    size: 18,
                    color: Color(0xFFEA580C),
                  ),
                  label: Text(context.l10n.selectFromMaterialsLibrary),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEA580C),
                    side: const BorderSide(color: Color(0xFFEA580C)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                      vertical: AppSpacing.s12,
                    ),
                  ),
                  onPressed: onPickFromMaterialsLibrary,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: Text(context.l10n.uploadFromDeviceAction),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s14,
                      vertical: AppSpacing.s12,
                    ),
                  ),
                  onPressed: onPickHandoutPdf,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
