import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/exam_entity.dart';

class ExamCardTeacherLinkageBanner extends StatelessWidget {
  final ExamEntity exam;
  final bool isLecture;
  final VoidCallback? onLinkLecture;

  const ExamCardTeacherLinkageBanner({
    super.key,
    required this.exam,
    required this.isLecture,
    this.onLinkLecture,
  });

  @override
  Widget build(BuildContext context) {
    if (isLecture && exam.isLinkedToLesson) {
      return Container(
        margin: const EdgeInsets.only(top: AppSpacing.s10),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s10,
          vertical: AppSpacing.s6,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0284C7).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(
            AppSpacing.radiusSmall,
          ),
          border: Border.all(
            color: const Color(0xFF0284C7).withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.link_rounded,
              size: 15,
              color: Color(0xFF0284C7),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                context.l10n.linkedToLecturePill(
                  exam.linkedLessonTitle ?? '',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0284C7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onLinkLecture != null)
              InkWell(
                onTap: onLinkLecture,
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Icon(
                    Icons.swap_horiz_rounded,
                    size: 16,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
          ],
        ),
      );
    } else if (isLecture && !exam.isLinkedToLesson) {
      return Container(
        margin: const EdgeInsets.only(top: AppSpacing.s10),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s10,
          vertical: AppSpacing.s6,
        ),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(
            AppSpacing.radiusSmall,
          ),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 15,
              color: AppColors.warning,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                context.l10n.unlinkedQuizPill,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onLinkLecture != null) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: onLinkLecture,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Text(
                    context.l10n.linkToLectureNowAction,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.only(top: AppSpacing.s10),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s10,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(
            AppSpacing.radiusSmall,
          ),
          border: Border.all(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.public_rounded,
              size: 13,
              color: Color(0xFF7C3AED),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                context.l10n.statGeneralExamsDesc,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF7C3AED),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
  }
}
