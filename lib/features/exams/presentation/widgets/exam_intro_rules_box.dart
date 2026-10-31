import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Important instructions before start box for exam intro.
class ExamIntroRulesBox extends StatelessWidget {
  final bool isUntimed;
  final bool isLectureExam;

  const ExamIntroRulesBox({
    super.key,
    required this.isUntimed,
    required this.isLectureExam,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.importantInstructionsBeforeStart,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Container(
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isUntimed) ...[
                _RuleItem(text: context.l10n.ruleUntimedLectureExam),
                const SizedBox(height: AppSpacing.s8),
                _RuleItem(text: context.l10n.ruleAutoSaveAnswers),
                const SizedBox(height: AppSpacing.s8),
                if (isLectureExam) ...[
                  _RuleItem(text: context.l10n.ruleRetakeAllowedNotice),
                  const SizedBox(height: AppSpacing.s8),
                ],
                _RuleItem(text: context.l10n.ruleDoNotCloseWindow),
              ] else ...[
                _RuleItem(text: context.l10n.ruleTimerStartsImmediately),
                const SizedBox(height: AppSpacing.s8),
                _RuleItem(text: context.l10n.ruleAutoSaveAnswers),
                const SizedBox(height: AppSpacing.s8),
                _RuleItem(text: context.l10n.ruleAutoSubmitOnTimeout),
                const SizedBox(height: AppSpacing.s8),
                _RuleItem(text: context.l10n.ruleDoNotCloseWindow),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RuleItem extends StatelessWidget {
  final String text;
  const _RuleItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Icon(
            Icons.check_circle_outline,
            size: 14,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
