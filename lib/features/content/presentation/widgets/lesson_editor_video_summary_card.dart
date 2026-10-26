import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/content_entity.dart';

/// Card displaying the selected lecture video thumbnail, title, and change options
class LessonEditorVideoSummaryCard extends StatelessWidget {
  final ContentEntity? selectedVideo;
  final VoidCallback onUseVideoTitle;
  final VoidCallback onPickVideoFromBank;

  const LessonEditorVideoSummaryCard({
    super.key,
    required this.selectedVideo,
    required this.onUseVideoTitle,
    required this.onPickVideoFromBank,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Row(
          children: [
            Container(
              width: 90,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  size: 30,
                  color: AppColors.primary,
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
                      Expanded(
                        child: Text(
                          selectedVideo?.title ?? l10n.lessonEditorSourceVideo,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s4,
                    children: [
                      if (selectedVideo != null)
                        TextButton.icon(
                          onPressed: onUseVideoTitle,
                          icon: const Icon(Icons.sync_rounded, size: 14),
                          label: Text(
                            l10n.useVideoTitleAction,
                            style: const TextStyle(fontSize: 11),
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      TextButton.icon(
                        onPressed: onPickVideoFromBank,
                        icon: const Icon(
                          Icons.change_circle_outlined,
                          size: 14,
                        ),
                        label: Text(
                          l10n.lessonEditorChangeVideo,
                          style: const TextStyle(fontSize: 11),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
