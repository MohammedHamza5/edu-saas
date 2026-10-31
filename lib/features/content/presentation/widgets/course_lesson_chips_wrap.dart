import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/content_entity.dart';

/// Renders the status and metadata chips row for a course lesson.
class CourseLessonChipsWrap extends StatelessWidget {
  final ContentEntity content;
  final bool hasPdf;
  final String? quizTitle;

  const CourseLessonChipsWrap({
    super.key,
    required this.content,
    required this.hasPdf,
    this.quizTitle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Wrap(
      spacing: AppSpacing.s6,
      runSpacing: AppSpacing.s4,
      children: [
        // Visibility status chip
        _MiniChip(
          icon: content.isPublished
              ? Icons.visibility_rounded
              : Icons.visibility_off_rounded,
          label: content.isPublished
              ? l10n.publishedCountLabel
              : l10n.draftCountLabel,
          color: content.isPublished ? AppColors.success : AppColors.warning,
        ),

        // Content type chip
        () {
          final (typeLabel, typeIcon, typeColor) = switch (content.type) {
            ContentType.video => (
              l10n.contentTypeVideo,
              Icons.play_circle_outline_rounded,
              AppColors.primary,
            ),
            ContentType.exam => (
              l10n.contentTypeExam,
              Icons.quiz_outlined,
              AppColors.success,
            ),
            ContentType.assignment => (
              l10n.contentTypeAssignment,
              Icons.assignment_outlined,
              AppColors.warning,
            ),
            ContentType.pdf => (
              l10n.contentTypePdf,
              Icons.picture_as_pdf_outlined,
              const Color(0xFFEA580C),
            ),
            ContentType.image => (
              l10n.contentTypeImage,
              Icons.image_outlined,
              Colors.purple,
            ),
          };
          return _MiniChip(
            icon: typeIcon,
            label: typeLabel,
            color: typeColor,
          );
        }(),

        // PDF chip
        if (hasPdf)
          _MiniChip(
            icon: Icons.picture_as_pdf_rounded,
            label: l10n.hasStudyMaterial,
            color: const Color(0xFFEA580C),
          ),

        // Chapter chip
        if (content.chapterTitle != null && content.chapterTitle!.isNotEmpty)
          _MiniChip(
            icon: Icons.folder_special_rounded,
            label: content.chapterTitle!,
            color: AppColors.info,
          ),

        // Quiz chip
        if (quizTitle != null)
          _MiniChip(
            icon: Icons.quiz_rounded,
            label: l10n.hasLessonQuiz,
            color: AppColors.success,
          ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MiniChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
