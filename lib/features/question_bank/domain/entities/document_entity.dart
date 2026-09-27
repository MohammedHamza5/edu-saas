import 'package:equatable/equatable.dart';

/// Represents an uploaded exam document from `qb_documents` (§6).
/// Each document is the source container for extracted questions.
class DocumentEntity extends Equatable {
  final String id;
  final String tenantId;
  final String originalFilename;
  final String status; // pending | processing | done | failed
  final String? mime;
  final int? sizeBytes;
  final int? pageCount;
  final String? uploaderId;
  final String? pipelineVersion;
  final String? storagePath;
  final Map<String, dynamic>? rightsAttestation;
  final DateTime createdAt;

  /// Populated client-side via a joined count or separate query.
  final int questionCount;

  const DocumentEntity({
    required this.id,
    required this.tenantId,
    required this.originalFilename,
    required this.status,
    this.mime,
    this.sizeBytes,
    this.pageCount,
    this.uploaderId,
    this.pipelineVersion,
    this.storagePath,
    this.rightsAttestation,
    required this.createdAt,
    this.questionCount = 0,
  });

  bool get isPending => status == 'pending';
  bool get isProcessing => status == 'processing';
  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';

  /// Human-readable file size.
  String get fileSizeLabel {
    if (sizeBytes == null) return '';
    final kb = sizeBytes! / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  /// Clean display name without extension.
  String get displayName {
    final name = originalFilename
        .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
        .replaceAll('_', ' ');
    return name.isEmpty ? originalFilename : name;
  }

  DocumentEntity copyWith({
    String? id,
    String? tenantId,
    String? originalFilename,
    String? status,
    String? mime,
    int? sizeBytes,
    int? pageCount,
    String? uploaderId,
    String? pipelineVersion,
    String? storagePath,
    Map<String, dynamic>? rightsAttestation,
    DateTime? createdAt,
    int? questionCount,
  }) {
    return DocumentEntity(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      originalFilename: originalFilename ?? this.originalFilename,
      status: status ?? this.status,
      mime: mime ?? this.mime,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      pageCount: pageCount ?? this.pageCount,
      uploaderId: uploaderId ?? this.uploaderId,
      pipelineVersion: pipelineVersion ?? this.pipelineVersion,
      storagePath: storagePath ?? this.storagePath,
      rightsAttestation: rightsAttestation ?? this.rightsAttestation,
      createdAt: createdAt ?? this.createdAt,
      questionCount: questionCount ?? this.questionCount,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tenantId,
    originalFilename,
    status,
    mime,
    sizeBytes,
    pageCount,
    uploaderId,
    pipelineVersion,
    storagePath,
    rightsAttestation,
    createdAt,
    questionCount,
  ];
}
