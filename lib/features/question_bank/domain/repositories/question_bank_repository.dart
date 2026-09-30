import '../entities/document_entity.dart';
import '../entities/question_entity.dart';
import '../entities/question_revision_entity.dart';
import '../entities/validation_issue_entity.dart';

/// Repository contract for Question Bank operations and Review Console (§10).
abstract class QuestionBankRepository {
  // ── Document-Level Operations ─────────────────────────────────────────────

  /// Fetches all documents for the current tenant, ordered by creation date (newest first).
  Future<List<DocumentEntity>> getDocuments();

  /// Fetches a single document by ID.
  Future<DocumentEntity> getDocumentById(String documentId);

  /// Fetches questions belonging to a specific document.
  Future<List<QuestionEntity>> getQuestionsByDocument(
    String documentId, {
    String? statusFilter,
  });

  /// Deletes a document and all its associated questions, revisions, validation data (cascade).
  Future<void> deleteDocument(String documentId);

  /// Deletes a single question and all its associated revisions and validation data.
  Future<void> deleteQuestion(String questionId);

  /// Retries ingestion for a failed document by creating a new job.
  Future<String> retryDocumentIngestion(String documentId);

  // ── Question-Level Operations ─────────────────────────────────────────────

  /// Fetches questions for the current tenant, optionally filtered by status and sorted by priority.
  Future<List<QuestionEntity>> getQuestions({
    String? statusFilter,
    bool sortByPriority = false,
  });

  /// Fetches a question by its unique ID.
  Future<QuestionEntity> getQuestionById(String questionId);

  /// Fetches the latest revision for a question.
  Future<QuestionRevisionEntity?> getLatestRevision(String questionId);

  /// Fetches all immutable revisions for a question (revision history).
  Future<List<QuestionRevisionEntity>> getRevisionHistory(String questionId);

  /// Fetches validation issues for a specific revision.
  Future<List<ValidationIssueEntity>> getValidationIssues(String revisionId);

  /// Acknowledges / confirms a validation issue (resolvable_by = confirm).
  Future<void> acknowledgeIssue({
    required String revisionId,
    required String issueId,
    String? rationale,
  });

  /// Performs a block-level edit and saves a new immutable revision with reason.
  Future<QuestionRevisionEntity> editBlock({
    required String questionId,
    required String blockId,
    required String newValue,
    required String reason,
  });

  /// Selects and confirms the correct answer for an unknown/ai_proposed question.
  Future<QuestionRevisionEntity> selectAnswer({
    required String questionId,
    required String selectedKey,
  });

  /// Merges question with the subsequent question (cross-page continuation resolution).
  Future<void> mergeWithNext({required String questionId});

  /// Splits question into two separate questions at the specified block index.
  Future<void> splitQuestion({
    required String questionId,
    required int splitIndex,
  });

  /// Marks a question source as unreadable / quarantined.
  Future<void> markSourceUnreadable({
    required String questionId,
    required String reason,
  });

  /// Restores an older immutable revision as the active latest revision.
  Future<QuestionRevisionEntity> restoreRevision({
    required String questionId,
    required String revisionId,
  });

  /// Tags question for second-review sampling (random 5-10%).
  Future<void> sampleSecondReview({required String questionId});

  /// Manually creates a new question and its initial revision.
  Future<String> createManualQuestion({
    required String sourceLabel,
    required String questionType,
    required String stemText,
    required List<Map<String, dynamic>> options,
    required String correctAnswer,
    required Map<String, dynamic> rightsAttestation,
    String? imageUrl,
    Map<String, dynamic>? imageMeta,
  });

  /// Approves an immutable revision, recording content_hash binding.
  Future<void> approveRevision({
    required String revisionId,
    required String contentHash,
    List<String>? acknowledgedIssueIds,
  });

  /// Triggers the database publish gate function publish_revision(revision_id).
  Future<void> publishRevision({required String revisionId});

  /// Ingests an uploaded exam document via the real Python pipeline (Edge Function + Worker).
  /// Returns real questions extracted by the pipeline once the job is done.
  Future<List<QuestionEntity>> ingestExamDocument({
    required String filename,
    required List<int> bytes,
    String? answerKeyFilename,
    required Map<String, dynamic> rightsAttestation,
  });

  /// Polls the status of a pipeline job (pending/running/done/failed).
  Future<Map<String, dynamic>> getJobStatus(String jobId);

  /// Deploys a list of questions directly as a published exam assigned to a specific group.
  Future<String> createExamFromQuestions({
    required String groupId,
    required String title,
    required int durationMinutes,
    required List<QuestionEntity> questions,
  });
}
