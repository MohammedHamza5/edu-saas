import 'package:equatable/equatable.dart';

class MaterialFolderEntity extends Equatable {
  final String id;
  final String tenantId;
  final String? parentId;
  final String name;
  final String color;
  final String icon;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int filesCount;
  final int totalSizeBytes;
  final int subfoldersCount;

  const MaterialFolderEntity({
    required this.id,
    required this.tenantId,
    this.parentId,
    required this.name,
    this.color = '#EA580C',
    this.icon = 'folder',
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.filesCount = 0,
    this.totalSizeBytes = 0,
    this.subfoldersCount = 0,
  });

  bool get hasFiles => filesCount > 0;
  bool get hasSubfolders => subfoldersCount > 0;
  bool get isEmpty => filesCount == 0 && subfoldersCount == 0;

  String get formattedTotalSize {
    if (totalSizeBytes <= 0) return '0 B';
    if (totalSizeBytes < 1024) return '$totalSizeBytes B';
    if (totalSizeBytes < 1024 * 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  MaterialFolderEntity copyWith({
    String? id,
    String? tenantId,
    String? parentId,
    String? name,
    String? color,
    String? icon,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? filesCount,
    int? totalSizeBytes,
    int? subfoldersCount,
  }) {
    return MaterialFolderEntity(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      filesCount: filesCount ?? this.filesCount,
      totalSizeBytes: totalSizeBytes ?? this.totalSizeBytes,
      subfoldersCount: subfoldersCount ?? this.subfoldersCount,
    );
  }

  @override
  List<Object?> get props => [
        id,
        tenantId,
        parentId,
        name,
        color,
        icon,
        sortOrder,
        createdAt,
        updatedAt,
        filesCount,
        totalSizeBytes,
        subfoldersCount,
      ];
}
