import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:edu_saas/core/extensions/localized_context_extension.dart';
import 'package:edu_saas/core/theme/app_colors.dart';
import 'package:edu_saas/core/theme/app_spacing.dart';
import 'package:edu_saas/core/widgets/app_button.dart';
import 'package:edu_saas/core/widgets/app_card.dart';
import 'package:edu_saas/core/widgets/app_empty_view.dart';
import 'package:edu_saas/features/exams/presentation/cubit/anki_drill_cubit.dart';
import 'package:edu_saas/features/exams/presentation/cubit/anki_drill_state.dart';
import 'package:edu_saas/features/exams/presentation/widgets/vault/anki_completed_view.dart';
import 'package:edu_saas/features/exams/presentation/widgets/vault/anki_difficulty_selector.dart';

class AnkiDrillPage extends StatelessWidget {
  const AnkiDrillPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.ankiDrillTitle),
      ),
      body: BlocBuilder<AnkiDrillCubit, AnkiDrillState>(
        builder: (context, state) {
          if (state is AnkiDrillEmpty) {
            return AppEmptyView(
              message: context.l10n.emptyVaultTitle,
              subtitle: context.l10n.emptyVaultSubtitle,
            );
          }
          if (state is AnkiDrillCompleted) {
            return AnkiCompletedView(
              state: state,
              onFinish: () => Navigator.of(context).pop(),
            );
          }
          if (state is AnkiDrillActive) {
            return _buildActiveDrillView(context, state);
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildActiveDrillView(BuildContext context, AnkiDrillActive state) {
    final q = state.currentQuestion;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.questionProgress(state.currentIndex, state.totalQuestions),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              if (state.queueLength > 1)
                Text(
                  '${state.queueLength} ${context.l10n.questions}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          LinearProgressIndicator(
            value: state.totalQuestions > 0 ? (state.currentIndex / state.totalQuestions).clamp(0.0, 1.0) : 0,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.s16),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q.questionText,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
                ),
                const SizedBox(height: AppSpacing.s16),
                ...q.options.map((opt) {
                  final isSelected = state.selectedOptionId == opt.id;
                  final isRevealed = state.isRevealed;
                  Color? tileColor;
                  if (isRevealed) {
                    if (opt.isCorrect == true) {
                      tileColor = AppColors.success.withValues(alpha: 0.15);
                    } else if (isSelected) {
                      tileColor = AppColors.error.withValues(alpha: 0.15);
                    }
                  } else if (isSelected) {
                    tileColor = AppColors.primary.withValues(alpha: 0.1);
                  }

                  final letter = String.fromCharCode(65 + (opt.sortOrder < 26 ? opt.sortOrder : 0));

                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: tileColor,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: ListTile(
                      onTap: isRevealed ? null : () => context.read<AnkiDrillCubit>().selectOption(opt.id),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: isSelected ? AppColors.primary : AppColors.surface,
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      title: Text(opt.optionText, style: const TextStyle(fontSize: 14)),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          if (!state.isRevealed)
            AppButton(
              text: context.l10n.checkAnswer,
              onPressed: state.selectedOptionId != null
                  ? () => context.read<AnkiDrillCubit>().checkAnswer()
                  : null,
            )
          else ...[
            _buildFeedbackBanner(context, state.isCorrect),
            const SizedBox(height: AppSpacing.s16),
            AnkiDifficultySelector(
              onRatingSelected: (rating) {
                context.read<AnkiDrillCubit>().rateDifficultyAndAdvance(rating);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeedbackBanner(BuildContext context, bool isCorrect) {
    final color = isCorrect ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              isCorrect ? context.l10n.correctAnswer : context.l10n.wrongAnswerBadge,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
