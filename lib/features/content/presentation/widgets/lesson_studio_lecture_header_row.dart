import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../models/lesson_studio_models.dart';

/// Top row of a staged lecture card in Lesson Studio: drag handle, index, thumbnail, title field, duration, and remove button.
class LessonStudioLectureHeaderRow extends StatelessWidget {
  final StagedLecture staged;
  final int index;
  final bool isOnlyOne;
  final VoidCallback onRemoveVideo;

  const LessonStudioLectureHeaderRow({
    super.key,
    required this.staged,
    required this.index,
    required this.isOnlyOne,
    required this.onRemoveVideo,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!isOnlyOne) ...[
          ReorderableDragStartListener(
            index: index,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.drag_indicator_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s10),
        ],

        // Thumbnail
        Container(
          width: 72,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
            image: staged.video.thumbnailUrl != null
                ? DecorationImage(
                    image: NetworkImage(staged.video.thumbnailUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: Center(
            child: Icon(
              Icons.play_circle_fill_rounded,
              size: 20,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s12),

        // Editable Title Field
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: staged.titleController,
                      labelText: l10n.lessonTitleLabel,
                      hintText: staged.video.title,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Duration badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      staged.video.formattedDuration,
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.s8),

        // Remove video button
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          color: AppColors.error,
          tooltip: l10n.cancel,
          onPressed: onRemoveVideo,
        ),
      ],
    );
  }
}
