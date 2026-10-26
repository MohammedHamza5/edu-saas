import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/mistake_entities.dart';
import '../cubit/mistakes_cubit.dart';
import '../cubit/mistakes_state.dart';

/// Hero Banner for Student Exams page displaying Mistakes Bank analytics and quick practice CTA.
class StudentMistakesBankBanner extends StatelessWidget {
  const StudentMistakesBankBanner({super.key});

  @override
  Widget build(BuildContext context) {
    MistakesCubit? mistakesCubit;
    try {
      mistakesCubit = context.read<MistakesCubit>();
    } catch (_) {}

    if (mistakesCubit == null) {
      return const SizedBox.shrink();
    }

    return BlocBuilder<MistakesCubit, MistakesState>(
      bloc: mistakesCubit,
      buildWhen: (prev, curr) {
        if (prev.runtimeType != curr.runtimeType) return true;
        if (prev is MistakesLoaded && curr is MistakesLoaded) {
          return prev.summary != curr.summary;
        }
        return true;
      },
      builder: (context, mistakesState) {
        MistakeSummaryEntity? summary;
        final bool isLoading = mistakesState is MistakesLoading;

        if (mistakesState is MistakesLoaded) {
          summary = mistakesState.summary;
        }

        final unresolvedCount = summary?.unresolvedCount ?? 0;
        final resolvedCount = summary?.resolvedCount ?? 0;
        final totalCount = summary?.totalMistakes ?? 0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.s20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.25),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMedium,
                        ),
                      ),
                      child: Icon(
                        Icons.auto_stories_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                context.l10n.mistakesBankTitle,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                              if (unresolvedCount > 0) ...[
                                const SizedBox(width: AppSpacing.s8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.s8,
                                    vertical: AppSpacing.s4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusSmall,
                                    ),
                                  ),
                                  child: Text(
                                    '$unresolvedCount',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s4),
                          Text(
                            isLoading
                                ? context.l10n.mistakesBankSubtitle
                                : (unresolvedCount > 0
                                    ? context.l10n.questionsNeedingReviewCount(
                                        unresolvedCount,
                                      )
                                    : (totalCount > 0
                                        ? context.l10n.allMistakesMastered
                                        : context.l10n.noMistakesRecordedYet)),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (summary != null && totalCount > 0) ...[
                  const SizedBox(height: AppSpacing.s16),
                  Wrap(
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s8,
                    children: [
                      _buildMistakeStatChip(
                        icon: Icons.error_outline_rounded,
                        label:
                            '$unresolvedCount ${context.l10n.unresolvedMistakesCount}',
                        color: unresolvedCount > 0
                            ? AppColors.error
                            : AppColors.success,
                      ),
                      _buildMistakeStatChip(
                        icon: Icons.check_circle_outline_rounded,
                        label:
                            '$resolvedCount ${context.l10n.resolvedMistakesCount}',
                        color: AppColors.success,
                      ),
                      _buildMistakeStatChip(
                        icon: Icons.analytics_outlined,
                        label: '$totalCount ${context.l10n.totalMistakesCount}',
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.s16),
                Wrap(
                  spacing: AppSpacing.s12,
                  runSpacing: AppSpacing.s8,
                  children: [
                    if (unresolvedCount > 0)
                      ElevatedButton.icon(
                        onPressed: () =>
                            context.push(AppRoutes.mistakesPractice),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(
                          context.l10n.startPracticeCount(unresolvedCount),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s16,
                            vertical: AppSpacing.s10,
                          ),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => context.go(AppRoutes.studentMistakes),
                      icon: const Icon(Icons.auto_stories_outlined, size: 18),
                      label: Text(
                        unresolvedCount > 0
                            ? context.l10n.reviewMistakesBankBtn
                            : context.l10n.mistakesBankBannerAction,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s16,
                          vertical: AppSpacing.s10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMistakeStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s10,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.s6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
