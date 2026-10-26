import 'package:flutter/material.dart';
import 'package:edu_saas/core/extensions/localized_context_extension.dart';
import 'package:edu_saas/core/theme/app_colors.dart';
import 'package:edu_saas/core/theme/app_spacing.dart';
import 'package:edu_saas/core/widgets/app_button.dart';
import 'bluebook_question_cell.dart';

class BluebookReviewGridModal extends StatelessWidget {
  final int totalQuestions;
  final int currentQuestionIndex;
  final Set<int> answeredIndices;
  final Set<int> flaggedIndices;
  final ValueChanged<int> onQuestionSelected;
  final VoidCallback onConfirmFinish;

  const BluebookReviewGridModal({
    super.key,
    required this.totalQuestions,
    required this.currentQuestionIndex,
    required this.answeredIndices,
    required this.flaggedIndices,
    required this.onQuestionSelected,
    required this.onConfirmFinish,
  });

  static void show(
    BuildContext context, {
    required int totalQuestions,
    required int currentQuestionIndex,
    required Set<int> answeredIndices,
    required Set<int> flaggedIndices,
    required ValueChanged<int> onQuestionSelected,
    required VoidCallback onConfirmFinish,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BluebookReviewGridModal(
        totalQuestions: totalQuestions,
        currentQuestionIndex: currentQuestionIndex,
        answeredIndices: answeredIndices,
        flaggedIndices: flaggedIndices,
        onQuestionSelected: onQuestionSelected,
        onConfirmFinish: onConfirmFinish,
      ),
    );
  }

  int get unansweredCount => totalQuestions - answeredIndices.length;

  void _handleFinishAttempt(BuildContext context) {
    if (unansweredCount > 0) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.unansweredQuestionsWarning(unansweredCount)),
          content: Text(context.l10n.unansweredQuestionsDesc),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
                onConfirmFinish();
              },
              child: Text(context.l10n.submitExamNow),
            ),
          ],
        ),
      );
    } else {
      Navigator.of(context).pop();
      onConfirmFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLarge)),
      ),
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.bluebookReviewGrid,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          _buildLegend(context),
          const SizedBox(height: AppSpacing.s16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 64,
                mainAxisSpacing: AppSpacing.s8,
                crossAxisSpacing: AppSpacing.s8,
                childAspectRatio: 1.0,
              ),
              itemCount: totalQuestions,
              itemBuilder: (ctx, idx) => BluebookQuestionCell(
                index: idx,
                isCurrent: idx == currentQuestionIndex,
                isAnswered: answeredIndices.contains(idx),
                isFlagged: flaggedIndices.contains(idx),
                onTap: () {
                  Navigator.of(context).pop();
                  onQuestionSelected(idx);
                },
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s20),
          AppButton(
            text: context.l10n.submitExamNow,
            variant: AppButtonVariant.primary,
            onPressed: () => _handleFinishAttempt(context),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.s12,
      runSpacing: AppSpacing.s8,
      children: [
        _buildLegendItem(color: AppColors.success, label: context.l10n.answeredStatus),
        _buildLegendItem(color: AppColors.border, label: context.l10n.unansweredStatus),
        _buildLegendItem(color: AppColors.warning, label: context.l10n.flaggedForReview, icon: Icons.flag_rounded),
      ],
    );
  }

  Widget _buildLegendItem({required Color color, required String label, IconData? icon}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(3),
          ),
          child: icon != null ? Icon(icon, size: 10, color: color) : null,
        ),
        const SizedBox(width: AppSpacing.s6),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
