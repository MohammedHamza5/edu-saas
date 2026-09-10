import 'package:equatable/equatable.dart';

/// Represents a secure file attachment stored in private Supabase Storage
class FileAttachmentEntity extends Equatable {
  final String id;
  final String tenantId;
  final String contentId;
  final String storagePath;
  final String fileName;
  final String mimeType;
  final int fileSize;
  final DateTime createdAt;
  final String? signedUrl;

  const FileAttachmentEntity({
    required this.id,
    required this.tenantId,
    required this.contentId,
    required this.storagePath,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    required this.createdAt,
    this.signedUrl,
  });

  FileAttachmentEntity copyWith({
    String? id,
    String? tenantId,
    String? contentId,
    String? storagePath,
    String? fileName,
    String? mimeType,
    int? fileSize,
    DateTime? createdAt,
    String? signedUrl,
  }) {
    return FileAttachmentEntity(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      contentId: contentId ?? this.contentId,
      storagePath: storagePath ?? this.storagePath,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      createdAt: createdAt ?? this.createdAt,
      signedUrl: signedUrl ?? this.signedUrl,
    );
  }

  /// Formatted file size string (e.g., 2.4 MB, 500 KB)
  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  List<Object?> get props => [
        id,
        tenantId,
        contentId,
        storagePath,
        fileName,
        mimeType,
        fileSize,
        createdAt,
        signedUrl,
      ];
}
