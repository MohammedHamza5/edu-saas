import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Exam / Quiz selector section for [LessonSetupSheet].
class LessonSetupQuizSection extends StatelessWidget {
  final bool isLoadingExams;
  final String? selectedExamId;
  final List<Map<String, dynamic>> availableExams;
  final ValueChanged<String?> onExamChanged;

  const LessonSetupQuizSection({
    super.key,
    required this.isLoadingExams,
    required this.selectedExamId,
    required this.availableExams,
    required this.onExamChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.quiz_rounded,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              l10n.lessonQuizLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        if (isLoadingExams)
          const LinearProgressIndicator()
        else ...[
          DropdownButtonFormField<String>(
            initialValue: selectedExamId,
            decoration: InputDecoration(
              hintText: l10n.lessonQuizHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppSpacing.radiusMedium,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: Text(
                  l10n.lessonQuizHint,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ...availableExams.map((exam) {
                return DropdownMenuItem<String>(
                  value: exam['id'] as String,
                  child: Text(
                    exam['title'] as String? ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ],
            onChanged: onExamChanged,
          ),
          if (selectedExamId != null) ...[
            const SizedBox(height: AppSpacing.s8),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      l10n.lessonQuizSequentialRequirement,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}
