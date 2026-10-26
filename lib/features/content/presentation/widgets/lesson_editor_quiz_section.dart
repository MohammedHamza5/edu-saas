import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';

/// Model representing an attached quiz item in the lesson editor
class LessonEditorAttachedExam {
  final String examId;
  String examTitle;
  bool isRequired;
  int? passingScore;

  LessonEditorAttachedExam({
    required this.examId,
    required this.examTitle,
    this.isRequired = true,
    this.passingScore,
  });
}

/// Gatekeeper Quiz Card section in the lesson editor
class LessonEditorQuizSection extends StatelessWidget {
  final List<LessonEditorAttachedExam> attachedExams;
  final bool isLoadingExams;
  final List<Map<String, dynamic>> availableExams;
  final VoidCallback onOpenCreateQuiz;
  final ValueChanged<String> onAddExistingExam;
  final ValueChanged<int> onRemoveExam;
  final ValueChanged<int> onToggleRequirement;
  final bool useCustomScore;
  final ValueChanged<bool> onToggleCustomScore;
  final TextEditingController customScoreController;
  final int defaultPassingScore;

  const LessonEditorQuizSection({
    super.key,
    required this.attachedExams,
    required this.isLoadingExams,
    required this.availableExams,
    required this.onOpenCreateQuiz,
    required this.onAddExistingExam,
    required this.onRemoveExam,
    required this.onToggleRequirement,
    required this.useCustomScore,
    required this.onToggleCustomScore,
    required this.customScoreController,
    required this.defaultPassingScore,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.attachedQuizzesSection,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.attachedQuizzesSectionSubtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (attachedExams.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                    ),
                    child: Text(
                      l10n.attachedQuizzesCount(attachedExams.length),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            if (isLoadingExams)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else ...[
              if (attachedExams.isNotEmpty) ...[
                ...attachedExams.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final examItem = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.s10),
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: examItem.isRequired
                          ? AppColors.primary.withValues(alpha: 0.04)
                          : AppColors.surfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMedium,
                      ),
                      border: Border.all(
                        color: examItem.isRequired
                            ? AppColors.primary.withValues(alpha: 0.25)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: examItem.isRequired
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : AppColors.textMuted.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSmall,
                            ),
                          ),
                          child: Icon(
                            Icons.quiz_rounded,
                            color: examItem.isRequired
                                ? AppColors.primary
                                : AppColors.textMuted,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                examItem.examTitle.isNotEmpty
                                    ? examItem.examTitle
                                    : l10n.lessonEditorLessonQuiz,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${l10n.quizPrefix} #${idx + 1}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Toggle isRequired chip
                        InkWell(
                          onTap: () => onToggleRequirement(idx),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusFull,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: examItem.isRequired
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusFull,
                              ),
                              border: Border.all(
                                color: examItem.isRequired
                                    ? AppColors.primary.withValues(alpha: 0.4)
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  examItem.isRequired
                                      ? Icons.lock_rounded
                                      : Icons.check_circle_outline_rounded,
                                  size: 13,
                                  color: examItem.isRequired
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  examItem.isRequired
                                      ? l10n.requiredForProgression
                                      : l10n.optionalPractice,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: examItem.isRequired
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.error,
                            size: 18,
                          ),
                          tooltip: l10n.unlinkQuizAction,
                          onPressed: () => onRemoveExam(idx),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.s8),
              ],

              // Add Quiz Action Row
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: l10n.createInstantQuizAction,
                      icon: Icons.add_task_rounded,
                      onPressed: onOpenCreateQuiz,
                      variant: attachedExams.isEmpty
                          ? AppButtonVariant.primary
                          : AppButtonVariant.outlined,
                    ),
                  ),
                ],
              ),

              // Dropdown to pick from existing available exams not already attached
              Builder(
                builder: (ctx) {
                  final unattached = availableExams.where(
                    (e) => !attachedExams.any((a) => a.examId == e['id']),
                  ).toList();
                  if (unattached.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.s10),
                      DropdownButtonFormField<String?>(
                        value: null,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.background,
                          hintText: l10n.selectExistingQuizAction,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(
                              '+ ${l10n.selectExistingQuizAction}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ...unattached.map(
                            (e) => DropdownMenuItem(
                              value: e['id'] as String,
                              child: Text(e['title'] as String),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            onAddExistingExam(val);
                          }
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: AppSpacing.s16),

            // Passing Score Configuration
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.lessonEditorPassingScoreReq,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Switch(
                  value: useCustomScore,
                  onChanged: onToggleCustomScore,
                  activeColor: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            if (useCustomScore)
              AppTextField(
                controller: customScoreController,
                keyboardType: TextInputType.number,
                label: l10n.lessonEditorCustomPassingScore,
                suffixIcon: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('%', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              )
            else
              Text(
                l10n.lessonEditorDefaultPassingScore(defaultPassingScore),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}
