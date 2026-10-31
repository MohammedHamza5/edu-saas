import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../videos/domain/entities/library_video_entity.dart';
import '../models/lesson_studio_models.dart';

/// Single video row in the library sidebar tree.
/// Displays selection checkbox, duration tag, title, and PDF/Exam badges.
class LessonStudioLibraryVideoRow extends StatelessWidget {
  final LibraryVideoEntity video;
  final bool isSelected;
  final bool isAlreadyAdded;
  final StagedLecture? staged;
  final ValueChanged<LibraryVideoEntity> onToggle;

  const LessonStudioLibraryVideoRow({
    super.key,
    required this.video,
    required this.isSelected,
    required this.isAlreadyAdded,
    this.staged,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final hasPdf = staged != null && staged!.hasPdf;
    final hasExam = staged != null && staged!.hasExam;

    return InkWell(
      onTap: () => onToggle(video),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              visualDensity: VisualDensity.compact,
              onChanged: (_) => onToggle(video),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                video.formattedDuration,
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      if (isAlreadyAdded) ...[
                        Text(
                          context.l10n.alreadyAddedBadge,
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (hasPdf) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEA580C)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFFEA580C)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.picture_as_pdf_rounded,
                                size: 9,
                                color: Color(0xFFEA580C),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                context.l10n.smartBadgePdf,
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFEA580C),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (hasExam) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.quiz_rounded,
                                size: 9,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                context.l10n.smartBadgeExam,
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
