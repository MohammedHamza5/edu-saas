/// Abstract contract for storing and retrieving in-progress exam answers locally.
/// Isolates the Presentation layer (ExamsCubit) from concrete storage implementations (Clean Architecture).
abstract interface class ExamAnswersStorage {
  /// Persists student's selected answers map (questionId -> selectedOptionId).
  Future<void> saveAnswers({
    required String attemptId,
    required Map<String, String> answers,
  });

  /// Retrieves the saved draft answers for the given attemptId, or empty map if none exist.
  Future<Map<String, String>> getAnswers(String attemptId);

  /// Removes the draft answers when the attempt is successfully submitted.
  Future<void> clearAnswers(String attemptId);
}

/// In-memory implementation of [ExamAnswersStorage] for testing and fallback.
class InMemoryExamAnswersStorage implements ExamAnswersStorage {
  final Map<String, Map<String, String>> _store;

  InMemoryExamAnswersStorage([Map<String, Map<String, String>>? store])
      : _store = store ?? {};

  @override
  Future<void> saveAnswers({
    required String attemptId,
    required Map<String, String> answers,
  }) async {
    _store[attemptId] = Map<String, String>.from(answers);
  }

  @override
  Future<Map<String, String>> getAnswers(String attemptId) async {
    return _store[attemptId] != null
        ? Map<String, String>.from(_store[attemptId]!)
        : const {};
  }

  @override
  Future<void> clearAnswers(String attemptId) async {
    _store.remove(attemptId);
  }
}
