import 'package:flutter/material.dart';
import 'package:edu_saas/core/extensions/localized_context_extension.dart';
import 'package:edu_saas/core/theme/app_colors.dart';
import 'package:edu_saas/core/theme/app_spacing.dart';
import 'package:edu_saas/core/widgets/app_button.dart';
import 'package:edu_saas/features/exams/domain/entities/question_difficulty_rating.dart';
import 'spaced_repetition_rating_bar.dart';

class SmartPracticeBottomBar extends StatelessWidget {
  final bool isSubmitted;
  final bool isCorrect;
  final bool isMastered;
  final bool hasNext;
  final bool canCheck;
  final VoidCallback onCheck;
  final VoidCallback onNext;
  final VoidCallback onToggleMastered;
  final ValueChanged<QuestionDifficultyRating> onRateDifficulty;

  const SmartPracticeBottomBar({
    super.key,
    required this.isSubmitted,
    required this.isCorrect,
    required this.isMastered,
    required this.hasNext,
    required this.canCheck,
    required this.onCheck,
    required this.onNext,
    required this.onToggleMastered,
    required this.onRateDifficulty,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isSubmitted) ...[
              _buildFeedbackBanner(context),
              const SizedBox(height: AppSpacing.s12),
              SpacedRepetitionRatingBar(
                onRate: onRateDifficulty,
                onToggleMastered: onToggleMastered,
                isMastered: isMastered,
              ),
              const SizedBox(height: AppSpacing.s10),
              AppButton(
                text: hasNext ? context.l10n.nextQuestionAction : context.l10n.finishSession,
                icon: hasNext ? Icons.arrow_forward_rounded : Icons.flag_rounded,
                variant: AppButtonVariant.outlined,
                onPressed: onNext,
              ),
            ] else ...[
              AppButton(
                text: context.l10n.checkAnswerButton,
                icon: Icons.check_rounded,
                onPressed: canCheck ? onCheck : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackBanner(BuildContext context) {
    final color = isCorrect ? AppColors.success : AppColors.error;
    final message = isCorrect
        ? context.l10n.correctAnswerCelebration
        : context.l10n.wrongAnswerNotice;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            isCorrect ? Icons.celebration_rounded : Icons.info_outline_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
