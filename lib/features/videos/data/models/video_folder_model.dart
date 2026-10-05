import '../../domain/entities/video_folder_entity.dart';

class VideoFolderModel extends VideoFolderEntity {
  const VideoFolderModel({
    required super.id,
    required super.tenantId,
    super.parentId,
    required super.name,
    required super.createdAt,
    required super.updatedAt,
    super.videoCount = 0,
    super.subfolderCount = 0,
  });

  factory VideoFolderModel.fromJson(Map<String, dynamic> json) {
    return VideoFolderModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String? ?? '',
      parentId: json['parent_id'] as String?,
      name: json['name'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      videoCount: json['video_count'] as int? ?? 0,
      subfolderCount: json['subfolder_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'parent_id': parentId,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
