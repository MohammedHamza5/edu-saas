import '../../domain/entities/exam_entity.dart';

class ExamContextModel extends ExamContextEntity {
  const ExamContextModel({
    required super.id,
    required super.examVersionId,
    super.title,
    super.contextText,
    super.imageUrl,
    super.imageMeta,
    super.sortOrder,
  });

  factory ExamContextModel.fromJson(Map<String, dynamic> json) {
    return ExamContextModel(
      id: json['id'] as String,
      examVersionId: json['exam_version_id'] as String? ?? '',
      title: json['title'] as String?,
      contextText: json['context_text'] as String?,
      imageUrl: json['image_url'] as String?,
      imageMeta: json['image_meta'] as Map<String, dynamic>?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exam_version_id': examVersionId,
      if (title != null) 'title': title,
      if (contextText != null) 'context_text': contextText,
      if (imageUrl != null) 'image_url': imageUrl,
      if (imageMeta != null) 'image_meta': imageMeta,
      'sort_order': sortOrder,
    };
  }
}
