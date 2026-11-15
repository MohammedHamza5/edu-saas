import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../domain/entities/exam_entity.dart';

/// Top header and mode switcher for students to toggle between [ExamCategory.realTest]
/// and [ExamCategory.questionBank] with real-time counters and inspiring hero banner.
class StudentExamCategoryHeader extends StatelessWidget {
  final ExamCategory activeCategory;
  final ValueChanged<ExamCategory> onCategoryChanged;
  final int realTestsCount;
  final int questionBankCount;

  const StudentExamCategoryHeader({
    super.key,
    required this.activeCategory,
    required this.onCategoryChanged,
    required this.realTestsCount,
    required this.questionBankCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isRealTest = activeCategory.isRealTest;

    final primaryTheme = isRealTest
        ? const Color(0xFF7C3AED) // Indigo / Violet
        : const Color(0xFF059669); // Emerald

    final heroTitle = isRealTest
        ? l10n.realTestsHeroTitle
        : l10n.questionBankHeroTitle;

    final heroSubtitle = isRealTest
        ? l10n.realTestsHeroSubtitle
        : l10n.questionBankHeroSubtitle;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Segmented Mode Switcher Bar
          Container(
            padding: const EdgeInsets.all(AppSpacing.s4),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ModeTab(
                    title: l10n.studentNavRealTests,
                    count: realTestsCount,
                    icon: Icons.timer_outlined,
                    isSelected: isRealTest,
                    selectedColor: const Color(0xFF7C3AED),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onCategoryChanged(ExamCategory.realTest);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.s4),
                Expanded(
                  child: _ModeTab(
                    title: l10n.studentNavQuestionBank,
                    count: questionBankCount,
                    icon: Icons.auto_stories_rounded,
                    isSelected: !isRealTest,
                    selectedColor: const Color(0xFF059669),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onCategoryChanged(ExamCategory.questionBank);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s12),

          // 2. Animated Category Hero Card
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryTheme.withValues(alpha: 0.10),
                  primaryTheme.withValues(alpha: 0.03),
                ],
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(
                color: primaryTheme.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s10),
                  decoration: BoxDecoration(
                    color: primaryTheme.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  ),
                  child: Icon(
                    isRealTest
                        ? Icons.psychology_outlined
                        : Icons.menu_book_rounded,
                    color: primaryTheme,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        heroTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primaryTheme,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        heroSubtitle,
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
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _ModeTab({
    required this.title,
    required this.count,
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.s10,
            horizontal: AppSpacing.s8,
          ),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? selectedColor : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.s6),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? selectedColor : AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.s6),
              AppBadge(
                label: '$count',
                variant: AppBadgeVariant.neutral,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
