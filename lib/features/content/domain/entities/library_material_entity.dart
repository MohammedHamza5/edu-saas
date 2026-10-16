import 'package:equatable/equatable.dart';

class LibraryMaterialEntity extends Equatable {
  final String id;
  final String tenantId;
  final String? folderId;
  final String title;
  final String? description;
  final String fileName;
  final String storagePath;
  final int fileSize;
  final String mimeType;
  final String storageProvider;
  final String? fileHash;
  final int assignedLecturesCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? signedUrl;

  const LibraryMaterialEntity({
    required this.id,
    required this.tenantId,
    this.folderId,
    required this.title,
    this.description,
    required this.fileName,
    required this.storagePath,
    required this.fileSize,
    this.mimeType = 'application/pdf',
    this.storageProvider = 'supabase',
    this.fileHash,
    this.assignedLecturesCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.signedUrl,
  });

  bool get isPdf =>
      mimeType.toLowerCase().contains('pdf') ||
      fileName.toLowerCase().endsWith('.pdf');

  bool get isAssigned => assignedLecturesCount > 0;

  String get formattedFileSize {
    if (fileSize <= 0) return '0 B';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get fileExtension {
    final dotIdx = fileName.lastIndexOf('.');
    if (dotIdx == -1 || dotIdx == fileName.length - 1) return '';
    return fileName.substring(dotIdx + 1).toUpperCase();
  }

  LibraryMaterialEntity copyWith({
    String? id,
    String? tenantId,
    String? folderId,
    String? title,
    String? description,
    String? fileName,
    String? storagePath,
    int? fileSize,
    String? mimeType,
    String? storageProvider,
    String? fileHash,
    int? assignedLecturesCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? signedUrl,
  }) {
    return LibraryMaterialEntity(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      folderId: folderId ?? this.folderId,
      title: title ?? this.title,
      description: description ?? this.description,
      fileName: fileName ?? this.fileName,
      storagePath: storagePath ?? this.storagePath,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      storageProvider: storageProvider ?? this.storageProvider,
      fileHash: fileHash ?? this.fileHash,
      assignedLecturesCount:
          assignedLecturesCount ?? this.assignedLecturesCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      signedUrl: signedUrl ?? this.signedUrl,
    );
  }

  @override
  List<Object?> get props => [
        id,
        tenantId,
        folderId,
        title,
        description,
        fileName,
        storagePath,
        fileSize,
        mimeType,
        storageProvider,
        fileHash,
        assignedLecturesCount,
        createdAt,
        updatedAt,
        signedUrl,
      ];
}
