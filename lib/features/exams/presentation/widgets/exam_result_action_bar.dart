import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../content/domain/entities/lesson_assignment_entity.dart';

class ExamResultActionBar extends StatelessWidget {
  final bool isLecture;
  final bool isPassed;
  final bool hasAttachedPdf;
  final bool allowRetake;
  final bool isLoadingNextLesson;
  final bool isRetaking;
  final LessonAssignmentEntity? nextLesson;
  final VoidCallback onNextLesson;
  final VoidCallback onOpenPdfBooklet;
  final VoidCallback onReview;
  final VoidCallback onRetake;
  final VoidCallback onBack;

  const ExamResultActionBar({
    super.key,
    required this.isLecture,
    required this.isPassed,
    required this.hasAttachedPdf,
    required this.allowRetake,
    required this.isLoadingNextLesson,
    required this.isRetaking,
    required this.nextLesson,
    required this.onNextLesson,
    required this.onOpenPdfBooklet,
    required this.onReview,
    required this.onRetake,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    if (isLecture) {
      if (isPassed) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (nextLesson != null) ...[
              AppButton(
                text: context.l10n.goToNextLectureSpecific(
                  nextLesson!.title,
                ),
                icon: Icons.play_circle_outline_rounded,
                isLoading: isLoadingNextLesson,
                onPressed: onNextLesson,
              ),
              const SizedBox(height: AppSpacing.s10),
            ],
            if (hasAttachedPdf) ...[
              AppButton(
                text: context.l10n.viewExamBooklet,
                icon: Icons.picture_as_pdf_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: onOpenPdfBooklet,
              ),
              const SizedBox(height: AppSpacing.s10),
            ],
            AppButton(
              text: context.l10n.reviewAllQuestionsAction,
              icon: Icons.fact_check_outlined,
              variant: nextLesson != null
                  ? AppButtonVariant.secondary
                  : AppButtonVariant.primary,
              onPressed: onReview,
            ),
            const SizedBox(height: AppSpacing.s10),
            AppButton(
              text: context.l10n.backToLecturesList,
              icon: Icons.menu_book_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: onBack,
            ),
            if (allowRetake) ...[
              const SizedBox(height: AppSpacing.s8),
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    context.l10n.retakeToImproveScore,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: onRetake,
                ),
              ),
            ],
          ],
        );
      } else {
        // Lecture exam failed: Prominent Retry button!
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              text: context.l10n.tryAgainExamAction,
              icon: Icons.replay_rounded,
              isLoading: isRetaking,
              onPressed: onRetake,
            ),
            const SizedBox(height: AppSpacing.s10),
            if (hasAttachedPdf) ...[
              AppButton(
                text: context.l10n.viewExamBooklet,
                icon: Icons.picture_as_pdf_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: onOpenPdfBooklet,
              ),
              const SizedBox(height: AppSpacing.s10),
            ],
            AppButton(
              text: context.l10n.reviewAllQuestionsAction,
              icon: Icons.fact_check_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: onReview,
            ),
            const SizedBox(height: AppSpacing.s10),
            AppButton(
              text: context.l10n.backToLecturesList,
              icon: Icons.menu_book_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: onBack,
            ),
          ],
        );
      }
    } else {
      // Non-lecture exam (general course exam)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasAttachedPdf) ...[
            AppButton(
              text: context.l10n.viewExamBooklet,
              icon: Icons.picture_as_pdf_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: onOpenPdfBooklet,
            ),
            const SizedBox(height: AppSpacing.s10),
          ],
          AppButton(
            text: context.l10n.reviewAllQuestionsAction,
            icon: Icons.fact_check_outlined,
            onPressed: onReview,
          ),
          if (allowRetake) ...[
            const SizedBox(height: AppSpacing.s10),
            AppButton(
              text: context.l10n.retakeToImproveScore,
              icon: Icons.replay_rounded,
              variant: AppButtonVariant.secondary,
              isLoading: isRetaking,
              onPressed: onRetake,
            ),
          ],
          const SizedBox(height: AppSpacing.s10),
          AppButton(
            text: context.l10n.backToExamsList,
            icon: Icons.home_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: onBack,
          ),
        ],
      );
    }
  }
}
