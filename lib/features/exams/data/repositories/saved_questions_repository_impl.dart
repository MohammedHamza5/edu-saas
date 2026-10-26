import 'package:edu_saas/core/errors/failures.dart';
import 'package:edu_saas/core/errors/result.dart';
import '../../domain/entities/saved_question_entity.dart';
import '../../domain/repositories/saved_questions_repository.dart';
import '../datasources/saved_questions_local_datasource.dart';

class SavedQuestionsRepositoryImpl implements SavedQuestionsRepository {
  final SavedQuestionsLocalDataSource localDataSource;

  const SavedQuestionsRepositoryImpl({required this.localDataSource});

  @override
  Future<Result<List<SavedQuestionEntity>>> getSavedQuestions() async {
    try {
      final list = await localDataSource.getSavedQuestions();
      return Success(list);
    } catch (e) {
      return FailureResult(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<SavedQuestionEntity>> saveQuestion(SavedQuestionEntity question) async {
    try {
      final saved = await localDataSource.saveQuestion(question);
      return Success(saved);
    } catch (e) {
      return FailureResult(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<bool>> removeSavedQuestion(String questionId) async {
    try {
      final removed = await localDataSource.removeSavedQuestion(questionId);
      return Success(removed);
    } catch (e) {
      return FailureResult(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<bool>> isQuestionSaved(String questionId) async {
    try {
      final saved = await localDataSource.isQuestionSaved(questionId);
      return Success(saved);
    } catch (e) {
      return FailureResult(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<SavedQuestionEntity>> updatePersonalNote({
    required String questionId,
    required String? note,
  }) async {
    try {
      final updated = await localDataSource.updatePersonalNote(questionId, note);
      return Success(updated);
    } catch (e) {
      return FailureResult(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<SavedQuestionEntity>> updateDifficultyRating({
    required String questionId,
    required QuestionDifficultyRating rating,
    bool? isMastered,
  }) async {
    try {
      final updated = await localDataSource.updateDifficultyRating(
        questionId,
        rating,
        isMastered: isMastered,
      );
      return Success(updated);
    } catch (e) {
      return FailureResult(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<SavedQuestionEntity>> markMastered({
    required String questionId,
    required bool isMastered,
  }) async {
    try {
      final updated = await localDataSource.markMastered(questionId, isMastered);
      return Success(updated);
    } catch (e) {
      return FailureResult(CacheFailure(e.toString()));
    }
  }
}
