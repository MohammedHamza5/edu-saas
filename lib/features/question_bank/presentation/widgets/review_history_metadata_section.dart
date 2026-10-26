import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../cubit/question_bank_cubit.dart';
import '../cubit/question_bank_state.dart';

/// Horizontal revision history strip allowing users to review and restore previous revisions.
class ReviewHistoryMetadataSection extends StatelessWidget {
  final QuestionBankReviewLoaded state;

  const ReviewHistoryMetadataSection({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    if (state.revisionHistory.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 70,
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(30),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      child: Row(
        children: [
          Text(
            l10n.revisionHistoryTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: state.revisionHistory.length,
              itemBuilder: (context, index) {
                final rev = state.revisionHistory[index];
                final isCurrent = rev.id == state.revision?.id;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: CircleAvatar(
                      radius: 8,
                      backgroundColor: isCurrent
                          ? AppColors.primary
                          : Colors.grey,
                      child: Text(
                        '${rev.revNo}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    label: Text(
                      'v${rev.revNo} ${rev.createdVia ?? ''}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    onPressed: isCurrent
                        ? null
                        : () => context
                              .read<QuestionBankCubit>()
                              .restoreRevision(rev.id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
