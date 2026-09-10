import 'package:equatable/equatable.dart';
import 'file_attachment_entity.dart';

/// Supported types of content in Educational SaaS V1
enum ContentType {
  video,
  pdf,
  image,
  assignment,
  exam;

  static ContentType fromString(String val) {
    return switch (val.toLowerCase()) {
      'video' => ContentType.video,
      'pdf' => ContentType.pdf,
      'image' => ContentType.image,
      'assignment' => ContentType.assignment,
      'exam' => ContentType.exam,
      _ => ContentType.pdf,
    };
  }

  String get value => name;

  String get labelAr {
    return switch (this) {
      ContentType.video => 'فيديو تعليمي',
      ContentType.pdf => 'مذكرة / PDF',
      ContentType.image => 'صورة توضيحية',
      ContentType.assignment => 'واجب دراسي',
      ContentType.exam => 'امتحان تقييمي',
    };
  }
}

/// Lifecycle status of content
enum ContentStatus {
  draft,
  published,
  archived;

  static ContentStatus fromString(String val) {
    return switch (val.toLowerCase()) {
      'published' => ContentStatus.published,
      'archived' => ContentStatus.archived,
      _ => ContentStatus.draft,
    };
  }

  String get value => name;

  String get labelAr {
    return switch (this) {
      ContentStatus.draft => 'مسودة',
      ContentStatus.published => 'منشور',
      ContentStatus.archived => 'مؤرشف',
    };
  }
}

/// Main Academic Content Entity
class ContentEntity extends Equatable {
  final String id;
  final String tenantId;
  final String groupId;
  final String title;
  final String? description;
  final ContentType type;
  final ContentStatus status;
  final int sortOrder;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final FileAttachmentEntity? file;

  const ContentEntity({
    required this.id,
    required this.tenantId,
    required this.groupId,
    required this.title,
    this.description,
    required this.type,
    required this.status,
    this.sortOrder = 0,
    this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
    this.file,
  });

  bool get isPublished => status == ContentStatus.published;
  bool get isDraft => status == ContentStatus.draft;
  bool get isArchived => status == ContentStatus.archived;
  bool get hasAttachment => file != null;

  ContentEntity copyWith({
    String? id,
    String? tenantId,
    String? groupId,
    String? title,
    String? description,
    ContentType? type,
    ContentStatus? status,
    int? sortOrder,
    DateTime? publishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    FileAttachmentEntity? file,
  }) {
    return ContentEntity(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      groupId: groupId ?? this.groupId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      sortOrder: sortOrder ?? this.sortOrder,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      file: file ?? this.file,
    );
  }

  @override
  List<Object?> get props => [
        id,
        tenantId,
        groupId,
        title,
        description,
        type,
        status,
        sortOrder,
        publishedAt,
        createdAt,
        updatedAt,
        file,
      ];
}
