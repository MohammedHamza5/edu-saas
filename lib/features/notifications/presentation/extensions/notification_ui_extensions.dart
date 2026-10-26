import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/notification_entity.dart';

extension NotificationTypeUiExtension on NotificationType {
  String localizedLabel(BuildContext context) => switch (this) {
    NotificationType.newContent => context.l10n.notificationTypeNewContent,
    NotificationType.assignmentCreated => context.l10n.notificationTypeAssignmentCreated,
    NotificationType.assignmentDue => context.l10n.notificationTypeAssignmentDue,
    NotificationType.assignmentReviewed => context.l10n.notificationTypeAssignmentReviewed,
    NotificationType.examPublished => context.l10n.notificationTypeExamPublished,
    NotificationType.examResult => context.l10n.notificationTypeExamResult,
    NotificationType.attendanceMarked => context.l10n.notificationTypeAttendanceMarked,
    NotificationType.importantAnnouncement => context.l10n.notificationTypeImportantAnnouncement,
  };

  IconData get icon => switch (this) {
    NotificationType.newContent => Icons.video_library_rounded,
    NotificationType.assignmentCreated => Icons.assignment_rounded,
    NotificationType.assignmentDue => Icons.alarm_rounded,
    NotificationType.assignmentReviewed => Icons.rate_review_rounded,
    NotificationType.examPublished => Icons.quiz_rounded,
    NotificationType.examResult => Icons.emoji_events_rounded,
    NotificationType.attendanceMarked => Icons.fact_check_rounded,
    NotificationType.importantAnnouncement => Icons.campaign_rounded,
  };

  Color get color => switch (this) {
    NotificationType.newContent => AppColors.primary,
    NotificationType.assignmentCreated => AppColors.info,
    NotificationType.assignmentDue => AppColors.warning,
    NotificationType.assignmentReviewed => AppColors.success,
    NotificationType.examPublished => AppColors.primaryLight,
    NotificationType.examResult => AppColors.success,
    NotificationType.attendanceMarked => AppColors.primary,
    NotificationType.importantAnnouncement => AppColors.error,
  };
}
