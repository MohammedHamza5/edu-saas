import '../../domain/entities/assignment_entity.dart';
import 'assignment_submission_model.dart';

class AssignmentModel extends AssignmentEntity {
  const AssignmentModel({
    required super.id,
    required super.contentId,
    required super.tenantId,
    required super.groupId,
    super.groupName,
    required super.title,
    super.instructions,
    super.dueAt,
    super.allowLateSubmission,
    super.maxScore,
    required super.createdAt,
    required super.updatedAt,
    super.submissionsCount,
    super.reviewedCount,
    super.mySubmission,
  });

  factory AssignmentModel.fromJson(Map<String, dynamic> json) {
    // Extract title, group_id, and group name from joined content record if available
    String title = json['title'] as String? ?? '';
    String groupId = json['group_id'] as String? ?? '';
    String? groupName;

    if (json['content'] is Map<String, dynamic>) {
      final contentMap = json['content'] as Map<String, dynamic>;
      title = contentMap['title'] as String? ?? title;
      groupId = contentMap['group_id'] as String? ?? groupId;

      if (contentMap['groups'] is Map<String, dynamic>) {
        final groupsMap = contentMap['groups'] as Map<String, dynamic>;
        groupName = groupsMap['name'] as String?;
      }
    }

    if (json['group_name'] != null) {
      groupName = json['group_name'] as String?;
    }

    // Submissions counts (can be aggregated or passed via RPC/view)
    int submissionsCount = 0;
    int reviewedCount = 0;
    if (json['submissions_count'] != null) {
      submissionsCount = (json['submissions_count'] as num).toInt();
    }
    if (json['reviewed_count'] != null) {
      reviewedCount = (json['reviewed_count'] as num).toInt();
    }

    // Parse my_submission if present
    AssignmentSubmissionModel? mySubmission;
    if (json['my_submission'] is Map<String, dynamic>) {
      mySubmission = AssignmentSubmissionModel.fromJson(
        json['my_submission'] as Map<String, dynamic>,
      );
    } else if (json['assignment_submissions'] is List && (json['assignment_submissions'] as List).isNotEmpty) {
      final first = (json['assignment_submissions'] as List).first;
      if (first is Map<String, dynamic>) {
        mySubmission = AssignmentSubmissionModel.fromJson(first);
      }
    }

    return AssignmentModel(
      id: json['id'] as String,
      contentId: json['content_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      groupId: groupId,
      groupName: groupName,
      title: title.isNotEmpty ? title : 'واجب بدون عنوان',
      instructions: json['instructions'] as String?,
      dueAt: json['due_at'] != null ? DateTime.parse(json['due_at'] as String) : null,
      allowLateSubmission: json['allow_late_submission'] as bool? ?? false,
      maxScore: (json['max_score'] as num?)?.toInt() ?? 100,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      submissionsCount: submissionsCount,
      reviewedCount: reviewedCount,
      mySubmission: mySubmission,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content_id': contentId,
      'tenant_id': tenantId,
      'instructions': instructions,
      if (dueAt != null) 'due_at': dueAt!.toIso8601String(),
      'allow_late_submission': allowLateSubmission,
      'max_score': maxScore,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
