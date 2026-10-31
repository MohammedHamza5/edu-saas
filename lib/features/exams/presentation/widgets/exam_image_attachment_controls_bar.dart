import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_badge.dart';

/// Controls bar for image attachments: upload status badge, alignment buttons, width presets, and remove action.
class ExamImageAttachmentControlsBar extends StatelessWidget {
  final bool isUploading;
  final String? imageUrl;
  final String? uploadError;
  final VoidCallback? onRetryUpload;
  final String alignment;
  final int widthPercent;
  final ValueChanged<String> onAlignmentChanged;
  final ValueChanged<int> onWidthPercentChanged;
  final VoidCallback onRemoveImage;

  const ExamImageAttachmentControlsBar({
    super.key,
    required this.isUploading,
    this.imageUrl,
    this.uploadError,
    this.onRetryUpload,
    required this.alignment,
    required this.widthPercent,
    required this.onAlignmentChanged,
    required this.onWidthPercentChanged,
    required this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 1. Sync / Status Badges
              if (isUploading) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSmall),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.syncingImageInBackground,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (imageUrl != null && imageUrl!.isNotEmpty) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSmall),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_done_rounded,
                        size: 14,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.imageSavedToCloud,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (uploadError != null) ...[
                InkWell(
                  onTap: onRetryUpload,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusSmall),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSmall),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.refresh_rounded,
                          size: 14,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.retryUpload,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (imageUrl != null && imageUrl!.contains('.webp')) ...[
                AppBadge(
                  label: context.l10n.optimizedWebpBadge,
                  variant: AppBadgeVariant.active,
                  icon: Icons.bolt_rounded,
                ),
              ],
              Text(
                context.l10n.imageAlignmentLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              _buildAlignButton('right', Icons.format_align_right_rounded),
              _buildAlignButton('center', Icons.format_align_center_rounded),
              _buildAlignButton('left', Icons.format_align_left_rounded),
              const SizedBox(width: 8),
              Text(
                context.l10n.imageWidthLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              _buildWidthChip(30, '30%'),
              _buildWidthChip(50, '50%'),
              _buildWidthChip(75, '75%'),
              _buildWidthChip(100, '100%'),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: AppColors.error,
            size: 20,
          ),
          tooltip: context.l10n.removeImageAction,
          onPressed: onRemoveImage,
        ),
      ],
    );
  }

  Widget _buildAlignButton(String alignKey, IconData icon) {
    final isSelected = alignKey == alignment;
    return InkWell(
      onTap: () => onAlignmentChanged(alignKey),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildWidthChip(int percent, String label) {
    final isSelected = percent == widthPercent;
    return InkWell(
      onTap: () => onWidthPercentChanged(percent),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
