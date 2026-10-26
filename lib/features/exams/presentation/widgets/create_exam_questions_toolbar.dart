import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Toolbar section showing question count, collapse/expand toggle,
/// import from question bank, bulk fill options, and add question action.
class CreateExamQuestionsToolbar extends StatelessWidget {
  final int questionsCount;
  final bool isCreating;
  final bool hasExpandedQuestions;
  final VoidCallback onToggleExpandCollapse;
  final VoidCallback onImportFromBank;
  final VoidCallback onBulkFillOptions;
  final VoidCallback onAddQuestion;

  const CreateExamQuestionsToolbar({
    super.key,
    required this.questionsCount,
    required this.isCreating,
    required this.hasExpandedQuestions,
    required this.onToggleExpandCollapse,
    required this.onImportFromBank,
    required this.onBulkFillOptions,
    required this.onAddQuestion,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.s12,
      runSpacing: AppSpacing.s8,
      children: [
        Text(
          context.l10n.questionsSectionTitle(questionsCount),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s4,
          children: [
            if (questionsCount > 1)
              OutlinedButton.icon(
                onPressed: isCreating ? null : onToggleExpandCollapse,
                icon: Icon(
                  hasExpandedQuestions
                      ? Icons.unfold_less_rounded
                      : Icons.unfold_more_rounded,
                  size: 18,
                ),
                label: Text(
                  hasExpandedQuestions
                      ? context.l10n.collapseAllQuestions
                      : context.l10n.expandAllQuestions,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusMedium,
                    ),
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: isCreating ? null : onImportFromBank,
              icon: const Icon(Icons.functions_rounded, size: 18),
              label: Text(context.l10n.importFromQuestionBankAction),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0EA5E9),
                side: const BorderSide(color: Color(0xFF0EA5E9)),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSpacing.radiusMedium,
                  ),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: isCreating ? null : onBulkFillOptions,
              icon: const Icon(
                Icons.auto_fix_high_rounded,
                size: 18,
              ),
              label: Text(context.l10n.bulkFillOptionsTitle),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSpacing.radiusMedium,
                  ),
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: isCreating ? null : onAddQuestion,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(context.l10n.addQuestionAction),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSpacing.radiusMedium,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
