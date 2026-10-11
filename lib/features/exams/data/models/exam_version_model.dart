import '../../domain/entities/exam_entity.dart';
import 'exam_context_model.dart';
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
    super.contexts,
  });

  factory ExamVersionModel.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'] ?? json['exam_questions'];
    final questionsList =
        (rawQuestions as List<dynamic>?)
            ?.whereType<Map<dynamic, dynamic>>()
            .where((q) => q['id'] != null)
            .map((q) => ExamQuestionModel.fromJson(Map<String, dynamic>.from(q)))
            .toList() ??
        <ExamQuestionModel>[];

    final rawContexts = json['contexts'] ?? json['exam_contexts'];
    final contextsList =
        (rawContexts as List<dynamic>?)
            ?.whereType<Map<dynamic, dynamic>>()
            .where((c) => c['id'] != null)
            .map((c) => ExamContextModel.fromJson(Map<String, dynamic>.from(c)))
            .toList() ??
        <ExamContextModel>[];

    return ExamVersionModel(
      id: json['id']?.toString() ?? '',
      examId: json['exam_id']?.toString() ?? '',
      versionNumber: (json['version_number'] as num?)?.toInt() ?? 1,
      status: ExamStatus.fromString(json['status']?.toString() ?? 'draft'),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'].toString())
          : null,
      questions: questionsList,
      contexts: contextsList,
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
