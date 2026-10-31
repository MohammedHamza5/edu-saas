import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Study material (PDF) upload and preview section for [LessonSetupSheet].
class LessonSetupMaterialSection extends StatelessWidget {
  final bool hasPdf;
  final String? pdfName;
  final VoidCallback onPickPdf;
  final VoidCallback onRemovePdf;

  const LessonSetupMaterialSection({
    super.key,
    required this.hasPdf,
    required this.pdfName,
    required this.onPickPdf,
    required this.onRemovePdf,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.picture_as_pdf_rounded,
              size: 16,
              color: Color(0xFFEA580C),
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              l10n.studyMaterial,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        if (hasPdf) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: const Color(0xFFEA580C).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(
                color: const Color(0xFFEA580C).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Color(0xFFEA580C),
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    pdfName ?? 'document.pdf',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onPickPdf,
                  child: Text(
                    l10n.replacePdf,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: onRemovePdf,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  child: Text(
                    l10n.removePdf,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          OutlinedButton.icon(
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: Text(l10n.uploadPdf),
            onPressed: onPickPdf,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEA580C),
              side: const BorderSide(color: Color(0xFFEA580C), width: 1.2),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ],
    );
  }
}
