import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class QuestionBankStatsDeck extends StatelessWidget {
  final int totalDocs;
  final int totalQuestions;
  final int done;
  final int failed;
  final int pending;

  const QuestionBankStatsDeck({
    super.key,
    required this.totalDocs,
    required this.totalQuestions,
    required this.done,
    required this.failed,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        final items = [
          _StatDeckItem(
            label: l10n.statTotalDocuments,
            value: totalDocs,
            icon: Icons.description_outlined,
            color: AppColors.primary,
          ),
          _StatDeckItem(
            label: l10n.statTotalQuestions,
            value: totalQuestions,
            icon: Icons.quiz_outlined,
            color: AppColors.textPrimary,
          ),
          _StatDeckItem(
            label: l10n.statDocumentsDone,
            value: done,
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.success,
          ),
          _StatDeckItem(
            label: l10n.statDocumentsPending,
            value: pending,
            icon: Icons.hourglass_top_rounded,
            color: AppColors.warning,
          ),
          _StatDeckItem(
            label: l10n.statDocumentsFailed,
            value: failed,
            icon: Icons.error_outline_rounded,
            color: AppColors.error,
          ),
        ];

        if (isNarrow) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AppSpacing.s8,
                      ),
                      child: SizedBox(width: 155, child: item),
                    ),
                  )
                  .toList(),
            ),
          );
        }

        return Row(
          children: items
              .map(
                (item) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: item,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _StatDeckItem extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _StatDeckItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$value',
                  style: AppTypography.statFigureSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
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
