import '../../domain/entities/document_entity.dart';
import '../../domain/entities/question_entity.dart';
import '../../domain/entities/question_revision_entity.dart';
import '../../domain/entities/validation_issue_entity.dart';
import '../../domain/repositories/question_bank_repository.dart';
import '../datasources/question_bank_remote_datasource.dart';

class QuestionBankRepositoryImpl implements QuestionBankRepository {
  final QuestionBankRemoteDataSource remoteDataSource;

  QuestionBankRepositoryImpl({required this.remoteDataSource});

  // ── Document-Level Operations ─────────────────────────────────────────────

  @override
  Future<List<DocumentEntity>> getDocuments() {
    return remoteDataSource.getDocuments();
  }

  @override
  Future<DocumentEntity> getDocumentById(String documentId) {
    return remoteDataSource.getDocumentById(documentId);
  }

  @override
  Future<List<QuestionEntity>> getQuestionsByDocument(
    String documentId, {
    String? statusFilter,
  }) {
    return remoteDataSource.getQuestionsByDocument(
      documentId,
      statusFilter: statusFilter,
    );
  }

  @override
  Future<void> deleteDocument(String documentId) {
    return remoteDataSource.deleteDocument(documentId);
  }

  @override
  Future<void> deleteQuestion(String questionId) {
    return remoteDataSource.deleteQuestion(questionId);
  }

  @override
  Future<String> retryDocumentIngestion(String documentId) {
    return remoteDataSource.retryDocumentIngestion(documentId);
  }

  // ── Question-Level Operations ─────────────────────────────────────────────

  @override
  Future<List<QuestionEntity>> getQuestions({
    String? statusFilter,
    bool sortByPriority = false,
  }) {
    return remoteDataSource.getQuestions(
      statusFilter: statusFilter,
      sortByPriority: sortByPriority,
    );
  }

  @override
  Future<QuestionEntity> getQuestionById(String questionId) {
    return remoteDataSource.getQuestionById(questionId);
  }

  @override
  Future<QuestionRevisionEntity?> getLatestRevision(String questionId) {
    return remoteDataSource.getLatestRevision(questionId);
  }

  @override
  Future<List<QuestionRevisionEntity>> getRevisionHistory(String questionId) {
    return remoteDataSource.getRevisionHistory(questionId);
  }

  @override
  Future<List<ValidationIssueEntity>> getValidationIssues(String revisionId) {
    return remoteDataSource.getValidationIssues(revisionId);
  }

  @override
  Future<void> acknowledgeIssue({
    required String revisionId,
    required String issueId,
    String? rationale,
  }) {
    return remoteDataSource.acknowledgeIssue(
      revisionId: revisionId,
      issueId: issueId,
      rationale: rationale,
    );
  }

  @override
  Future<QuestionRevisionEntity> editBlock({
    required String questionId,
    required String blockId,
    required String newValue,
    required String reason,
  }) {
    return remoteDataSource.editBlock(
      questionId: questionId,
      blockId: blockId,
      newValue: newValue,
      reason: reason,
    );
  }

  @override
  Future<QuestionRevisionEntity> selectAnswer({
    required String questionId,
    required String selectedKey,
  }) {
    return remoteDataSource.selectAnswer(
      questionId: questionId,
      selectedKey: selectedKey,
    );
  }

  @override
  Future<void> mergeWithNext({required String questionId}) {
    return remoteDataSource.mergeWithNext(questionId: questionId);
  }

  @override
  Future<void> splitQuestion({
    required String questionId,
    required int splitIndex,
  }) {
    return remoteDataSource.splitQuestion(
      questionId: questionId,
      splitIndex: splitIndex,
    );
  }

  @override
  Future<void> markSourceUnreadable({
    required String questionId,
    required String reason,
  }) {
    return remoteDataSource.markSourceUnreadable(
      questionId: questionId,
      reason: reason,
    );
  }

  @override
  Future<QuestionRevisionEntity> restoreRevision({
    required String questionId,
    required String revisionId,
  }) {
    return remoteDataSource.restoreRevision(
      questionId: questionId,
      revisionId: revisionId,
    );
  }

  @override
  Future<void> sampleSecondReview({required String questionId}) {
    return remoteDataSource.sampleSecondReview(questionId: questionId);
  }

  @override
  Future<String> createManualQuestion({
    required String sourceLabel,
    required String questionType,
    required String stemText,
    required List<Map<String, dynamic>> options,
    required String correctAnswer,
    required Map<String, dynamic> rightsAttestation,
    String? imageUrl,
    Map<String, dynamic>? imageMeta,
  }) {
    return remoteDataSource.createManualQuestion(
      sourceLabel: sourceLabel,
      questionType: questionType,
      stemText: stemText,
      options: options,
      correctAnswer: correctAnswer,
      rightsAttestation: rightsAttestation,
      imageUrl: imageUrl,
      imageMeta: imageMeta,
    );
  }

  @override
  Future<void> approveRevision({
    required String revisionId,
    required String contentHash,
    List<String>? acknowledgedIssueIds,
  }) {
    return remoteDataSource.approveRevision(
      revisionId: revisionId,
      contentHash: contentHash,
      acknowledgedIssueIds: acknowledgedIssueIds,
    );
  }

  @override
  Future<void> publishRevision({required String revisionId}) {
    return remoteDataSource.publishRevision(revisionId: revisionId);
  }

  @override
  Future<List<QuestionEntity>> ingestExamDocument({
    required String filename,
    required List<int> bytes,
    String? answerKeyFilename,
    required Map<String, dynamic> rightsAttestation,
  }) {
    return remoteDataSource.ingestExamDocument(
      filename: filename,
      bytes: bytes,
      answerKeyFilename: answerKeyFilename,
      rightsAttestation: rightsAttestation,
    );
  }

  @override
  Future<String> createExamFromQuestions({
    required String groupId,
    required String title,
    required int durationMinutes,
    required List<QuestionEntity> questions,
  }) {
    return remoteDataSource.createExamFromQuestions(
      groupId: groupId,
      title: title,
      durationMinutes: durationMinutes,
      questions: questions,
    );
  }

  @override
  Future<Map<String, dynamic>> getJobStatus(String jobId) {
    return remoteDataSource.getJobStatus(jobId);
  }
}
