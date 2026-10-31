import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';

/// Section handling picking, displaying, removing, and submitting solution files
class AssignmentFilesUploadSection extends StatelessWidget {
  final bool canSubmit;
  final bool isSubmitted;
  final bool isOverdue;
  final bool allowLateSubmission;
  final bool isSubmitting;
  final List<PlatformFile> selectedFiles;
  final VoidCallback onPickFiles;
  final ValueChanged<int> onRemoveFile;
  final VoidCallback onSubmit;

  const AssignmentFilesUploadSection({
    super.key,
    required this.canSubmit,
    required this.isSubmitted,
    required this.isOverdue,
    required this.allowLateSubmission,
    required this.isSubmitting,
    required this.selectedFiles,
    required this.onPickFiles,
    required this.onRemoveFile,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (canSubmit) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isSubmitted
                    ? l10n.resubmitNewAttemptTitle
                    : l10n.uploadSolutionFilesTitle,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton.icon(
                onPressed: onPickFiles,
                icon: const Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 18,
                ),
                label: Text(l10n.selectFilesBtn),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),

          if (selectedFiles.isEmpty)
            InkWell(
              onTap: onPickFiles,
              borderRadius: BorderRadius.circular(
                AppSpacing.radiusMedium,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.s32,
                  horizontal: AppSpacing.s16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(
                    AppSpacing.radiusMedium,
                  ),
                  border: Border.all(
                    color: AppColors.border,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.cloud_upload_outlined,
                      size: 44,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Text(
                      l10n.tapToPickFilesHint,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      l10n.maxFileSizeNotice,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...selectedFiles.asMap().entries.map((entry) {
              final idx = entry.key;
              final file = entry.value;
              final isPdf = file.extension?.toLowerCase() == 'pdf';

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  child: Row(
                    children: [
                      Icon(
                        isPdf
                            ? Icons.picture_as_pdf_outlined
                            : Icons.image_outlined,
                        color: isPdf ? AppColors.error : AppColors.primary,
                        size: 28,
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${(file.size / 1024).toStringAsFixed(1)} KB',
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
                          Icons.delete_outline,
                          color: AppColors.error,
                        ),
                        onPressed: () => onRemoveFile(idx),
                      ),
                    ],
                  ),
                ),
              );
            }),

          const SizedBox(height: AppSpacing.s24),

          AppButton(
            text: isSubmitted
                ? l10n.submitNewAttemptBtn
                : l10n.submitAssignmentNowBtn,
            onPressed: isSubmitting ? null : onSubmit,
            isLoading: isSubmitting,
            variant: AppButtonVariant.primary,
            icon: Icons.check_circle_outline,
          ),
        ],
      );
    }

    if (isOverdue && !allowLateSubmission && !isSubmitted) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(
            AppSpacing.radiusMedium,
          ),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Text(
                l10n.deadlinePassedNoLateNotice,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
