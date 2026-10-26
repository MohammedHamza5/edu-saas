import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';

/// Top command bar for Lesson Studio Workspace with navigation, group context,
/// selection indicators, and action triggers.
class LessonStudioHeader extends StatelessWidget {
  final String groupName;
  final int selectedVideosCount;
  final bool isSaving;
  final VoidCallback onCancel;
  final VoidCallback? onSave;

  const LessonStudioHeader({
    super.key,
    required this.groupName,
    required this.selectedVideosCount,
    required this.isSaving,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s20,
        vertical: AppSpacing.s12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: Text(l10n.backToCourse),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l10n.lessonStudioTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.primary.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Text(
                        groupName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.lessonStudioSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Selection Counter Pill
          if (selectedVideosCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    selectedVideosCount == 1
                        ? l10n.singleLectureSetup
                        : l10n.batchModeTitle(selectedVideosCount),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
          ],

          // Action Buttons in Header
          TextButton(
            onPressed: onCancel,
            child: Text(l10n.cancel),
          ),
          const SizedBox(width: AppSpacing.s8),
          AppButton(
            text: selectedVideosCount > 1
                ? l10n.addBatchLecturesButton(selectedVideosCount)
                : l10n.saveLectureButton,
            icon: selectedVideosCount > 1
                ? Icons.rocket_launch_rounded
                : Icons.save_rounded,
            isLoading: isSaving,
            onPressed: selectedVideosCount == 0 ? null : onSave,
          ),
        ],
      ),
    );
  }
}
