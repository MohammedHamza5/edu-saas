import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/saved_question_entity.dart';
import '../../domain/repositories/saved_questions_repository.dart';
import 'saved_questions_state.dart';

class SavedQuestionsCubit extends Cubit<SavedQuestionsState> {
  final SavedQuestionsRepository repository;

  SavedQuestionsCubit({required this.repository}) : super(const SavedQuestionsInitial());

  Future<void> loadSavedQuestions() async {
    emit(const SavedQuestionsLoading());
    final result = await repository.getSavedQuestions();
    result.when(
      onSuccess: (list) {
        if (list.isEmpty) {
          emit(const SavedQuestionsEmpty());
        } else {
          emit(SavedQuestionsLoaded(questions: list));
        }
      },
      onFailure: (failure) {
        emit(SavedQuestionsError(failure.message));
      },
    );
  }

  Future<void> toggleSaveQuestion(SavedQuestionEntity question) async {
    final checkResult = await repository.isQuestionSaved(question.questionId);
    final isAlreadySaved = checkResult.dataOrNull ?? false;

    if (isAlreadySaved) {
      await repository.removeSavedQuestion(question.questionId);
    } else {
      await repository.saveQuestion(question);
    }
    await loadSavedQuestions();
  }

  Future<void> removeQuestion(String questionId) async {
    await repository.removeSavedQuestion(questionId);
    await loadSavedQuestions();
  }

  Future<void> updateNote(String questionId, String? note) async {
    await repository.updatePersonalNote(questionId: questionId, note: note);
    await loadSavedQuestions();
  }

  Future<void> updateDifficulty(
    String questionId,
    QuestionDifficultyRating rating, {
    bool? isMastered,
  }) async {
    await repository.updateDifficultyRating(
      questionId: questionId,
      rating: rating,
      isMastered: isMastered,
    );
    await loadSavedQuestions();
  }

  Future<void> markQuestionMastered(String questionId, {bool isMastered = true}) async {
    await repository.markMastered(questionId: questionId, isMastered: isMastered);
    await loadSavedQuestions();
  }

  void filterByVaultType(VaultFilterType filter) {
    final current = state;
    if (current is SavedQuestionsLoaded) {
      emit(current.copyWith(activeFilter: filter));
    }
  }

  void filterByDifficulty(QuestionDifficultyRating? rating) {
    final current = state;
    if (current is SavedQuestionsLoaded) {
      emit(current.copyWith(
        activeDifficultyFilter: rating,
        clearDifficultyFilter: rating == null,
      ));
    }
  }

  void searchQuestions(String query) {
    final current = state;
    if (current is SavedQuestionsLoaded) {
      emit(current.copyWith(searchQuery: query));
    }
  }
}
