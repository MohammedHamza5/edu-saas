import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Passing score configuration section for [LessonSetupSheet].
class LessonSetupPassingScoreSection extends StatelessWidget {
  final bool useCustomScore;
  final int defaultPassingScore;
  final TextEditingController customScoreController;
  final ValueChanged<bool> onToggleCustomScore;

  const LessonSetupPassingScoreSection({
    super.key,
    required this.useCustomScore,
    required this.defaultPassingScore,
    required this.customScoreController,
    required this.onToggleCustomScore,
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
              Icons.percent_rounded,
              size: 16,
              color: AppColors.success,
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              l10n.passingScoreLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Column(
          children: [
            RadioListTile<bool>(
              value: false,
              groupValue: useCustomScore,
              onChanged: (v) => onToggleCustomScore(false),
              title: Text(
                l10n.useCourseDefault(defaultPassingScore),
                style: const TextStyle(fontSize: 14),
              ),
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: AppColors.primary,
            ),
            RadioListTile<bool>(
              value: true,
              groupValue: useCustomScore,
              onChanged: (v) => onToggleCustomScore(true),
              title: Row(
                children: [
                  Text(
                    l10n.customPassingScore,
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (useCustomScore) ...[
                    const SizedBox(width: AppSpacing.s12),
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        controller: customScoreController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          suffixText: '%',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ],
    );
  }
}
