import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../cubit/question_bank_cubit.dart';
import '../cubit/question_bank_state.dart';
import '../dialogs/review_console_dialogs.dart';

/// Bottom action bar for approving, publishing, merging, splitting,
/// or quarantining a question during review.
class ReviewActionBar extends StatelessWidget {
  final QuestionBankReviewLoaded state;

  const ReviewActionBar({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rev = state.revision;
    final isApproved = state.question.isApproved || state.question.isPublished;
    final isPublished = state.question.isPublished;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isStacked = constraints.maxWidth < 780;

          final structuralActions = Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              OutlinedButton.icon(
                onPressed: () => ReviewConsoleDialogs.confirmMerge(context),
                icon: const Icon(Icons.merge_type, size: 16),
                label: Text(l10n.mergeWithNextAction),
              ),
              const SizedBox(width: AppSpacing.s8),
              OutlinedButton.icon(
                onPressed: () => ReviewConsoleDialogs.confirmSplit(context),
                icon: const Icon(Icons.call_split, size: 16),
                label: Text(l10n.splitQuestionAction),
              ),
              const SizedBox(width: AppSpacing.s8),
              OutlinedButton.icon(
                onPressed: () =>
                    ReviewConsoleDialogs.confirmMarkUnreadable(context),
                icon: const Icon(Icons.visibility_off, size: 16),
                label: Text(l10n.markUnreadableAction),
              ),
            ],
          );

          final primaryActions = Wrap(
            spacing: AppSpacing.s12,
            runSpacing: AppSpacing.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (!isApproved) ...[
                AppButton(
                  text: l10n.approveRevision,
                  icon: Icons.thumb_up,
                  isLoading: state.isActionLoading,
                  onPressed: state.hasBlockers || rev == null
                      ? null
                      : () {
                          context.read<QuestionBankCubit>().approveRevision(
                                revisionId: rev.id,
                                contentHash: rev.contentHash,
                              );
                        },
                ),
              ],
              if (!isPublished) ...[
                AppButton(
                  text: l10n.publishToStudents,
                  icon: Icons.send,
                  isLoading: state.isActionLoading,
                  onPressed: !isApproved || state.hasBlockers || rev == null
                      ? null
                      : () {
                          context.read<QuestionBankCubit>().publishRevision(
                                revisionId: rev.id,
                              );
                        },
                ),
              ] else ...[
                Chip(
                  avatar: const Icon(
                    Icons.check,
                    color: AppColors.success,
                    size: 18,
                  ),
                  label: Text(
                    l10n.statusPublished,
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: AppColors.successLight,
                ),
              ],
            ],
          );

          if (isStacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                primaryActions,
                const SizedBox(height: AppSpacing.s12),
                structuralActions,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              structuralActions,
              primaryActions,
            ],
          );
        },
      ),
    );
  }
}
