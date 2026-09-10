import '../../domain/entities/assignment_entity.dart';

class SubmissionFileModel extends SubmissionFileEntity {
  const SubmissionFileModel({
    required super.id,
    required super.submissionId,
    required super.storagePath,
    required super.fileName,
    required super.mimeType,
    required super.fileSize,
    super.signedUrl,
    required super.createdAt,
  });

  factory SubmissionFileModel.fromJson(Map<String, dynamic> json, {String? signedUrl}) {
    return SubmissionFileModel(
      id: json['id'] as String,
      submissionId: json['submission_id'] as String,
      storagePath: json['storage_path'] as String,
      fileName: json['file_name'] as String,
      mimeType: json['mime_type'] as String,
      fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
      signedUrl: signedUrl ?? json['signed_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'submission_id': submissionId,
      'storage_path': storagePath,
      'file_name': fileName,
      'mime_type': mimeType,
      'file_size': fileSize,
      'created_at': createdAt.toIso8601String(),
    };
  }

  SubmissionFileModel copyWithSignedUrl(String url) {
    return SubmissionFileModel(
      id: id,
      submissionId: submissionId,
      storagePath: storagePath,
      fileName: fileName,
      mimeType: mimeType,
      fileSize: fileSize,
      signedUrl: url,
      createdAt: createdAt,
    );
  }
}
