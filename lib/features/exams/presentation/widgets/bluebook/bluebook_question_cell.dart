import 'package:flutter/material.dart';
import 'package:edu_saas/core/theme/app_colors.dart';
import 'package:edu_saas/core/theme/app_spacing.dart';

class BluebookQuestionCell extends StatelessWidget {
  final int index;
  final bool isCurrent;
  final bool isAnswered;
  final bool isFlagged;
  final VoidCallback onTap;

  const BluebookQuestionCell({
    super.key,
    required this.index,
    required this.isCurrent,
    required this.isAnswered,
    required this.isFlagged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isAnswered ? AppColors.success.withValues(alpha: 0.15) : AppColors.surface;
    final border = isCurrent ? AppColors.primary : (isAnswered ? AppColors.success : AppColors.border);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: isCurrent ? 2.5 : 1.2),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${index + 1}',
              style: TextStyle(
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                color: isCurrent ? AppColors.primary : AppColors.textPrimary,
                fontSize: 15,
              ),
            ),
            if (isFlagged)
              const Positioned(
                top: 2,
                right: 2,
                child: Icon(Icons.flag_rounded, size: 12, color: AppColors.warning),
              ),
          ],
        ),
      ),
    );
  }
}
