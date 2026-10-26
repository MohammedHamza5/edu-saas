/// Abstract contract for storing and retrieving in-progress exam creation drafts locally.
/// Decouples presentation pages from concrete secure storage implementations (Clean Architecture).
abstract interface class ExamDraftStorage {
  /// Persists the draft JSON structure into secure local storage.
  Future<void> saveDraft({
    required String draftKey,
    required Map<String, dynamic> data,
  });

  /// Retrieves the saved draft for the given key, or null if none exists.
  Future<Map<String, dynamic>?> getDraft(String draftKey);

  /// Removes the draft when the exam is successfully created or discarded.
  Future<void> clearDraft(String draftKey);
}
