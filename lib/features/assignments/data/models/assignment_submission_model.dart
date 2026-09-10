import '../../domain/entities/assignment_entity.dart';
import 'submission_file_model.dart';

class AssignmentSubmissionModel extends AssignmentSubmissionEntity {
  const AssignmentSubmissionModel({
    required super.id,
    required super.assignmentId,
    required super.studentId,
    required super.studentName,
    super.studentEmail,
    super.attemptNumber,
    required super.submittedAt,
    super.status,
    super.score,
    super.teacherFeedback,
    super.reviewedAt,
    super.reviewedBy,
    super.files,
  });

  factory AssignmentSubmissionModel.fromJson(Map<String, dynamic> json) {
    // Extract student name/email from joined users record if available
    String studentName = 'طالب';
    String? studentEmail;

    if (json['users'] is Map<String, dynamic>) {
      final userMap = json['users'] as Map<String, dynamic>;
      studentName = userMap['full_name'] as String? ?? 'طالب';
      studentEmail = userMap['email'] as String?;
    } else if (json['student_name'] != null) {
      studentName = json['student_name'] as String;
      studentEmail = json['student_email'] as String?;
    }

    final filesList = (json['submission_files'] as List<dynamic>?)
            ?.map((f) => SubmissionFileModel.fromJson(f as Map<String, dynamic>))
            .toList() ??
        <SubmissionFileModel>[];

    return AssignmentSubmissionModel(
      id: json['id'] as String,
      assignmentId: json['assignment_id'] as String,
      studentId: json['student_id'] as String,
      studentName: studentName,
      studentEmail: studentEmail,
      attemptNumber: (json['attempt_number'] as num?)?.toInt() ?? 1,
      submittedAt: DateTime.parse(json['submitted_at'] as String),
      status: SubmissionStatus.fromString(json['status'] as String? ?? 'submitted'),
      score: (json['score'] as num?)?.toInt(),
      teacherFeedback: json['teacher_feedback'] as String?,
      reviewedAt: json['reviewed_at'] != null ? DateTime.parse(json['reviewed_at'] as String) : null,
      reviewedBy: json['reviewed_by'] as String?,
      files: filesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assignment_id': assignmentId,
      'student_id': studentId,
      'attempt_number': attemptNumber,
      'submitted_at': submittedAt.toIso8601String(),
      'status': status.value,
      if (score != null) 'score': score,
      if (teacherFeedback != null) 'teacher_feedback': teacherFeedback,
      if (reviewedAt != null) 'reviewed_at': reviewedAt!.toIso8601String(),
      if (reviewedBy != null) 'reviewed_by': reviewedBy,
    };
  }
}
