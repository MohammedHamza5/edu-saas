import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/saved_question_entity.dart';
import '../../domain/repositories/saved_questions_repository.dart';
import 'anki_drill_state.dart';

class AnkiDrillCubit extends Cubit<AnkiDrillState> {
  final SavedQuestionsRepository repository;
  final List<SavedQuestionEntity> _queue = [];
  int _totalQuestions = 0;
  int _currentIndex = 0;
  int _masteredCount = 0;
  int _repeatedCount = 0;
  int _totalReviewed = 0;

  AnkiDrillCubit({required this.repository}) : super(const AnkiDrillInitial());

  void startDrill(List<SavedQuestionEntity> questions) {
    if (questions.isEmpty) {
      emit(const AnkiDrillEmpty());
      return;
    }
    _queue.clear();
    _queue.addAll(questions);
    _totalQuestions = questions.length;
    _currentIndex = 0;
    _masteredCount = 0;
    _repeatedCount = 0;
    _totalReviewed = 0;

    _emitNextQuestion();
  }

  void _emitNextQuestion() {
    if (_queue.isEmpty) {
      emit(AnkiDrillCompleted(
        totalReviewed: _totalReviewed,
        masteredCount: _masteredCount,
        repeatedCount: _repeatedCount,
      ));
      return;
    }

    final current = _queue.first;
    emit(AnkiDrillActive(
      currentQuestion: current,
      queueLength: _queue.length,
      totalQuestions: _totalQuestions,
      currentIndex: _currentIndex + 1,
      selectedOptionId: null,
      isRevealed: false,
      isCorrect: false,
      masteredCount: _masteredCount,
      repeatedCount: _repeatedCount,
    ));
  }

  void selectOption(String optionId) {
    final current = state;
    if (current is AnkiDrillActive && !current.isRevealed) {
      emit(current.copyWith(selectedOptionId: optionId));
    }
  }

  void checkAnswer() {
    final current = state;
    if (current is! AnkiDrillActive || current.selectedOptionId == null || current.isRevealed) {
      return;
    }

    final selectedOpt = current.currentQuestion.options.firstWhere(
      (o) => o.id == current.selectedOptionId,
      orElse: () => current.currentQuestion.options.first,
    );

    final isCorrect = selectedOpt.isCorrect;
    _totalReviewed++;

    emit(current.copyWith(
      isRevealed: true,
      isCorrect: isCorrect,
    ));
  }

  Future<void> rateDifficultyAndAdvance(QuestionDifficultyRating rating) async {
    final current = state;
    if (current is! AnkiDrillActive || !current.isRevealed) return;

    final question = _queue.removeAt(0);

    // 1. Spaced Repetition Logic (Anki SuperMemo Style)
    if (rating == QuestionDifficultyRating.hard) {
      // Re-queue hard questions to the end of the session so they repeat!
      _queue.add(question);
      _repeatedCount++;
      await repository.updateDifficultyRating(
        questionId: question.questionId,
        rating: rating,
        isMastered: false,
      );
    } else if (rating == QuestionDifficultyRating.easy) {
      _masteredCount++;
      _currentIndex++;
      await repository.updateDifficultyRating(
        questionId: question.questionId,
        rating: rating,
        isMastered: true,
      );
    } else {
      // Medium
      _currentIndex++;
      await repository.updateDifficultyRating(
        questionId: question.questionId,
        rating: rating,
        isMastered: false,
      );
    }

    _emitNextQuestion();
  }
}
