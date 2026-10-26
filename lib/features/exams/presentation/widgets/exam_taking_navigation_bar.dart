import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_loading_view.dart';

/// Bottom action bar for exam taking allowing Previous, Review Grid, and Next/Submit actions.
class ExamTakingNavigationBar extends StatelessWidget {
  final bool hasPrevious;
  final bool hasNext;
  final bool isSubmitting;
  final VoidCallback? onPrevious;
  final VoidCallback onReviewGrid;
  final VoidCallback? onNext;
  final VoidCallback onSubmit;

  const ExamTakingNavigationBar({
    super.key,
    required this.hasPrevious,
    required this.hasNext,
    required this.isSubmitting,
    this.onPrevious,
    required this.onReviewGrid,
    this.onNext,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.border.withValues(alpha: 0.7),
          ),
        ),
      ),
      child: Row(
        children: [
          // Review Grid Button
          OutlinedButton.icon(
            onPressed: isSubmitting ? null : onReviewGrid,
            icon: const Icon(Icons.grid_view_rounded, size: 16),
            label: Text(l10n.reviewAllQuestionsAction),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),

          // Previous button
          if (hasPrevious)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isSubmitting ? null : onPrevious,
                icon: const Icon(
                  Icons.arrow_forward,
                  size: 16,
                ),
                label: Text(l10n.previousQuestion),
              ),
            )
          else
            const Spacer(),

          const SizedBox(width: AppSpacing.s12),

          // Next or Submit button
          if (hasNext)
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting ? null : onNext,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: Text(l10n.nextQuestion),
              ),
            )
          else
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting ? null : onSubmit,
                icon: const Icon(
                  Icons.check_circle_outline,
                  size: 16,
                ),
                label: isSubmitting
                    ? const AppLoadingView.compact(
                        size: 16,
                        color: Colors.white,
                      )
                    : Text(l10n.submitExamNow),
              ),
            ),
        ],
      ),
    );
  }
}
