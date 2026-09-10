import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

enum SubmissionStatus {
  submitted,
  reviewed,
  late;

  static SubmissionStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'reviewed':
        return SubmissionStatus.reviewed;
      case 'late':
        return SubmissionStatus.late;
      case 'submitted':
      default:
        return SubmissionStatus.submitted;
    }
  }

  String get value => name;

  String get labelAr {
    switch (this) {
      case SubmissionStatus.submitted:
        return 'بانتظار التصحيح';
      case SubmissionStatus.reviewed:
        return 'تم التصحيح والتقييم';
      case SubmissionStatus.late:
        return 'تسليم متأخر';
    }
  }

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
}

class SubmissionFileEntity extends Equatable {
  final String id;
  final String submissionId;
  final String storagePath;
  final String fileName;
  final String mimeType;
  final int fileSize;
  final String? signedUrl;
  final DateTime createdAt;

  const SubmissionFileEntity({
    required this.id,
    required this.submissionId,
    required this.storagePath,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    this.signedUrl,
    required this.createdAt,
  });

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool get isPdf => mimeType.contains('pdf') || fileName.toLowerCase().endsWith('.pdf');
  bool get isImage => mimeType.startsWith('image/');

  @override
  List<Object?> get props => [
        id,
        submissionId,
        storagePath,
        fileName,
        mimeType,
        fileSize,
        signedUrl,
        createdAt,
      ];
}

class AssignmentSubmissionEntity extends Equatable {
  final String id;
  final String assignmentId;
  final String studentId;
  final String studentName;
  final String? studentEmail;
  final int attemptNumber;
  final DateTime submittedAt;
  final SubmissionStatus status;
  final int? score;
  final String? teacherFeedback;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final List<SubmissionFileEntity> files;

  const AssignmentSubmissionEntity({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.studentName,
    this.studentEmail,
    this.attemptNumber = 1,
    required this.submittedAt,
    this.status = SubmissionStatus.submitted,
    this.score,
    this.teacherFeedback,
    this.reviewedAt,
    this.reviewedBy,
    this.files = const [],
  });

  bool get isReviewed => status == SubmissionStatus.reviewed;
  bool get isLate => status == SubmissionStatus.late;
  bool get isSubmitted => status == SubmissionStatus.submitted;

  double? scorePercentage(int maxScore) {
    if (score == null || maxScore <= 0) return null;
    return (score! / maxScore) * 100;
  }

  AssignmentSubmissionEntity copyWith({
    String? id,
    String? assignmentId,
    String? studentId,
    String? studentName,
    String? studentEmail,
    int? attemptNumber,
    DateTime? submittedAt,
    SubmissionStatus? status,
    int? score,
    String? teacherFeedback,
    DateTime? reviewedAt,
    String? reviewedBy,
    List<SubmissionFileEntity>? files,
  }) {
    return AssignmentSubmissionEntity(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentEmail: studentEmail ?? this.studentEmail,
      attemptNumber: attemptNumber ?? this.attemptNumber,
      submittedAt: submittedAt ?? this.submittedAt,
      status: status ?? this.status,
      score: score ?? this.score,
      teacherFeedback: teacherFeedback ?? this.teacherFeedback,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      files: files ?? this.files,
    );
  }

  @override
  List<Object?> get props => [
        id,
        assignmentId,
        studentId,
        studentName,
        studentEmail,
        attemptNumber,
        submittedAt,
        status,
        score,
        teacherFeedback,
        reviewedAt,
        reviewedBy,
        files,
      ];
}

class AssignmentEntity extends Equatable {
  final String id;
  final String contentId;
  final String tenantId;
  final String groupId;
  final String? groupName;
  final String title;
  final String? instructions;
  final DateTime? dueAt;
  final bool allowLateSubmission;
  final int maxScore;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int submissionsCount;
  final int reviewedCount;
  final AssignmentSubmissionEntity? mySubmission;

  const AssignmentEntity({
    required this.id,
    required this.contentId,
    required this.tenantId,
    required this.groupId,
    this.groupName,
    required this.title,
    this.instructions,
    this.dueAt,
    this.allowLateSubmission = false,
    this.maxScore = 100,
    required this.createdAt,
    required this.updatedAt,
    this.submissionsCount = 0,
    this.reviewedCount = 0,
    this.mySubmission,
  });

  bool get isOverdue => dueAt != null && DateTime.now().isAfter(dueAt!);
  bool get hasSubmitted => mySubmission != null;
  bool get isReviewed => mySubmission?.isReviewed ?? false;

  AssignmentEntity copyWith({
    String? id,
    String? contentId,
    String? tenantId,
    String? groupId,
    String? groupName,
    String? title,
    String? instructions,
    DateTime? dueAt,
    bool? allowLateSubmission,
    int? maxScore,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? submissionsCount,
    int? reviewedCount,
    AssignmentSubmissionEntity? mySubmission,
  }) {
    return AssignmentEntity(
      id: id ?? this.id,
      contentId: contentId ?? this.contentId,
      tenantId: tenantId ?? this.tenantId,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      title: title ?? this.title,
      instructions: instructions ?? this.instructions,
      dueAt: dueAt ?? this.dueAt,
      allowLateSubmission: allowLateSubmission ?? this.allowLateSubmission,
      maxScore: maxScore ?? this.maxScore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      submissionsCount: submissionsCount ?? this.submissionsCount,
      reviewedCount: reviewedCount ?? this.reviewedCount,
      mySubmission: mySubmission ?? this.mySubmission,
    );
  }

  @override
  List<Object?> get props => [
        id,
        contentId,
        tenantId,
        groupId,
        groupName,
        title,
        instructions,
        dueAt,
        allowLateSubmission,
        maxScore,
        createdAt,
        updatedAt,
        submissionsCount,
        reviewedCount,
        mySubmission,
      ];
}
