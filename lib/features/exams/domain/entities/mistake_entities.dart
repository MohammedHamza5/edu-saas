import 'package:equatable/equatable.dart';

class MistakeSummaryEntity extends Equatable {
  final int totalMistakes;
  final int unresolvedCount;
  final int resolvedCount;
  final int unresolvedWrongCount;
  final int unresolvedSkippedCount;
  final int totalWrongCount;
  final int totalSkippedCount;
  final int conceptGapCount;
  final int carelessErrorCount;
  final int misreadQuestionCount;
  final int timePressureCount;
  final int unclassifiedCount;
  final List<MistakeSourceEntity> sources;

  const MistakeSummaryEntity({
    required this.totalMistakes,
    required this.unresolvedCount,
    required this.resolvedCount,
    this.unresolvedWrongCount = 0,
    this.unresolvedSkippedCount = 0,
    this.totalWrongCount = 0,
    this.totalSkippedCount = 0,
    this.conceptGapCount = 0,
    this.carelessErrorCount = 0,
    this.misreadQuestionCount = 0,
    this.timePressureCount = 0,
    this.unclassifiedCount = 0,
    required this.sources,
  });

  MistakeSummaryEntity copyWith({
    int? totalMistakes,
    int? unresolvedCount,
    int? resolvedCount,
    int? unresolvedWrongCount,
    int? unresolvedSkippedCount,
    int? totalWrongCount,
    int? totalSkippedCount,
    int? conceptGapCount,
    int? carelessErrorCount,
    int? misreadQuestionCount,
    int? timePressureCount,
    int? unclassifiedCount,
    List<MistakeSourceEntity>? sources,
  }) {
    return MistakeSummaryEntity(
      totalMistakes: totalMistakes ?? this.totalMistakes,
      unresolvedCount: unresolvedCount ?? this.unresolvedCount,
      resolvedCount: resolvedCount ?? this.resolvedCount,
      unresolvedWrongCount: unresolvedWrongCount ?? this.unresolvedWrongCount,
      unresolvedSkippedCount: unresolvedSkippedCount ?? this.unresolvedSkippedCount,
      totalWrongCount: totalWrongCount ?? this.totalWrongCount,
      totalSkippedCount: totalSkippedCount ?? this.totalSkippedCount,
      conceptGapCount: conceptGapCount ?? this.conceptGapCount,
      carelessErrorCount: carelessErrorCount ?? this.carelessErrorCount,
      misreadQuestionCount: misreadQuestionCount ?? this.misreadQuestionCount,
      timePressureCount: timePressureCount ?? this.timePressureCount,
      unclassifiedCount: unclassifiedCount ?? this.unclassifiedCount,
      sources: sources ?? this.sources,
    );
  }

  @override
  List<Object?> get props => [
        totalMistakes,
        unresolvedCount,
        resolvedCount,
        unresolvedWrongCount,
        unresolvedSkippedCount,
        totalWrongCount,
        totalSkippedCount,
        conceptGapCount,
        carelessErrorCount,
        misreadQuestionCount,
        timePressureCount,
        unclassifiedCount,
        sources,
      ];
}

class MistakeSourceEntity extends Equatable {
  final String examId;
  final String examTitle;
  final String? contentTitle;
  final int totalMistakes;
  final int unresolvedCount;

  const MistakeSourceEntity({
    required this.examId,
    required this.examTitle,
    this.contentTitle,
    required this.totalMistakes,
    required this.unresolvedCount,
  });

  @override
  List<Object?> get props => [
        examId,
        examTitle,
        contentTitle,
        totalMistakes,
        unresolvedCount,
      ];
}

class MistakeOptionEntity extends Equatable {
  final String id;
  final String optionText;
  final int sortOrder;

  const MistakeOptionEntity({
    required this.id,
    required this.optionText,
    required this.sortOrder,
  });

  @override
  List<Object?> get props => [id, optionText, sortOrder];
}

