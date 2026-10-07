import 'package:equatable/equatable.dart';

/// تمثيل فصل دراسي (Chapter) داخل كورس / مجموعة
class ChapterEntity extends Equatable {
  final String id;
  final String title;
  final String? description;
  final int sortOrder;
  final String? sourceFolderId;
  final DateTime? createdAt;

  const ChapterEntity({
    required this.id,
    required this.title,
    this.description,
    this.sortOrder = 0,
    this.sourceFolderId,
    this.createdAt,
  });

  factory ChapterEntity.fromJson(Map<String, dynamic> json) {
    return ChapterEntity(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      sourceFolderId: json['source_folder_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (description != null) 'description': description,
      'sort_order': sortOrder,
      if (sourceFolderId != null) 'source_folder_id': sourceFolderId,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  ChapterEntity copyWith({
    String? id,
    String? title,
    String? description,
    int? sortOrder,
    String? sourceFolderId,
    DateTime? createdAt,
  }) {
    return ChapterEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      sourceFolderId: sourceFolderId ?? this.sourceFolderId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        sortOrder,
        sourceFolderId,
        createdAt,
      ];
}
