import '../../domain/entities/content_entity.dart';
import 'file_attachment_model.dart';

class ContentModel extends ContentEntity {
  const ContentModel({
    required super.id,
    required super.tenantId,
    required super.groupId,
    required super.title,
    super.description,
    required super.type,
    required super.status,
    super.sortOrder = 0,
    super.publishedAt,
    required super.createdAt,
    required super.updatedAt,
    super.file,
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

    return ContentModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      groupId: json['group_id'] as String? ?? '',
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
    };
  }
}
