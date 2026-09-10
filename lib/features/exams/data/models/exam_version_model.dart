import '../../domain/entities/exam_entity.dart';
import 'exam_question_model.dart';

class ExamVersionModel extends ExamVersionEntity {
  const ExamVersionModel({
    required super.id,
    required super.examId,
    super.versionNumber,
    super.status,
    required super.createdAt,
    super.publishedAt,
    super.questions,
  });

  factory ExamVersionModel.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'] ?? json['exam_questions'];
    final questionsList = (rawQuestions as List<dynamic>?)
            ?.map((q) => ExamQuestionModel.fromJson(q as Map<String, dynamic>))
            .toList() ??
        <ExamQuestionModel>[];

    return ExamVersionModel(
      id: json['id'] as String,
      examId: json['exam_id'] as String? ?? '',
      versionNumber: (json['version_number'] as num?)?.toInt() ?? 1,
      status: ExamStatus.fromString(json['status'] as String? ?? 'draft'),
      createdAt: DateTime.parse(json['created_at'] as String),
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
      questions: questionsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exam_id': examId,
      'version_number': versionNumber,
      'status': status.value,
      'created_at': createdAt.toIso8601String(),
      if (publishedAt != null) 'published_at': publishedAt!.toIso8601String(),
    };
  }
}
