import 'package:equatable/equatable.dart';

class MistakeSummaryEntity extends Equatable {
  final int totalMistakes;
  final int unresolvedCount;
  final int resolvedCount;
  final List<MistakeSourceEntity> sources;

  const MistakeSummaryEntity({
    required this.totalMistakes,
    required this.unresolvedCount,
    required this.resolvedCount,
    required this.sources,
  });

  @override
  List<Object?> get props => [
        totalMistakes,
        unresolvedCount,
        resolvedCount,
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
    required this.options,
  });

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
