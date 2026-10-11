import '../../domain/entities/exam_entity.dart';

class QuestionOptionModel extends QuestionOptionEntity {
  const QuestionOptionModel({
    required super.id,
    required super.questionId,
    required super.optionText,
    super.sortOrder,
    super.isCorrect,
    super.imageUrl,
    super.imageMeta,
  });

  factory QuestionOptionModel.fromJson(Map<String, dynamic> json) {
    return QuestionOptionModel(
      id: json['id']?.toString() ?? '',
      questionId: json['question_id']?.toString() ?? '',
      optionText: json['option_text']?.toString() ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isCorrect: json['is_correct'] as bool?,
      imageUrl: json['image_url']?.toString(),
      imageMeta: json['image_meta'] is Map ? Map<String, dynamic>.from(json['image_meta'] as Map) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_id': questionId,
      'option_text': optionText,
      'sort_order': sortOrder,
      if (isCorrect != null) 'is_correct': isCorrect,
      if (imageUrl != null) 'image_url': imageUrl,
      if (imageMeta != null) 'image_meta': imageMeta,
    };
  }
}
