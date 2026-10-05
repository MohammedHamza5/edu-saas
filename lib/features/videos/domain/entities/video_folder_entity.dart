import 'package:equatable/equatable.dart';

class VideoFolderEntity extends Equatable {
  final String id;
  final String tenantId;
  final String? parentId;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int videoCount;
  final int subfolderCount;

  const VideoFolderEntity({
    required this.id,
    required this.tenantId,
    this.parentId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.videoCount = 0,
    this.subfolderCount = 0,
  });

  VideoFolderEntity copyWith({
    String? id,
    String? tenantId,
    String? parentId,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? videoCount,
    int? subfolderCount,
  }) {
    return VideoFolderEntity(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      videoCount: videoCount ?? this.videoCount,
      subfolderCount: subfolderCount ?? this.subfolderCount,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tenantId,
    parentId,
    name,
    createdAt,
    updatedAt,
    videoCount,
    subfolderCount,
  ];
}
