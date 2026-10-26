import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/assignment_entity.dart';

extension SubmissionStatusUiExtension on SubmissionStatus {
  Color get color {
    switch (this) {
      case SubmissionStatus.submitted:
        return AppColors.warning;
      case SubmissionStatus.reviewed:
        return AppColors.success;
      case SubmissionStatus.late:
        return AppColors.error;
    }
  }

  IconData get icon {
    switch (this) {
      case SubmissionStatus.submitted:
        return Icons.pending_actions_rounded;
      case SubmissionStatus.reviewed:
        return Icons.check_circle_rounded;
      case SubmissionStatus.late:
        return Icons.running_with_errors_rounded;
    }
  }

  String localizedLabel(BuildContext context) {
    switch (this) {
      case SubmissionStatus.submitted:
        return context.l10n.submissionStatusSubmitted;
      case SubmissionStatus.reviewed:
        return context.l10n.submissionStatusReviewed;
      case SubmissionStatus.late:
        return context.l10n.submissionStatusLate;
    }
  }
}
