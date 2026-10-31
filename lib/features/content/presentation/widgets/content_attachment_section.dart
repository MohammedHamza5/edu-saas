import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/content_entity.dart';

/// Card managing file attachment selection and live upload progress notice.
class ContentAttachmentSection extends StatelessWidget {
  final ContentType selectedType;
  final bool hasAttachment;
  final TextEditingController fileNameController;
  final bool isLoading;
  final ValueChanged<bool> onAttachmentChanged;
  final VoidCallback onPickFile;

  const ContentAttachmentSection({
    super.key,
    required this.selectedType,
    required this.hasAttachment,
    required this.fileNameController,
    required this.isLoading,
    required this.onAttachmentChanged,
    required this.onPickFile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          variant: AppCardVariant.standard,
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CheckboxListTile(
                title: Text(
                  selectedType == ContentType.video
                      ? context.l10n.attachVideoMaterialNotice
                      : context.l10n.attachMaterialFile,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: selectedType == ContentType.video
                    ? Text(
                        context.l10n.attachVideoMaterialHint,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : null,
                value: hasAttachment,
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => onAttachmentChanged(val ?? false),
              ),
              if (hasAttachment) ...[
                const SizedBox(height: AppSpacing.s6),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: fileNameController,
                        labelText: context.l10n.attachedFileNameLabel,
                        hintText: context.l10n.attachedFileNameHint,
                        prefixIcon: const Icon(Icons.attach_file_rounded),
                        validator: (val) {
                          if (hasAttachment && (val == null || val.trim().isEmpty)) {
                            return context.l10n.fileNameRequired;
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: onPickFile,
                        icon: const Icon(
                          Icons.file_upload_outlined,
                          size: 18,
                        ),
                        label: Text(context.l10n.browseFileAction),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceVariant,
                          foregroundColor: AppColors.textPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSmall,
                            ),
                            side: const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        if (isLoading) ...[
          const SizedBox(height: AppSpacing.s16),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.warning.withAlpha(20),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              border: Border.all(color: AppColors.warning.withAlpha(80)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.s10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.uploadingFileKeepPageOpen,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.doNotClosePageWarning,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      const LinearProgressIndicator(
                        minHeight: 4,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
