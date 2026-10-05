import '../../domain/entities/mistake_entities.dart';

class MistakeSummaryModel extends MistakeSummaryEntity {
  const MistakeSummaryModel({
    required super.totalMistakes,
    required super.unresolvedCount,
    required super.resolvedCount,
    required super.sources,
  });

  factory MistakeSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawSources = json['sources'] as List<dynamic>? ?? [];
    final sources = rawSources
        .map((s) => MistakeSourceModel.fromJson(Map<String, dynamic>.from(s as Map)))
        .toList();

    return MistakeSummaryModel(
      totalMistakes: (json['total_mistakes'] as num?)?.toInt() ?? 0,
      unresolvedCount: (json['unresolved_count'] as num?)?.toInt() ?? 0,
      resolvedCount: (json['resolved_count'] as num?)?.toInt() ?? 0,
      sources: sources,
    );
  }
}

class MistakeSourceModel extends MistakeSourceEntity {
  const MistakeSourceModel({
    required super.examId,
    required super.examTitle,
    super.contentTitle,
    required super.totalMistakes,
    required super.unresolvedCount,
  });

  factory MistakeSourceModel.fromJson(Map<String, dynamic> json) {
    return MistakeSourceModel(
      examId: (json['exam_id'] as String?) ?? '',
      examTitle: (json['exam_title'] as String?) ?? 'اختبار',
      contentTitle: json['content_title'] as String?,
      totalMistakes: (json['total_mistakes'] as num?)?.toInt() ?? 0,
      unresolvedCount: (json['unresolved_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class MistakeOptionModel extends MistakeOptionEntity {
  const MistakeOptionModel({
    required super.id,
    required super.optionText,
    required super.sortOrder,
  });

  factory MistakeOptionModel.fromJson(Map<String, dynamic> json) {
    return MistakeOptionModel(
      id: (json['id'] as String?) ?? '',
      optionText: (json['option_text'] as String?) ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class MistakeQuestionModel extends MistakeQuestionEntity {
  const MistakeQuestionModel({
    required super.mistakeId,
    required super.questionId,
    required super.questionText,
    required super.questionType,
    required super.points,
    required super.sortOrder,
    super.imageUrl,
    super.imageMeta,
    required super.isResolved,
    required super.failureCount,
    super.lastFailedAt,
    required super.sourceExamId,
    required super.sourceExamTitle,
    super.lessonTitle,
    super.lastSelectedOptionId,
    required super.options,
  });

  factory MistakeQuestionModel.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List<dynamic>? ?? [];
    final options = rawOptions
        .map((o) => MistakeOptionModel.fromJson(Map<String, dynamic>.from(o as Map)))
        .toList();

    return MistakeQuestionModel(
      mistakeId: (json['mistake_id'] as String?) ?? '',
      questionId: (json['question_id'] as String?) ?? '',
      questionText: (json['question_text'] as String?) ?? '',
      questionType: (json['question_type'] as String?) ?? 'single_choice',
      points: (json['points'] as num?)?.toInt() ?? 1,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      imageUrl: json['image_url'] as String?,
      imageMeta: json['image_meta'] is Map
          ? Map<String, dynamic>.from(json['image_meta'] as Map)
          : null,
      isResolved: json['is_resolved'] as bool? ?? false,
      failureCount: (json['failure_count'] as num?)?.toInt() ?? 1,
      lastFailedAt: json['last_failed_at'] != null
          ? DateTime.tryParse(json['last_failed_at'] as String)
          : null,
      sourceExamId: (json['source_exam_id'] as String?) ?? '',
      sourceExamTitle: (json['source_exam_title'] as String?) ?? 'اختبار',
      lessonTitle: json['lesson_title'] as String?,
      lastSelectedOptionId: json['last_selected_option_id'] as String?,
      options: options,
    );
  }
}

class MistakeAnswerFeedbackModel extends MistakeAnswerFeedbackEntity {
  const MistakeAnswerFeedbackModel({
    required super.questionId,
    super.selectedOptionId,
    super.correctOptionId,
    required super.isCorrect,
  });

  factory MistakeAnswerFeedbackModel.fromJson(Map<String, dynamic> json) {
    return MistakeAnswerFeedbackModel(
      questionId: (json['question_id'] as String?) ?? '',
      selectedOptionId: json['selected_option_id'] as String?,
      correctOptionId: json['correct_option_id'] as String?,
      isCorrect: json['is_correct'] as bool? ?? false,
    );
  }
}

class MistakePracticeResultModel extends MistakePracticeResultEntity {
  const MistakePracticeResultModel({
    required super.totalQuestions,
    required super.correctCount,
    required super.percentage,
    required super.results,
  });

  factory MistakePracticeResultModel.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'] as List<dynamic>? ?? [];
    final results = rawResults
        .map((r) => MistakeAnswerFeedbackModel.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();

    return MistakePracticeResultModel(
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 0,
      correctCount: (json['correct_count'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      results: results,
    );
  }
}
