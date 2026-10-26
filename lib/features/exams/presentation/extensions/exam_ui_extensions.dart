import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/exam_entity.dart';

extension QuestionTypeUiExtension on QuestionType {
  String localizedLabel(BuildContext context) {
    switch (this) {
      case QuestionType.multipleChoice:
        return context.l10n.questionTypeMultipleChoice;
      case QuestionType.trueFalse:
        return context.l10n.questionTypeTrueFalse;
    }
  }
}

extension ExamStatusUiExtension on ExamStatus {
  String localizedLabel(BuildContext context) {
    switch (this) {
      case ExamStatus.draft:
        return context.l10n.examStatusDraft;
      case ExamStatus.published:
        return context.l10n.examStatusPublished;
      case ExamStatus.archived:
        return context.l10n.statusArchived;
    }
  }

  Color get color {
    switch (this) {
      case ExamStatus.draft:
        return AppColors.warning;
      case ExamStatus.published:
        return AppColors.success;
      case ExamStatus.archived:
        return AppColors.textMuted;
    }
  }
}

extension AttemptStatusUiExtension on AttemptStatus {
  String localizedLabel(BuildContext context) {
    switch (this) {
      case AttemptStatus.inProgress:
        return context.l10n.attemptStatusInProgress;
      case AttemptStatus.submitted:
        return context.l10n.attemptStatusSubmitted;
      case AttemptStatus.expired:
        return context.l10n.attemptStatusExpired;
    }
  }

  Color get color {
    switch (this) {
      case AttemptStatus.inProgress:
        return AppColors.primary;
      case AttemptStatus.submitted:
        return AppColors.success;
      case AttemptStatus.expired:
        return AppColors.error;
    }
  }
}

extension ExamSubmissionReasonUiExtension on ExamSubmissionReason {
  String localizedLabel(BuildContext context) {
    switch (this) {
      case ExamSubmissionReason.studentSubmitted:
        return context.l10n.submissionReasonStudentSubmitted;
      case ExamSubmissionReason.timeExpired:
        return context.l10n.submissionReasonTimeExpired;
      case ExamSubmissionReason.forcedExit:
        return context.l10n.submissionReasonForcedExit;
      case ExamSubmissionReason.securityViolations:
        return context.l10n.submissionReasonSecurityViolations;
      case ExamSubmissionReason.tabClosed:
        return context.l10n.submissionReasonTabClosed;
      case ExamSubmissionReason.systemTimeout:
        return context.l10n.submissionReasonSystemTimeout;
    }
  }

  Color get color {
    switch (this) {
      case ExamSubmissionReason.studentSubmitted:
        return AppColors.success;
      case ExamSubmissionReason.timeExpired:
        return AppColors.warning;
      case ExamSubmissionReason.forcedExit:
        return AppColors.error;
      case ExamSubmissionReason.securityViolations:
        return const Color(0xFFB91C1C);
      case ExamSubmissionReason.tabClosed:
        return const Color(0xFF7C3AED);
      case ExamSubmissionReason.systemTimeout:
        return AppColors.textMuted;
    }
  }

  IconData get icon {
    switch (this) {
      case ExamSubmissionReason.studentSubmitted:
        return Icons.check_circle_outline_rounded;
      case ExamSubmissionReason.timeExpired:
        return Icons.timer_off_outlined;
      case ExamSubmissionReason.forcedExit:
        return Icons.exit_to_app_rounded;
      case ExamSubmissionReason.securityViolations:
        return Icons.shield_outlined;
      case ExamSubmissionReason.tabClosed:
        return Icons.tab_unselected_rounded;
      case ExamSubmissionReason.systemTimeout:
        return Icons.hourglass_disabled_rounded;
    }
  }
}
