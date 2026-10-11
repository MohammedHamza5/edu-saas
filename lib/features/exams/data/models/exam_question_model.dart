import '../../domain/entities/exam_entity.dart';
import 'question_option_model.dart';

class ExamQuestionModel extends ExamQuestionEntity {
  const ExamQuestionModel({
    required super.id,
    required super.examVersionId,
    required super.questionText,
    super.questionType,
    super.points,
    super.sortOrder,
    super.options,
    super.imageUrl,
    super.imageMeta,
    super.contextId,
  });

  factory ExamQuestionModel.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] ?? json['question_options'];
    final optionsList =
        (rawOptions as List<dynamic>?)
            ?.whereType<Map<dynamic, dynamic>>()
            .where((o) => o['id'] != null)
            .map(
              (o) => QuestionOptionModel.fromJson(Map<String, dynamic>.from(o)),
            )
            .toList() ??
        <QuestionOptionModel>[];

    return ExamQuestionModel(
      id: json['id']?.toString() ?? '',
      examVersionId: json['exam_version_id']?.toString() ?? '',
      questionText: json['question_text']?.toString() ?? '',
      questionType: QuestionType.fromString(
        json['question_type']?.toString() ?? 'multiple_choice',
      ),
      points: (json['points'] as num?)?.toInt() ?? 1,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      options: optionsList,
      imageUrl: json['image_url']?.toString(),
      imageMeta: json['image_meta'] is Map ? Map<String, dynamic>.from(json['image_meta'] as Map) : null,
      contextId: json['context_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exam_version_id': examVersionId,
      'question_text': questionText,
      'question_type': questionType.value,
      'points': points,
      'sort_order': sortOrder,
      if (imageUrl != null) 'image_url': imageUrl,
      if (imageMeta != null) 'image_meta': imageMeta,
      if (contextId != null) 'context_id': contextId,
    };
  }
}
