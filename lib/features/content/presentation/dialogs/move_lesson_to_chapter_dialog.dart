import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/content_entity.dart';

/// Dialog allowing teacher to move a lesson between chapters or to unassign it
class MoveLessonToChapterDialog extends StatelessWidget {
  final ContentEntity lesson;
  final List<ChapterEntity> chapters;

  const MoveLessonToChapterDialog({
    super.key,
    required this.lesson,
    required this.chapters,
  });

  static Future<String?> show(
    BuildContext context, {
    required ContentEntity lesson,
    required List<ChapterEntity> chapters,
  }) {
    return showDialog<String?>(
      context: context,
      builder: (ctx) => MoveLessonToChapterDialog(
        lesson: lesson,
        chapters: chapters,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SimpleDialog(
      title: Row(
        children: [
          const Icon(Icons.drive_file_move_outlined, color: AppColors.primary),
          const SizedBox(width: AppSpacing.s8),
          Text(l10n.selectTargetChapter),
        ],
      ),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop('__NONE__'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.remove_circle_outline,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.s12),
                Text(
                  l10n.noChapterOption,
                  style: TextStyle(
                    fontWeight: lesson.chapterId == null
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: lesson.chapterId == null
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        for (int i = 0; i < chapters.length; i++) ...[
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(chapters[i].id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      (i + 1).toString().padLeft(2, '0'),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Text(
                      chapters[i].title,
                      style: TextStyle(
                        fontWeight: lesson.chapterId == chapters[i].id
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: lesson.chapterId == chapters[i].id
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (lesson.chapterId == chapters[i].id)
                    const Icon(
                      Icons.check_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
