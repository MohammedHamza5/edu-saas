import 'package:equatable/equatable.dart';
import '../../domain/entities/saved_question_entity.dart';

abstract class AnkiDrillState extends Equatable {
  const AnkiDrillState();

  @override
  List<Object?> get props => [];
}

class AnkiDrillInitial extends AnkiDrillState {
  const AnkiDrillInitial();
}

class AnkiDrillActive extends AnkiDrillState {
  final SavedQuestionEntity currentQuestion;
  final int queueLength;
  final int totalQuestions;
  final int currentIndex;
  final String? selectedOptionId;
  final bool isRevealed;
  final bool isCorrect;
  final int masteredCount;
  final int repeatedCount;

  const AnkiDrillActive({
    required this.currentQuestion,
    required this.queueLength,
    required this.totalQuestions,
    required this.currentIndex,
    this.selectedOptionId,
    this.isRevealed = false,
    this.isCorrect = false,
    this.masteredCount = 0,
    this.repeatedCount = 0,
  });

  AnkiDrillActive copyWith({
    SavedQuestionEntity? currentQuestion,
    int? queueLength,
    int? totalQuestions,
    int? currentIndex,
    String? selectedOptionId,
    bool clearSelectedOption = false,
    bool? isRevealed,
    bool? isCorrect,
    int? masteredCount,
    int? repeatedCount,
  }) {
    return AnkiDrillActive(
      currentQuestion: currentQuestion ?? this.currentQuestion,
      queueLength: queueLength ?? this.queueLength,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      currentIndex: currentIndex ?? this.currentIndex,
      selectedOptionId: clearSelectedOption
          ? null
          : (selectedOptionId ?? this.selectedOptionId),
      isRevealed: isRevealed ?? this.isRevealed,
      isCorrect: isCorrect ?? this.isCorrect,
      masteredCount: masteredCount ?? this.masteredCount,
      repeatedCount: repeatedCount ?? this.repeatedCount,
    );
  }

  @override
  List<Object?> get props => [
    currentQuestion,
    queueLength,
    totalQuestions,
    currentIndex,
    selectedOptionId,
    isRevealed,
    isCorrect,
    masteredCount,
    repeatedCount,
  ];
}

class AnkiDrillCompleted extends AnkiDrillState {
  final int totalReviewed;
  final int masteredCount;
  final int repeatedCount;

  const AnkiDrillCompleted({
    required this.totalReviewed,
    required this.masteredCount,
    required this.repeatedCount,
  });

  @override
  List<Object?> get props => [totalReviewed, masteredCount, repeatedCount];
}

class AnkiDrillEmpty extends AnkiDrillState {
  const AnkiDrillEmpty();
}
