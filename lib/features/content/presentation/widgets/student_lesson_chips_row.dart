import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/content_entity.dart';
import '../../domain/entities/lesson_assignment_entity.dart';

/// Informative handout and quiz badges displayed in the student lesson tile meta row.
class StudentLessonChipsRow extends StatelessWidget {
  final ContentEntity content;
  final LessonAssignmentEntity? lesson;

  const StudentLessonChipsRow({
    super.key,
    required this.content,
    this.lesson,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handout Chip (Informative PDF Badge)
        if (content.file != null || (lesson?.pdfFileId != null)) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFEA580C).withAlpha(18),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: const Color(0xFFEA580C).withAlpha(60),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.picture_as_pdf_rounded,
                  size: 11,
                  color: Color(0xFFEA580C),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    context.l10n.lessonHandoutChip,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
        ],

        // Quiz Chip (Informative Quiz Badge)
        if (content.type != ContentType.exam &&
            (content.attachedExams.isNotEmpty ||
                content.associatedExamTitle != null)) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (content.isExamPassed
                      ? AppColors.success
                      : AppColors.primary)
                  .withAlpha(18),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: (content.isExamPassed
                        ? AppColors.success
                        : AppColors.primary)
                    .withAlpha(60),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  content.isExamPassed
                      ? Icons.check_circle_rounded
                      : Icons.quiz_rounded,
                  size: 11,
                  color: content.isExamPassed
                      ? AppColors.success
                      : AppColors.primary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    content.isExamPassed
                        ? (content.attachedExams.length > 1
                            ? '${content.attachedExams.length} ${context.l10n.attachedQuizzesSection} (${context.l10n.statusCompleted})'
                            : '${context.l10n.lessonQuizChip} (${context.l10n.statusCompleted})')
                        : (content.attachedExams.length > 1
                            ? '${content.attachedExams.where((e) => e.isPassed).length}/${content.attachedExams.length} ${context.l10n.attachedQuizzesSection}'
                            : context.l10n.lessonQuizChip),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: content.isExamPassed
                          ? AppColors.success
                          : AppColors.primary,
                    ),
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
