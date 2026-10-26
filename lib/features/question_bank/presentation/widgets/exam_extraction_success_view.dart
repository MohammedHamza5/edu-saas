import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/question_entity.dart';

/// Success view shown after exam extraction is complete.
/// Displays extracted questions preview and provides options to deploy
/// as an exam to a group or keep in the Question Bank.
class ExamExtractionSuccessView extends StatelessWidget {
  final List<QuestionEntity> extractedQuestions;
  final String extractedFilename;
  final String? publishedExamId;
  final bool showAssignForm;
  final bool isAssigning;
  final List<Map<String, dynamic>> groups;
  final String? selectedGroupId;
  final TextEditingController examTitleController;
  final TextEditingController durationController;
  final ValueChanged<bool> onToggleAssignForm;
  final ValueChanged<String?> onSelectedGroupChanged;
  final VoidCallback onPublishExam;
  final VoidCallback onNavigateToExams;
  final VoidCallback onClose;

  const ExamExtractionSuccessView({
    super.key,
    required this.extractedQuestions,
    required this.extractedFilename,
    required this.publishedExamId,
    required this.showAssignForm,
    required this.isAssigning,
    required this.groups,
    required this.selectedGroupId,
    required this.examTitleController,
    required this.durationController,
    required this.onToggleAssignForm,
    required this.onSelectedGroupChanged,
    required this.onPublishExam,
    required this.onNavigateToExams,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Success Celebration Header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s10),
              decoration: BoxDecoration(
                color: AppColors.successLight.withAlpha(80),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: AppColors.success.withAlpha(100)),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.extractionSuccessTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    l10n.extractionSuccessDesc(
                      extractedQuestions.length,
                      extractedFilename,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onClose,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),

        // Extracted Questions Preview Chips
        Text(
          l10n.extractedQuestionsPreview,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Container(
          height: 72,
          padding: const EdgeInsets.all(AppSpacing.s8),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withAlpha(50),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: extractedQuestions.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s8),
            itemBuilder: (context, idx) {
              final q = extractedQuestions[idx];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s10,
                  vertical: AppSpacing.s6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Q${idx + 1}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          q.questionType == 'multiple_choice'
                              ? 'MCQ'
                              : 'Grid-in',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      q.sourceLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.s20),

        // ── PATH 1: Deploy as Exam to Study Group ────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: publishedExamId != null
                ? AppColors.successLight.withAlpha(40)
                : AppColors.primary.withAlpha(15),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(
              color: publishedExamId != null
                  ? AppColors.success.withAlpha(80)
                  : AppColors.primary.withAlpha(60),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (publishedExamId != null) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: AppColors.success,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        l10n.examPublishedSuccess,
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      text: l10n.goToExamsPage,
                      icon: Icons.assignment_turned_in_rounded,
                      variant: AppButtonVariant.primary,
                      onPressed: onNavigateToExams,
                    ),
                  ],
                ),
              ] else if (!showAssignForm) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.rocket_launch_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.assignAsExamAction,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            l10n.assignAsExamDesc,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppButton(
                      text: 'تعيين لمجموعة الآن',
                      variant: AppButtonVariant.primary,
                      onPressed: () => onToggleAssignForm(true),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.assignAsExamAction,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.primary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => onToggleAssignForm(false),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s10),

                // Group Selector Dropdown
                Text(
                  l10n.selectTargetGroup,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                DropdownButtonFormField<String>(
                  initialValue: selectedGroupId,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hintText: l10n.selectTargetGroupHint,
                  ),
                  items: groups.map((g) {
                    final name = g['name']?.toString() ?? 'Group';
                    final level = g['level']?.toString() ?? '';
                    return DropdownMenuItem<String>(
                      value: g['id'] as String,
                      child: Text(
                        '$name ($level)',
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: onSelectedGroupChanged,
                ),
                const SizedBox(height: AppSpacing.s12),

                // Exam Title & Duration
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: AppTextField(
                        controller: examTitleController,
                        label: l10n.examTitleLabel,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      flex: 1,
                      child: AppTextField(
                        controller: durationController,
                        label: l10n.examDurationMinutesLabel,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => onToggleAssignForm(false),
                      child: Text(
                        MaterialLocalizations.of(context).cancelButtonLabel,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    AppButton(
                      text: l10n.publishExamToGroupAction,
                      icon: Icons.send_rounded,
                      isLoading: isAssigning,
                      onPressed: (selectedGroupId != null && !isAssigning)
                          ? onPublishExam
                          : null,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        // ── PATH 2: Keep in Question Bank for Review ─────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.saveToQuestionBankOnly,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      l10n.saveToQuestionBankDesc,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AppButton(
                text: 'العودة لبنك الأسئلة',
                variant: AppButtonVariant.outlined,
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
