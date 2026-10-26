import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';

/// Bottom bar for the exam creation/editing view, featuring a large "Add Question"
/// dashed button and the primary full-width Submit/Publish action button.
class CreateExamBottomBar extends StatelessWidget {
  final bool isCreating;
  final bool isSubmitting;
  final bool isEditing;
  final VoidCallback onAddQuestion;
  final VoidCallback onSubmit;

  const CreateExamBottomBar({
    super.key,
    required this.isCreating,
    required this.isSubmitting,
    required this.isEditing,
    required this.onAddQuestion,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: isCreating ? null : onAddQuestion,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.s10),
                Text(
                  context.l10n.addQuestionAction,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s24),
        AppButton(
          text: isEditing
              ? context.l10n.saveExamDraftChanges
              : context.l10n.saveAndPublishExam,
          icon: isEditing ? Icons.save_rounded : Icons.publish_rounded,
          isFullWidth: true,
          onPressed: (isCreating || isSubmitting) ? null : onSubmit,
          isLoading: isCreating || isSubmitting,
        ),
        const SizedBox(height: 80), // Clearance for FloatingActionButton
      ],
    );
  }
}
