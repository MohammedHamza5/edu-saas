import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';

/// Card containing all general settings for the exam being created or edited.
class CreateExamGeneralSettingsCard extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController durationController;
  final TextEditingController maxScoreController;
  final TextEditingController passingScoreController;
  final TextEditingController defaultPointsController;
  final bool isCreating;
  final bool shuffle;
  final bool showResult;
  final bool allowRetake;
  final bool isPublished;
  final bool saveToQuestionBank;
  final VoidCallback onApplyDefaultPoints;
  final ValueChanged<int> onDefaultPointsChanged;
  final ValueChanged<bool> onShuffleChanged;
  final ValueChanged<bool> onShowResultChanged;
  final ValueChanged<bool> onAllowRetakeChanged;
  final ValueChanged<bool> onIsPublishedChanged;
  final ValueChanged<bool> onSaveToQuestionBankChanged;
  final VoidCallback onMaxScoreChanged;

  const CreateExamGeneralSettingsCard({
    super.key,
    required this.titleController,
    required this.durationController,
    required this.maxScoreController,
    required this.passingScoreController,
    required this.defaultPointsController,
    required this.isCreating,
    required this.shuffle,
    required this.showResult,
    required this.allowRetake,
    required this.isPublished,
    required this.saveToQuestionBank,
    required this.onApplyDefaultPoints,
    required this.onDefaultPointsChanged,
    required this.onShuffleChanged,
    required this.onShowResultChanged,
    required this.onAllowRetakeChanged,
    required this.onIsPublishedChanged,
    required this.onSaveToQuestionBankChanged,
    required this.onMaxScoreChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Text(
                context.l10n.examGeneralSettings,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s20),

          AppTextField(
            controller: titleController,
            labelText: context.l10n.examTitleField,
            hintText: context.l10n.examTitleHint,
            prefixIcon: const Icon(Icons.assignment_outlined),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return context.l10n.examTitleRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.s16),

          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 650;
              final defaultPointsWidget = Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: defaultPointsController,
                      labelText: context.l10n.defaultQuestionPointsLabel,
                      hintText: '5',
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.stars_outlined),
                      onChanged: (val) {
                        final pts = int.tryParse(val.trim());
                        if (pts != null && pts > 0) {
                          onDefaultPointsChanged(pts);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Tooltip(
                    message: context.l10n.applyPointsToAllTooltip,
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: isCreating ? null : onApplyDefaultPoints,
                        icon: const Icon(
                          Icons.auto_awesome_rounded,
                          size: 16,
                        ),
                        label: Text(
                          context.l10n.applyPointsToAllAction,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMedium,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );

              if (isCompact) {
                return Column(
                  children: [
                    AppTextField(
                      controller: durationController,
                      labelText: context.l10n.durationMinutesField,
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.timer_outlined),
                      validator: (v) {
                        final num = int.tryParse(v ?? '');
                        if (num == null || num <= 0) {
                          return context.l10n.positiveNumberRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    defaultPointsWidget,
                    const SizedBox(height: AppSpacing.s12),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: maxScoreController,
                            labelText: context.l10n.maxScoreField,
                            keyboardType: TextInputType.number,
                            prefixIcon: const Icon(Icons.grade_outlined),
                            onChanged: (_) => onMaxScoreChanged(),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        Expanded(
                          child: AppTextField(
                            controller: passingScoreController,
                            labelText: context.l10n.passingScoreField,
                            keyboardType: TextInputType.number,
                            prefixIcon: const Icon(Icons.verified_outlined),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: durationController,
                          labelText: context.l10n.durationMinutesField,
                          keyboardType: TextInputType.number,
                          prefixIcon: const Icon(Icons.timer_outlined),
                          validator: (v) {
                            final num = int.tryParse(v ?? '');
                            if (num == null || num <= 0) {
                              return context.l10n.positiveNumberRequired;
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(child: defaultPointsWidget),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: maxScoreController,
                          labelText: context.l10n.maxScoreField,
                          keyboardType: TextInputType.number,
                          prefixIcon: const Icon(Icons.grade_outlined),
                          onChanged: (_) => onMaxScoreChanged(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: AppTextField(
                          controller: passingScoreController,
                          labelText: context.l10n.passingScoreField,
                          keyboardType: TextInputType.number,
                          prefixIcon: const Icon(Icons.verified_outlined),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.s16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.s12),

          // Toggles
          SwitchListTile(
            title: Text(
              context.l10n.shuffleQuestionsTitle,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              context.l10n.shuffleQuestionsSubtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            value: shuffle,
            activeThumbColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: isCreating ? null : onShuffleChanged,
          ),
          SwitchListTile(
            title: Text(
              context.l10n.showResultTitle,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              context.l10n.showResultSubtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            value: showResult,
            activeThumbColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: isCreating ? null : onShowResultChanged,
          ),
          SwitchListTile(
            title: Text(
              context.l10n.allowRetakeTitle,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              context.l10n.allowRetakeSubtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            value: allowRetake,
            activeThumbColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: isCreating ? null : onAllowRetakeChanged,
          ),
          const Divider(height: 20),
          SwitchListTile(
            title: Text(
              context.l10n.examPublishImmediatelyTitle,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              context.l10n.examPublishImmediatelyDesc,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            value: isPublished,
            activeThumbColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: isCreating ? null : onIsPublishedChanged,
          ),
          const Divider(height: 20),
          SwitchListTile(
            title: Text(
              context.l10n.saveToQuestionBankToggle,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              context.l10n.saveToQuestionBankTooltip,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            value: saveToQuestionBank,
            activeThumbColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: isCreating ? null : onSaveToQuestionBankChanged,
          ),
        ],
      ),
    );
  }
}
