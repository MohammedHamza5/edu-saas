import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_spacing.dart';
import '../models/lesson_studio_models.dart';

/// PDF handout section with upload buttons or attached PDF chip with replace/remove menu
class LessonStudioLecturePdfSection extends StatelessWidget {
  final StagedLecture staged;
  final VoidCallback onPickFromLibrary;
  final VoidCallback onPickPdf;
  final VoidCallback onRemovePdf;

  const LessonStudioLecturePdfSection({
    super.key,
    required this.staged,
    required this.onPickFromLibrary,
    required this.onPickPdf,
    required this.onRemovePdf,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (!staged.hasPdf) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: onPickFromLibrary,
            icon: const Icon(
              Icons.folder_shared_rounded,
              size: 15,
              color: Color(0xFFEA580C),
            ),
            label: Text(
              l10n.selectFromMaterialsLibrary,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFFEA580C),
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: const Color(0xFFEA580C).withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              ),
            ),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: onPickPdf,
            icon: const Icon(
              Icons.upload_file_rounded,
              size: 15,
            ),
            label: Text(
              l10n.uploadFromDeviceAction,
              style: const TextStyle(fontSize: 11.5),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEA580C).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(
          color: const Color(0xFFEA580C).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.picture_as_pdf_rounded,
            size: 16,
            color: Color(0xFFEA580C),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  staged.pdfDisplayName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEA580C),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (staged.formattedPdfSize != null)
                  Text(
                    staged.formattedPdfSize!,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: const Color(0xFFEA580C).withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Quick Replace Menu
          PopupMenuButton<String>(
            tooltip: l10n.changeAction,
            icon: const Icon(
              Icons.swap_horiz_rounded,
              size: 16,
              color: Color(0xFFEA580C),
            ),
            onSelected: (val) {
              if (val == 'library') {
                onPickFromLibrary();
              } else if (val == 'upload') {
                onPickPdf();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'library',
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_shared_rounded,
                      size: 16,
                      color: Color(0xFFEA580C),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.selectFromMaterialsLibrary,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'upload',
                child: Row(
                  children: [
                    const Icon(
                      Icons.upload_file_rounded,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.uploadFromDeviceAction,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Remove Button
          InkWell(
            onTap: onRemovePdf,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(2.0),
              child: Icon(
                Icons.close_rounded,
                size: 15,
                color: Color(0xFFEA580C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
