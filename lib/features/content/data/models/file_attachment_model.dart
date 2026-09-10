import '../../domain/entities/file_attachment_entity.dart';

class FileAttachmentModel extends FileAttachmentEntity {
  const FileAttachmentModel({
    required super.id,
    required super.tenantId,
    required super.contentId,
    required super.storagePath,
    required super.fileName,
    required super.mimeType,
    required super.fileSize,
    required super.createdAt,
    super.signedUrl,
  });

  factory FileAttachmentModel.fromJson(Map<String, dynamic> json) {
    return FileAttachmentModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      contentId: json['content_id'] as String? ?? '',
      storagePath: json['storage_path'] as String? ?? '',
      fileName: json['file_name'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? '',
      fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      signedUrl: json['signed_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'content_id': contentId,
      'storage_path': storagePath,
      'file_name': fileName,
      'mime_type': mimeType,
      'file_size': fileSize,
      'created_at': createdAt.toIso8601String(),
    };
  }

  FileAttachmentModel copyWithSignedUrl(String url) {
    return FileAttachmentModel(
      id: id,
      tenantId: tenantId,
      contentId: contentId,
      storagePath: storagePath,
      fileName: fileName,
      mimeType: mimeType,
      fileSize: fileSize,
      createdAt: createdAt,
      signedUrl: url,
    );
  }
}
