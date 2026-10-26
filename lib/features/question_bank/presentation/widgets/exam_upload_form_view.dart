import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';

/// Form view for uploading exam files, optional answer key, and attesting copyright.
class ExamUploadFormView extends StatelessWidget {
  final List<PlatformFile> examFiles;
  final PlatformFile? answerKeyFile;
  final bool rightsAttested;
  final bool isProcessing;
  final String? statusMessage;
  final String? errorMessage;
  final VoidCallback onPickExamFiles;
  final VoidCallback onPickAnswerKeyFile;
  final VoidCallback onClearAnswerKeyFile;
  final ValueChanged<bool> onRightsAttestationChanged;
  final VoidCallback onClearErrorMessage;
  final VoidCallback onStartReconstruction;
  final VoidCallback onClose;

  const ExamUploadFormView({
    super.key,
    required this.examFiles,
    required this.answerKeyFile,
    required this.rightsAttested,
    required this.isProcessing,
    required this.statusMessage,
    required this.errorMessage,
    required this.onPickExamFiles,
    required this.onPickAnswerKeyFile,
    required this.onClearAnswerKeyFile,
    required this.onRightsAttestationChanged,
    required this.onClearErrorMessage,
    required this.onStartReconstruction,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              ),
              child: Icon(
                Icons.auto_awesome,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.uploadExamDialogTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    l10n.uploadExamDialogSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!isProcessing)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),

        // Multi-file supported banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: AppColors.info.withAlpha(30),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(color: AppColors.info.withAlpha(60)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.info, size: 18),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  l10n.multiFileAcceptedNotice,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        // Exam Paper (Primary)
        Text(
          l10n.primaryExamFile,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        InkWell(
          onTap: isProcessing ? null : onPickExamFiles,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              border: Border.all(
                color: examFiles.isNotEmpty
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: examFiles.isNotEmpty ? 1.5 : 1.0,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              color: examFiles.isNotEmpty
                  ? theme.colorScheme.primaryContainer.withAlpha(30)
                  : theme.colorScheme.surface,
            ),
            child: Row(
              children: [
                Icon(
                  examFiles.isNotEmpty
                      ? Icons.picture_as_pdf
                      : Icons.cloud_upload_outlined,
                  color: examFiles.isNotEmpty
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        examFiles.isNotEmpty
                            ? l10n.selectedFilesCount(examFiles.length)
                            : l10n.selectFileAction,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: examFiles.isNotEmpty
                              ? theme.colorScheme.primary
                              : null,
                        ),
                      ),
                      if (examFiles.isNotEmpty)
                        Text(
                          examFiles.map((f) => f.name).join(', '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: isProcessing ? null : onPickExamFiles,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.selectFileAction),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        // Separate Answer Key (Optional)
        Text(
          l10n.answerKeyFile,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        InkWell(
          onTap: isProcessing ? null : onPickAnswerKeyFile,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s12,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              color: answerKeyFile != null
                  ? AppColors.successLight.withAlpha(30)
                  : theme.colorScheme.surface,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.key_outlined,
                  color: answerKeyFile != null
                      ? AppColors.success
                      : theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(
                    answerKeyFile?.name ?? l10n.selectFileAction,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: answerKeyFile != null ? AppColors.success : null,
                      fontWeight:
                          answerKeyFile != null ? FontWeight.bold : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (answerKeyFile != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: onClearAnswerKeyFile,
                  )
                else
                  TextButton(
                    onPressed: isProcessing ? null : onPickAnswerKeyFile,
                    child: Text(l10n.selectFileAction),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        // Rights Attestation Checkbox
        CheckboxListTile(
          value: rightsAttested,
          onChanged: isProcessing
              ? null
              : (v) => onRightsAttestationChanged(v ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            l10n.rightsAttestationPrompt,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        // Error Banner
        if (errorMessage != null && !isProcessing) ...[
          const SizedBox(height: AppSpacing.s12),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.s10),
                Expanded(
                  child: Text(
                    errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onClearErrorMessage,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Processing Indicator
        if (isProcessing) ...[
          const SizedBox(height: AppSpacing.s12),
          LinearProgressIndicator(borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: AppSpacing.s8),
          Text(
            statusMessage ?? '',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s20),

        // Footer Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!isProcessing)
              TextButton(
                onPressed: onClose,
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
            const SizedBox(width: AppSpacing.s12),
            AppButton(
              text: l10n.startReconstructionAction,
              icon: Icons.auto_awesome,
              isLoading: isProcessing,
              onPressed:
                  (examFiles.isNotEmpty && rightsAttested && !isProcessing)
                      ? onStartReconstruction
                      : null,
            ),
          ],
        ),
      ],
    );
  }
}
