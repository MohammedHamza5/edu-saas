import 'package:edu_saas/core/errors/result.dart';
import '../entities/saved_question_entity.dart';

abstract class SavedQuestionsRepository {
  Future<Result<List<SavedQuestionEntity>>> getSavedQuestions();
  Future<Result<SavedQuestionEntity>> saveQuestion(SavedQuestionEntity question);
  Future<Result<bool>> removeSavedQuestion(String questionId);
  Future<Result<bool>> isQuestionSaved(String questionId);
  Future<Result<SavedQuestionEntity>> updatePersonalNote({
    required String questionId,
    required String? note,
  });
  Future<Result<SavedQuestionEntity>> updateDifficultyRating({
    required String questionId,
    required QuestionDifficultyRating rating,
    bool? isMastered,
  });
  Future<Result<SavedQuestionEntity>> markMastered({
    required String questionId,
    required bool isMastered,
  });
}
