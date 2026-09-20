import '../../domain/entities/content_entity.dart';
import 'file_attachment_model.dart';

class ContentModel extends ContentEntity {
  const ContentModel({
    required super.id,
    required super.tenantId,
    super.groupId,
    required super.title,
    super.description,
    required super.type,
    required super.status,
    super.sortOrder = 0,
    super.publishedAt,
    required super.createdAt,
    required super.updatedAt,
    super.file,
    super.videoId,
    super.videoStatus,
    super.videoProviderId,
    super.videoProvider,
    super.assignedGroupIds = const [],
    super.assignedGroupNames = const [],
    super.associatedExamId,
    super.associatedExamTitle,
    super.prerequisiteExamId,
    super.prerequisiteExamTitle,
    super.prerequisitePassingScore,
    super.isLocked = false,
    super.isVideoCompleted = false,
    super.videoProgressPercentage = 0.0,
    super.isExamPassed = false,
  });

  factory ContentModel.fromJson(Map<String, dynamic> json) {
    FileAttachmentModel? fileAttachment;
    if (json['files'] != null) {
      if (json['files'] is List && (json['files'] as List).isNotEmpty) {
        fileAttachment = FileAttachmentModel.fromJson(
          (json['files'] as List).first as Map<String, dynamic>,
        );
      } else if (json['files'] is Map<String, dynamic>) {
        fileAttachment = FileAttachmentModel.fromJson(
          json['files'] as Map<String, dynamic>,
        );
      }
    }

    // Parse video metadata from the left-joined `videos` table rows.
    String? videoId;
    String? videoStatus;
    String? videoProviderId;
    String? videoProvider;
    final videosRaw = json['videos'];
    if (videosRaw is List && videosRaw.isNotEmpty) {
      final v = videosRaw.first as Map<String, dynamic>;
      videoId = v['id'] as String?;
      videoStatus = v['status'] as String?;
      videoProviderId = v['provider_video_id'] as String?;
      videoProvider = v['provider'] as String?;
    } else if (videosRaw is Map<String, dynamic>) {
      videoId = videosRaw['id'] as String?;
      videoStatus = videosRaw['status'] as String?;
      videoProviderId = videosRaw['provider_video_id'] as String?;
      videoProvider = videosRaw['provider'] as String?;
    }

    // Parse multi-group junction associations
    final List<String> assignedGroupIds = [];
    final List<String> assignedGroupNames = [];
    final contentGroupsRaw = json['content_groups'];
    if (contentGroupsRaw is List) {
      for (final item in contentGroupsRaw) {
        if (item is Map<String, dynamic>) {
          final gId = item['group_id'] as String?;
          if (gId != null && !assignedGroupIds.contains(gId)) {
            assignedGroupIds.add(gId);
          }
          final groupObj = item['groups'];
          if (groupObj is Map<String, dynamic>) {
            final gName = groupObj['name'] as String?;
            if (gName != null && !assignedGroupNames.contains(gName)) {
              assignedGroupNames.add(gName);
            }
          }
        }
      }
    }

    // Parse associated and prerequisite exam metadata
    String? associatedExamTitle;
    if (json['associated_exam'] is Map<String, dynamic>) {
      associatedExamTitle = json['associated_exam']['title'] as String?;
    }

    String? prerequisiteExamTitle;
    int? prerequisitePassingScore;
    if (json['prerequisite_exam'] is Map<String, dynamic>) {
      final pExam = json['prerequisite_exam'] as Map<String, dynamic>;
      prerequisiteExamTitle = pExam['title'] as String?;
      prerequisitePassingScore = (pExam['passing_score'] as num?)?.toInt();
    }

    final isLocked = json['is_locked'] == true;

    return ContentModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      groupId: json['group_id'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      type: ContentType.fromString(json['type'] as String? ?? 'pdf'),
      status: ContentStatus.fromString(json['status'] as String? ?? 'draft'),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      file: fileAttachment,
      videoId: videoId,
      videoStatus: videoStatus,
      videoProviderId: videoProviderId,
      videoProvider: videoProvider,
      assignedGroupIds: assignedGroupIds,
      assignedGroupNames: assignedGroupNames,
      associatedExamId: json['associated_exam_id'] as String?,
      associatedExamTitle: associatedExamTitle,
      prerequisiteExamId: json['prerequisite_exam_id'] as String?,
      prerequisiteExamTitle: prerequisiteExamTitle,
      prerequisitePassingScore: prerequisitePassingScore,
      isLocked: isLocked,
      isVideoCompleted: json['is_video_completed'] == true,
      videoProgressPercentage:
          (json['video_progress_percentage'] as num?)?.toDouble() ?? 0.0,
      isExamPassed: json['is_exam_passed'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'group_id': groupId,
      'title': title,
      'description': description,
      'type': type.value,
      'status': status.value,
      'sort_order': sortOrder,
      'published_at': publishedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (associatedExamId != null) 'associated_exam_id': associatedExamId,
      if (prerequisiteExamId != null) 'prerequisite_exam_id': prerequisiteExamId,
    };
  }
}
