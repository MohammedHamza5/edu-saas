import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';

/// Supported notification types strictly matching the whitelist in DB:
/// check (type in ('new_content','assignment_created','assignment_due','assignment_reviewed',
///                'exam_published','exam_result','attendance_marked','important_announcement'))
enum NotificationType {
  newContent,
  assignmentCreated,
  assignmentDue,
  assignmentReviewed,
  examPublished,
  examResult,
  attendanceMarked,
  importantAnnouncement;

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

  String get labelAr => switch (this) {
    NotificationType.newContent => 'محتوى جديد',
    NotificationType.assignmentCreated => 'واجب جديد',
    NotificationType.assignmentDue => 'تذكير بموعد واجب',
    NotificationType.assignmentReviewed => 'تقييم واجب',
    NotificationType.examPublished => 'امتحان جديد',
    NotificationType.examResult => 'نتيجة امتحان',
    NotificationType.attendanceMarked => 'رصد حضور',
    NotificationType.importantAnnouncement => 'إعلان مهم',
  };

  String get dbValue => switch (this) {
    NotificationType.newContent => 'new_content',
    NotificationType.assignmentCreated => 'assignment_created',
    NotificationType.assignmentDue => 'assignment_due',
    NotificationType.assignmentReviewed => 'assignment_reviewed',
    NotificationType.examPublished => 'exam_published',
    NotificationType.examResult => 'exam_result',
    NotificationType.attendanceMarked => 'attendance_marked',
    NotificationType.importantAnnouncement => 'important_announcement',
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

  static NotificationType fromString(String? value) {
    return switch (value) {
      'new_content' => NotificationType.newContent,
      'assignment_created' => NotificationType.assignmentCreated,
      'assignment_due' => NotificationType.assignmentDue,
      'assignment_reviewed' => NotificationType.assignmentReviewed,
      'exam_published' => NotificationType.examPublished,
      'exam_result' => NotificationType.examResult,
      'attendance_marked' => NotificationType.attendanceMarked,
      'important_announcement' => NotificationType.importantAnnouncement,
      _ => NotificationType.importantAnnouncement,
    };
  }
}

/// Core domain entity for an in-app notification item received by a user
class NotificationEntity extends Equatable {
  final String id; // notification_id
  final String recipientId; // notification_recipients.id
  final String tenantId;
  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  const NotificationEntity({
    required this.id,
    required this.recipientId,
    required this.tenantId,
    required this.title,
    required this.body,
    required this.type,
    this.data = const {},
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  NotificationEntity copyWith({
    String? id,
    String? recipientId,
    String? tenantId,
    String? title,
    String? body,
    NotificationType? type,
    Map<String, dynamic>? data,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return NotificationEntity(
      id: id ?? this.id,
      recipientId: recipientId ?? this.recipientId,
      tenantId: tenantId ?? this.tenantId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    recipientId,
    tenantId,
    title,
    body,
    type,
    data,
    readAt,
    createdAt,
  ];
}
