import '../../domain/entities/library_material_entity.dart';

class LibraryMaterialModel extends LibraryMaterialEntity {
  const LibraryMaterialModel({
    required super.id,
    required super.tenantId,
    super.folderId,
    required super.title,
    super.description,
    required super.fileName,
    required super.storagePath,
    required super.fileSize,
    super.mimeType = 'application/pdf',
    super.storageProvider = 'supabase',
    super.fileHash,
    super.assignedLecturesCount = 0,
    required super.createdAt,
    required super.updatedAt,
    super.signedUrl,
  });

  factory LibraryMaterialModel.fromJson(Map<String, dynamic> json) {
    return LibraryMaterialModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      folderId: json['folder_id'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      fileName: json['file_name'] as String? ?? '',
      storagePath: json['storage_path'] as String? ?? '',
      fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
      mimeType: json['mime_type'] as String? ?? 'application/pdf',
      storageProvider: json['storage_provider'] as String? ?? 'supabase',
      fileHash: json['file_hash'] as String?,
      assignedLecturesCount:
          (json['assigned_lectures_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      signedUrl: json['signed_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'folder_id': folderId,
      'title': title,
      'description': description,
      'file_name': fileName,
      'storage_path': storagePath,
      'file_size': fileSize,
      'mime_type': mimeType,
      'storage_provider': storageProvider,
      'file_hash': fileHash,
      'assigned_lectures_count': assignedLecturesCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  LibraryMaterialModel copyWithSignedUrl(String url) {
    return LibraryMaterialModel(
      id: id,
      tenantId: tenantId,
      folderId: folderId,
      title: title,
      description: description,
      fileName: fileName,
      storagePath: storagePath,
      fileSize: fileSize,
      mimeType: mimeType,
      storageProvider: storageProvider,
      fileHash: fileHash,
      assignedLecturesCount: assignedLecturesCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
      signedUrl: url,
    );
  }
}
