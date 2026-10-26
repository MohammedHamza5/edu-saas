import 'package:flutter/material.dart';
import 'package:edu_saas/core/extensions/localized_context_extension.dart';
import 'package:edu_saas/core/theme/app_colors.dart';
import 'package:edu_saas/core/theme/app_spacing.dart';
import 'package:edu_saas/core/widgets/app_button.dart';
import 'package:edu_saas/features/exams/presentation/cubit/anki_drill_state.dart';

class AnkiCompletedView extends StatelessWidget {
  final AnkiDrillCompleted state;
  final VoidCallback onFinish;

  const AnkiCompletedView({
    super.key,
    required this.state,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.stars_rounded, color: AppColors.success, size: 72),
            const SizedBox(height: AppSpacing.s16),
            Text(
              context.l10n.ankiDrillCompletedTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              context.l10n.ankiDrillCompletedDesc,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatPill(context.l10n.drillTotalReviewed, '${state.totalReviewed}', AppColors.primary),
                _buildStatPill(context.l10n.drillMasteredCount, '${state.masteredCount}', AppColors.success),
                _buildStatPill(context.l10n.drillHardRepeated, '${state.repeatedCount}', AppColors.error),
              ],
            ),
            const SizedBox(height: AppSpacing.s32),
            AppButton(
              text: context.l10n.finishDrill,
              onPressed: onFinish,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