class MistakeQuestionEntity extends Equatable {
  final String mistakeId;
  final String questionId;
  final String questionText;
  final String questionType;
  final int points;
  final int sortOrder;
  final String? imageUrl;
  final Map<String, dynamic>? imageMeta;
  final bool isResolved;
  final int failureCount;
  final DateTime? lastFailedAt;
  final String sourceExamId;
  final String sourceExamTitle;
  final String? lessonTitle;
  final String? lastSelectedOptionId;
  final String? selectedOptionText;
  final String? reflectionReason;
  final List<MistakeOptionEntity> options;

  const MistakeQuestionEntity({
    required this.mistakeId,
    required this.questionId,
    required this.questionText,
    required this.questionType,
    required this.points,
    required this.sortOrder,
    this.imageUrl,
    this.imageMeta,
    required this.isResolved,
    required this.failureCount,
    this.lastFailedAt,
    required this.sourceExamId,
    required this.sourceExamTitle,
    this.lessonTitle,
    this.lastSelectedOptionId,
    this.selectedOptionText,
    this.reflectionReason,
    required this.options,
  });

  MistakeQuestionEntity copyWith({
    String? mistakeId,
    String? questionId,
    String? questionText,
    String? questionType,
    int? points,
    int? sortOrder,
    String? imageUrl,
    Map<String, dynamic>? imageMeta,
    bool? isResolved,
    int? failureCount,
    DateTime? lastFailedAt,
    String? sourceExamId,
    String? sourceExamTitle,
    String? lessonTitle,
    String? lastSelectedOptionId,
    String? selectedOptionText,
    String? reflectionReason,
    List<MistakeOptionEntity>? options,
  }) {
    return MistakeQuestionEntity(
      mistakeId: mistakeId ?? this.mistakeId,
      questionId: questionId ?? this.questionId,
      questionText: questionText ?? this.questionText,
      questionType: questionType ?? this.questionType,
      points: points ?? this.points,
      sortOrder: sortOrder ?? this.sortOrder,
      imageUrl: imageUrl ?? this.imageUrl,
      imageMeta: imageMeta ?? this.imageMeta,
      isResolved: isResolved ?? this.isResolved,
      failureCount: failureCount ?? this.failureCount,
      lastFailedAt: lastFailedAt ?? this.lastFailedAt,
      sourceExamId: sourceExamId ?? this.sourceExamId,
      sourceExamTitle: sourceExamTitle ?? this.sourceExamTitle,
      lessonTitle: lessonTitle ?? this.lessonTitle,
      lastSelectedOptionId: lastSelectedOptionId ?? this.lastSelectedOptionId,
      selectedOptionText: selectedOptionText ?? this.selectedOptionText,
      reflectionReason: reflectionReason ?? this.reflectionReason,
      options: options ?? this.options,
    );
  }

  /// Returns true if the student skipped the question without selecting any option.
  bool get isSkipped => lastSelectedOptionId == null || lastSelectedOptionId!.isEmpty;

  /// Returns true if the student chose an incorrect option.
  bool get isWrongAnswer => !isSkipped;

  @override
  List<Object?> get props => [
        mistakeId,
        questionId,
        questionText,
        questionType,
        points,
        sortOrder,
        imageUrl,
        imageMeta,
        isResolved,
        failureCount,
        lastFailedAt,
        sourceExamId,
        sourceExamTitle,
        lessonTitle,
        lastSelectedOptionId,
        selectedOptionText,
        reflectionReason,
        options,
      ];
}

class MistakeAnswerFeedbackEntity extends Equatable {
  final String questionId;
  final String? selectedOptionId;
  final String? correctOptionId;
  final bool isCorrect;

  const MistakeAnswerFeedbackEntity({
    required this.questionId,
    this.selectedOptionId,
    this.correctOptionId,
    required this.isCorrect,
  });

  @override
  List<Object?> get props => [
        questionId,
        selectedOptionId,
        correctOptionId,
        isCorrect,
      ];
}

class MistakePracticeResultEntity extends Equatable {
  final int totalQuestions;
  final int correctCount;
  final double percentage;
  final List<MistakeAnswerFeedbackEntity> results;

  const MistakePracticeResultEntity({
    required this.totalQuestions,
    required this.correctCount,
    required this.percentage,
    required this.results,
  });

  @override
  List<Object?> get props => [
        totalQuestions,
        correctCount,
        percentage,
        results,
      ];
}
