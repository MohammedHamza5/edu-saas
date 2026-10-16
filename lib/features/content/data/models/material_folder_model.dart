import '../../domain/entities/material_folder_entity.dart';

class MaterialFolderModel extends MaterialFolderEntity {
  const MaterialFolderModel({
    required super.id,
    required super.tenantId,
    super.parentId,
    required super.name,
    super.color = '#EA580C',
    super.icon = 'folder',
    super.sortOrder = 0,
    required super.createdAt,
    required super.updatedAt,
    super.filesCount = 0,
    super.totalSizeBytes = 0,
    super.subfoldersCount = 0,
  });

  factory MaterialFolderModel.fromJson(Map<String, dynamic> json) {
    return MaterialFolderModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      parentId: json['parent_id'] as String?,
      name: json['name'] as String? ?? '',
      color: json['color'] as String? ?? '#EA580C',
      icon: json['icon'] as String? ?? 'folder',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      filesCount: (json['files_count'] as num?)?.toInt() ?? 0,
      totalSizeBytes: (json['total_size_bytes'] as num?)?.toInt() ?? 0,
      subfoldersCount: (json['subfolders_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'parent_id': parentId,
      'name': name,
      'color': color,
      'icon': icon,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
