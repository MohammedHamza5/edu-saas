import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/exam_entity.dart';

/// Interactive dual-card selector for classifying an exam as [ExamCategory.realTest]
/// or [ExamCategory.questionBank].
class ExamCategorySelector extends StatelessWidget {
  final ExamCategory selectedCategory;
  final ValueChanged<ExamCategory> onCategoryChanged;
  final bool enabled;

  const ExamCategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.category_outlined,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              l10n.examCategorySelectLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 540;

            final realTestCard = _CategoryCard(
              title: l10n.examCategoryRealTestFull,
              description: l10n.examCategoryRealTestDesc,
              icon: Icons.timer_outlined,
              isSelected: selectedCategory.isRealTest,
              accentColor: const Color(0xFF7C3AED), // Indigo / Purple
              onTap: enabled
                  ? () {
                      HapticFeedback.selectionClick();
                      onCategoryChanged(ExamCategory.realTest);
                    }
                  : null,
            );

            final questionBankCard = _CategoryCard(
              title: l10n.examCategoryQuestionBankFull,
              description: l10n.examCategoryQuestionBankDesc,
              icon: Icons.auto_stories_rounded,
              isSelected: selectedCategory.isQuestionBank,
              accentColor: const Color(0xFF059669), // Emerald
              onTap: enabled
                  ? () {
                      HapticFeedback.selectionClick();
                      onCategoryChanged(ExamCategory.questionBank);
                    }
                  : null,
            );

            if (isCompact) {
              return Column(
                children: [
                  realTestCard,
                  const SizedBox(height: AppSpacing.s12),
                  questionBankCard,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: realTestCard),
                const SizedBox(width: AppSpacing.s16),
                Expanded(child: questionBankCard),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback? onTap;

  const _CategoryCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected
            ? accentColor.withValues(alpha: 0.08)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(
          color: isSelected ? accentColor : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor.withValues(alpha: 0.18)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: isSelected ? accentColor : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? accentColor
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? accentColor
                                    : AppColors.border,
                                width: isSelected ? 6 : 2,
                              ),
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
