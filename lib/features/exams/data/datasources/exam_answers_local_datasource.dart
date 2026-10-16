import 'dart:convert';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/secure_storage_helper.dart';

/// Local data source to safely persist student's in-progress answers during an active attempt.
/// Protects against accidental browser reloads, phone battery drops, or app backgrounding.
/// Operates client-side with zero database impact and zero risk to existing production workflows.
class ExamAnswersLocalDataSource {
  static const String _keyPrefix = 'edu_exam_answers_attempt_';

  const ExamAnswersLocalDataSource();

  /// Persists student's selected answers map (questionId -> selectedOptionId).
  Future<void> saveAnswers({
    required String attemptId,
    required Map<String, String> answers,
  }) async {
    try {
      if (attemptId.isEmpty) return;
      final jsonStr = jsonEncode(answers);
      await SecureStorageHelper.write(
        key: '$_keyPrefix$attemptId',
        value: jsonStr,
      );
    } catch (e, st) {
      AppLogger.e(
        'ExamAnswersLocalDataSource',
        'Failed to save draft answers for attempt $attemptId: $e',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Retrieves the saved draft answers for the given attemptId, or empty map if none exist.
  Future<Map<String, String>> getAnswers(String attemptId) async {
    try {
      if (attemptId.isEmpty) return const {};
      final jsonStr = await SecureStorageHelper.read(key: '$_keyPrefix$attemptId');
      if (jsonStr == null || jsonStr.trim().isEmpty) return const {};
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
      return const {};
    } catch (e, st) {
      AppLogger.e(
        'ExamAnswersLocalDataSource',
        'Failed to read draft answers for attempt $attemptId: $e',
        error: e,
        stackTrace: st,
      );
      return const {};
    }
  }

  /// Removes the draft answers when the attempt is successfully submitted.
  Future<void> clearAnswers(String attemptId) async {
    try {
      if (attemptId.isEmpty) return;
      await SecureStorageHelper.delete(key: '$_keyPrefix$attemptId');
    } catch (e, st) {
      AppLogger.e(
        'ExamAnswersLocalDataSource',
        'Failed to clear draft answers for attempt $attemptId: $e',
        error: e,
        stackTrace: st,
      );
    }
  }
}
