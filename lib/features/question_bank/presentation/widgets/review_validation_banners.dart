import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../cubit/question_bank_state.dart';
import '../dialogs/review_console_dialogs.dart';

class ReviewValidationBanners extends StatelessWidget {
  final QuestionBankReviewLoaded state;

  const ReviewValidationBanners({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top Issues Banner
        if (state.issues.isNotEmpty)
          _buildIssuesBanner(context)
        else
          _buildCleanBanner(context),

        // Duplicate Cluster Notice (if detected)
        if (state.question.duplicateClusterId != null)
          _buildDuplicateClusterBanner(context),
      ],
    );
  }

  Widget _buildCleanBanner(BuildContext context) {
    final l10n = context.l10n;
    final rev = state.revision;
    final hasAnswer =
        rev != null && rev.answerKey != null && rev.answerKey!.isNotEmpty;
    final hasStem =
        rev != null &&
        (rev.stemText.trim().isNotEmpty || rev.stemBlocks.isNotEmpty);

    if (!hasAnswer || !hasStem) {
      return Container(
        width: double.infinity,
        color: AppColors.info.withAlpha(40),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s8,
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.info, size: 20),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                l10n.statusReviewRequired,
                style: const TextStyle(
                  color: AppColors.info,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      color: AppColors.successLight.withAlpha(50),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 20),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              l10n.noBlockersMessage,
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicateClusterBanner(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      color: AppColors.warningLight.withAlpha(60),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s6,
      ),
      child: Row(
        children: [
          const Icon(Icons.copy_outlined, color: AppColors.warning, size: 18),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              '${l10n.possibleDuplicateNotice} cluster [${state.question.duplicateClusterId}]',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssuesBanner(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;

    return Container(
      width: double.infinity,
      color: state.hasBlockers
          ? AppColors.errorLight.withAlpha(45)
          : AppColors.warningLight.withAlpha(45),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                state.hasBlockers ? Icons.block : Icons.warning_amber_rounded,
                color: state.hasBlockers ? AppColors.error : AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                l10n.validationBlockers,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: state.hasBlockers
                      ? AppColors.error
                      : AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Wrap(
            spacing: AppSpacing.s6,
            runSpacing: AppSpacing.s6,
            children: state.issues.map((issue) {
              final isAcked =
                  state.acknowledgedIssueIds.contains(issue.id) ||
                  issue.isResolved;
              final isBlocker = issue.isBlocker && !isAcked;

              return ActionChip(
                avatar: CircleAvatar(
                  backgroundColor: isAcked
                      ? AppColors.success
                      : (isBlocker ? AppColors.error : AppColors.warning),
                  radius: 10,
                  child: Icon(
                    isAcked ? Icons.check : Icons.priority_high,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
                label: Text(
                  '${issue.ruleId}: ${issue.getLocalizedMessage(locale)}',
                  style: TextStyle(
                    fontSize: 12,
                    decoration: isAcked ? TextDecoration.lineThrough : null,
                  ),
                ),
                onPressed: () =>
                    ReviewConsoleDialogs.showIssueAcknowledgmentDialog(
                  context,
                  issue,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
