import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Summary bar showing the total question count, sum of question points,
/// mismatch warning with auto-adjust button, and uniform point assignment tool.
class CreateExamScoreSummaryBar extends StatelessWidget {
  final int questionsCount;
  final int totalQuestionsPoints;
  final int maxScoreNum;
  final TextEditingController defaultPointsController;
  final bool isCreating;
  final VoidCallback onAutoAdjustMaxScore;
  final ValueChanged<int> onDefaultPointsChanged;
  final VoidCallback onApplyDefaultPoints;

  const CreateExamScoreSummaryBar({
    super.key,
    required this.questionsCount,
    required this.totalQuestionsPoints,
    required this.maxScoreNum,
    required this.defaultPointsController,
    required this.isCreating,
    required this.onAutoAdjustMaxScore,
    required this.onDefaultPointsChanged,
    required this.onApplyDefaultPoints,
  });

  bool get isPointsMismatched =>
      maxScoreNum > 0 && maxScoreNum != totalQuestionsPoints;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(
          color: isPointsMismatched
              ? AppColors.warning.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.s16,
        runSpacing: AppSpacing.s10,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.s12,
            runSpacing: AppSpacing.s4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: Text(
                  context.l10n.totalQuestionsSummary(questionsCount),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Text(
                context.l10n.totalPointsSummary(
                  totalQuestionsPoints,
                  maxScoreNum,
                ),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isPointsMismatched
                      ? AppColors.warning
                      : AppColors.textPrimary,
                ),
              ),
              if (isPointsMismatched)
                TextButton.icon(
                  onPressed: onAutoAdjustMaxScore,
                  icon: const Icon(
                    Icons.sync_alt_rounded,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  label: Text(
                    context.l10n.autoAdjustMaxScore(totalQuestionsPoints),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.warning,
                    ),
                  ),
                ),
            ],
          ),

          // Quick Uniform Points in Header
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.tune_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '${context.l10n.defaultQuestionPointsLabel}:',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 52,
                height: 34,
                child: TextField(
                  controller: defaultPointsController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSmall),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSmall),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSmall),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: (v) {
                    final pts = int.tryParse(v.trim());
                    if (pts != null && pts > 0) {
                      onDefaultPointsChanged(pts);
                    }
                  },
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: context.l10n.applyPointsToAllTooltip,
                child: OutlinedButton.icon(
                  onPressed: isCreating ? null : onApplyDefaultPoints,
                  icon: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                  ),
                  label: Text(
                    context.l10n.applyPointsToAllAction,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSmall),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
