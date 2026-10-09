import '../../domain/entities/video_folder_entity.dart';

class VideoFolderModel extends VideoFolderEntity {
  const VideoFolderModel({
    required super.id,
    required super.tenantId,
    super.parentId,
    required super.name,
    super.color,
    required super.createdAt,
    required super.updatedAt,
    super.videoCount = 0,
    super.subfolderCount = 0,
    super.totalDurationSeconds = 0,
    super.readyVideoCount = 0,
    super.assignedChaptersCount = 0,
    super.assignedGroups = const [],
  });

  factory VideoFolderModel.fromJson(Map<String, dynamic> json) {
    final rawGroups = json['assigned_groups'];
    List<FolderAssignedGroupInfo> assignedList = [];
    if (rawGroups is List) {
      assignedList = rawGroups
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => FolderAssignedGroupInfo.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    return VideoFolderModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String? ?? '',
      parentId: json['parent_id'] as String?,
      name: json['name'] as String? ?? '',
      color: json['color'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      videoCount: json['video_count'] as int? ?? 0,
      subfolderCount: json['subfolder_count'] as int? ?? 0,
      totalDurationSeconds: json['total_duration_seconds'] as int? ?? 0,
      readyVideoCount: json['ready_video_count'] as int? ?? 0,
      assignedChaptersCount: json['assigned_chapters_count'] as int? ?? 0,
      assignedGroups: assignedList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'parent_id': parentId,
      'name': name,
      if (color != null) 'color': color,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
