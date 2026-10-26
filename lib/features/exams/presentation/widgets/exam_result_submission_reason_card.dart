import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/exam_entity.dart';
import '../extensions/exam_ui_extensions.dart';

class ExamResultSubmissionReasonCard extends StatelessWidget {
  final ExamAttemptEntity attempt;

  const ExamResultSubmissionReasonCard({
    super.key,
    required this.attempt,
  });

  String _getSubmissionExplanation(
    BuildContext context,
    ExamSubmissionReason reason,
  ) {
    switch (reason) {
      case ExamSubmissionReason.studentSubmitted:
        return context.l10n.submissionExplanationStudent;
      case ExamSubmissionReason.timeExpired:
        return context.l10n.submissionExplanationTimeout;
      case ExamSubmissionReason.forcedExit:
        return context.l10n.submissionExplanationForcedExit;
      case ExamSubmissionReason.securityViolations:
        return context.l10n.submissionExplanationViolations;
      case ExamSubmissionReason.tabClosed:
        return context.l10n.submissionExplanationTabClosed;
      case ExamSubmissionReason.systemTimeout:
        return context.l10n.submissionExplanationSystem;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd - hh:mm a');

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s8),
                decoration: BoxDecoration(
                  color: attempt.submissionReason.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  attempt.submissionReason.icon,
                  color: attempt.submissionReason.color,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.submissionReasonLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      attempt.submissionReason.localizedLabel(context),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: attempt.submissionReason.color,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: AppSpacing.s4,
                ),
                decoration: BoxDecoration(
                  color: attempt.status.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: Text(
                  attempt.status.localizedLabel(context),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: attempt.status.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),
          Text(
            _getSubmissionExplanation(
              context,
              attempt.submissionReason,
            ),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const Divider(
            height: AppSpacing.s20,
            color: AppColors.border,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.examSubmissionDateTitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                attempt.submittedAt != null
                    ? dateFormat.format(attempt.submittedAt!)
                    : context.l10n.justNow,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
