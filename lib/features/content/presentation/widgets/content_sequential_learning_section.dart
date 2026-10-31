import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';

/// Card managing sequential learning prerequisites and associated exam options.
class ContentSequentialLearningSection extends StatelessWidget {
  final bool isLoadingExams;
  final List<Map<String, dynamic>> availableExams;
  final String? selectedAssociatedExamId;
  final String? selectedPrerequisiteExamId;
  final ValueChanged<String?> onAssociatedExamChanged;
  final ValueChanged<String?> onPrerequisiteExamChanged;

  const ContentSequentialLearningSection({
    super.key,
    required this.isLoadingExams,
    required this.availableExams,
    required this.selectedAssociatedExamId,
    required this.selectedPrerequisiteExamId,
    required this.onAssociatedExamChanged,
    required this.onPrerequisiteExamChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.standard,
      padding: const EdgeInsets.all(AppSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.sequentialLearningSectionTitle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),

          // Associated Exam
          if (isLoadingExams)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            DropdownButtonFormField<String?>(
              initialValue: availableExams.any(
                (e) => e['id'] == selectedAssociatedExamId,
              )
                  ? selectedAssociatedExamId
                  : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.l10n.associatedExamLabel,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(
                    context.l10n.noneOption,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ...availableExams.map((exam) {
                  return DropdownMenuItem(
                    value: exam['id'] as String,
                    child: Text(
                      exam['title'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
              onChanged: onAssociatedExamChanged,
            ),

          const SizedBox(height: AppSpacing.s12),

          // Prerequisite Exam
          if (!isLoadingExams)
            DropdownButtonFormField<String?>(
              initialValue: availableExams.any(
                (e) => e['id'] == selectedPrerequisiteExamId,
              )
                  ? selectedPrerequisiteExamId
                  : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.l10n.prerequisiteExamLabel,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(
                    context.l10n.noneOption,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ...availableExams.map((exam) {
                  return DropdownMenuItem(
                    value: exam['id'] as String,
                    child: Text(
                      exam['title'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
              onChanged: onPrerequisiteExamChanged,
            ),
        ],
      ),
    );
  }
}
