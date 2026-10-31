import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';

class ExamReviewNavigationFooter extends StatelessWidget {
  final int currentIndex;
  final int totalQuestions;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  const ExamReviewNavigationFooter({
    super.key,
    required this.currentIndex,
    required this.totalQuestions,
    required this.onPrevious,
    required this.onNext,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s20,
        vertical: AppSpacing.s12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (currentIndex > 0)
            Expanded(
              child: AppButton(
                text: context.l10n.previousQuestion,
                icon: Icons.arrow_back_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: onPrevious,
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: AppSpacing.s12),
          if (currentIndex < totalQuestions - 1)
            Expanded(
              child: AppButton(
                text: context.l10n.nextQuestion,
                icon: Icons.arrow_forward_rounded,
                onPressed: onNext,
              ),
            )
          else
            Expanded(
              child: AppButton(
                text: context.l10n.backToExamsList,
                icon: Icons.check_rounded,
                onPressed: onFinish,
              ),
            ),
        ],
      ),
    );
  }
}
