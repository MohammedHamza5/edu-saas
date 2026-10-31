import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import 'crop_aspect_ratio.dart';

class CropToolbar extends StatelessWidget {
  final CropAspectRatio selectedRatio;
  final ValueChanged<CropAspectRatio> onRatioSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onRotateClockwise;
  final VoidCallback onCancel;
  final VoidCallback onApply;
  final bool isProcessing;

  const CropToolbar({
    super.key,
    required this.selectedRatio,
    required this.onRatioSelected,
    required this.onSelectAll,
    required this.onRotateClockwise,
    required this.onCancel,
    required this.onApply,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        children: [
          // Aspect Ratios, Rotate, and Select All Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...CropAspectRatio.values.map((ratio) {
                final isSelected = selectedRatio == ratio;
                return ChoiceChip(
                  label: Text(ratio.label(context)),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (_) => onRatioSelected(ratio),
                );
              }),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                onPressed: onSelectAll,
                icon: const Icon(Icons.select_all_rounded, size: 18),
                label: Text(l10n.resetCropAction),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                onPressed: onRotateClockwise,
                icon: const Icon(Icons.rotate_right_rounded, size: 18),
                label: Text(l10n.rotate90Action),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),

          // Actions: Cancel / Confirm
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: isProcessing ? null : onCancel,
                child: Text(l10n.cancel),
              ),
              const SizedBox(width: AppSpacing.s12),
              ElevatedButton.icon(
                onPressed: isProcessing ? null : onApply,
                icon: isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(l10n.applyCropAction),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
