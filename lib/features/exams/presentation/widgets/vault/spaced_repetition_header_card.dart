import 'package:flutter/material.dart';
import 'package:edu_saas/core/extensions/localized_context_extension.dart';
import 'package:edu_saas/core/theme/app_colors.dart';
import 'package:edu_saas/core/theme/app_spacing.dart';
import 'package:edu_saas/core/widgets/app_button.dart';
import 'package:edu_saas/core/widgets/app_card.dart';
import '../../cubit/saved_questions_state.dart';

class SpacedRepetitionHeaderCard extends StatelessWidget {
  final SavedQuestionsLoaded state;
  final VoidCallback onStartDueReview;
  final VoidCallback onPracticeAll;

  const SpacedRepetitionHeaderCard({
    super.key,
    required this.state,
    required this.onStartDueReview,
    required this.onPracticeAll,
  });

  @override
  Widget build(BuildContext context) {
    final hasDue = state.dueTodayCount > 0;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
                child: const Icon(Icons.psychology_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.leitnerScheduleTitle,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasDue
                          ? context.l10n.startDuePracticeAction(state.dueTodayCount)
                          : context.l10n.noDueTodayTitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: hasDue ? AppColors.warning : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s14),

          // Leitner Boxes Bar
          Row(
            children: [
              Expanded(
                child: _BoxMetricTile(
                  label: context.l10n.leitnerBox1Title,
                  count: state.box1Count,
                  color: AppColors.error,
                  icon: Icons.repeat_one_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: _BoxMetricTile(
                  label: context.l10n.leitnerBox2Title,
                  count: state.box2Count,
                  color: AppColors.warning,
                  icon: Icons.update_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: _BoxMetricTile(
                  label: context.l10n.leitnerBox3Title,
                  count: state.box3Count,
                  color: AppColors.success,
                  icon: Icons.done_all_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s14),

          // Action Button or All-Caught-Up banner
          if (hasDue)
            AppButton(
              text: context.l10n.startDuePracticeAction(state.dueTodayCount),
              icon: Icons.bolt_rounded,
              onPressed: onStartDueReview,
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s10),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      context.l10n.noDueTodaySubtitle,
                      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BoxMetricTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _BoxMetricTile({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8, horizontal: AppSpacing.s6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                count.toString(),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
