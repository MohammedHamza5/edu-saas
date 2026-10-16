import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/cache_manager.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/question_entity.dart';
import '../../domain/entities/validation_issue_entity.dart';
import '../../domain/repositories/question_bank_repository.dart';
import 'question_bank_state.dart';

class QuestionBankCubit extends Cubit<QuestionBankState> {
  final QuestionBankRepository repository;
  int _documentsPage = 0;
  static const int _documentsPageSize = 20;
  int _documentQuestionsPage = 0;
  static const int _documentQuestionsPageSize = 20;

  QuestionBankCubit({required this.repository})
    : super(const QuestionBankInitial());

  // ══════════════════════════════════════════════════════════════════════════
  // Document-Level Operations
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> loadDocuments({bool forceRefresh = false}) async {
    _documentsPage = 0;
    final cacheKey = AppCache.userKey('qb_docs_page_0');

    if (!forceRefresh) {
      final cached =
          AppCache.questionBank.get(cacheKey) as List<DocumentEntity>?;
      if (cached != null) {
        emit(
          QuestionBankDocumentsLoaded(
            documents: cached,
            hasMore: cached.length >= _documentsPageSize,
            isLoadingMore: false,
          ),
        );
      } else {
        emit(const QuestionBankLoading());
      }
    } else {
      emit(const QuestionBankLoading());
    }

    try {
      final documents = await repository.getDocuments(
        page: 0,
        pageSize: _documentsPageSize,
      );
      AppCache.questionBank.put(cacheKey, documents);
      emit(
        QuestionBankDocumentsLoaded(
          documents: documents,
          hasMore: documents.length >= _documentsPageSize,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      if (state is! QuestionBankDocumentsLoaded) {
        emit(QuestionBankError(e.toString()));
      }
    }
  }

  Future<void> loadMoreDocuments() async {
    final currentState = state;
    if (currentState is! QuestionBankDocumentsLoaded) return;
    if (currentState.isLoadingMore || !currentState.hasMore) return;

    emit(currentState.copyWith(isLoadingMore: true));

    try {
      final nextPage = _documentsPage + 1;
      final newDocs = await repository.getDocuments(
        page: nextPage,
        pageSize: _documentsPageSize,
      );
      _documentsPage = nextPage;
      final updated = [...currentState.documents, ...newDocs];
      emit(
        currentState.copyWith(
          documents: updated,
          hasMore: newDocs.length >= _documentsPageSize,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> loadDocumentQuestions(
    String documentId, {
    String statusFilter = 'all',
  }) async {
    _documentQuestionsPage = 0;
    emit(const QuestionBankLoading());
    try {
      final document = await repository.getDocumentById(documentId);
      final questions = await repository.getQuestionsByDocument(
        documentId,
        statusFilter: statusFilter == 'all' ? null : statusFilter,
        page: 0,
        pageSize: _documentQuestionsPageSize,
      );
      emit(
        QuestionBankDocumentQuestionsLoaded(
          document: document,
          questions: questions,
          selectedFilter: statusFilter,
          hasMore: questions.length >= _documentQuestionsPageSize,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      emit(QuestionBankError(e.toString()));
    }
  }

  Future<void> loadMoreDocumentQuestions() async {
    final currentState = state;
    if (currentState is! QuestionBankDocumentQuestionsLoaded) return;
    if (currentState.isLoadingMore || !currentState.hasMore) return;

    emit(currentState.copyWith(isLoadingMore: true));

    try {
      final nextPage = _documentQuestionsPage + 1;
      final newQuestions = await repository.getQuestionsByDocument(
        currentState.document.id,
        statusFilter: currentState.selectedFilter == 'all'
            ? null
            : currentState.selectedFilter,
        page: nextPage,
        pageSize: _documentQuestionsPageSize,
      );
      _documentQuestionsPage = nextPage;
      final updated = [...currentState.questions, ...newQuestions];
      emit(
        currentState.copyWith(
          questions: updated,
          hasMore: newQuestions.length >= _documentQuestionsPageSize,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> deleteDocument(String documentId) async {
    final currentState = state;
    emit(const QuestionBankLoading());
    try {
      await repository.deleteDocument(documentId);
      AppCache.questionBank.clear();
      // Reload documents list
      final documents = await repository.getDocuments();
      emit(QuestionBankDocumentsLoaded(documents: documents));
    } catch (e) {
      // Try to restore the previous state
      if (currentState is QuestionBankDocumentsLoaded) {
        emit(currentState);
      }
      emit(QuestionBankError(e.toString()));
    }
  }

  Future<void> deleteQuestion(String questionId) async {
    final currentState = state;
    if (currentState is! QuestionBankDocumentQuestionsLoaded) return;

    emit(const QuestionBankLoading());
    try {
      await repository.deleteQuestion(questionId);
      AppCache.questionBank.clear();
      // Reload the document's questions
      final document = await repository.getDocumentById(
        currentState.document.id,
      );
      final questions = await repository.getQuestionsByDocument(
        currentState.document.id,
        statusFilter: currentState.selectedFilter == 'all'
            ? null
            : currentState.selectedFilter,
      );
      emit(
        QuestionBankDocumentQuestionsLoaded(
          document: document,
          questions: questions,
          selectedFilter: currentState.selectedFilter,
        ),
      );
    } catch (e) {
      emit(currentState);
      emit(QuestionBankError(e.toString()));
    }
  }

  Future<void> retryDocumentIngestion(String documentId) async {
    final currentState = state;
    emit(const QuestionBankLoading());
    try {
      await repository.retryDocumentIngestion(documentId);
      AppCache.questionBank.clear();
      // Reload documents list
      final documents = await repository.getDocuments();
      emit(QuestionBankDocumentsLoaded(documents: documents));
    } catch (e) {
      if (currentState is QuestionBankDocumentsLoaded) {
        emit(currentState);
      }
      emit(QuestionBankError(e.toString()));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Question-Level Operations (existing, preserved)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> loadQuestions({
    String statusFilter = 'all',
    bool sortByPriority = false,
  }) async {
    emit(const QuestionBankLoading());
    try {
      final questions = await repository.getQuestions(
        statusFilter: statusFilter == 'all' ? null : statusFilter,
        sortByPriority: sortByPriority,
      );
      emit(
        QuestionBankLoaded(
          questions: questions,
          selectedFilter: statusFilter,
          isSortedByPriority: sortByPriority,
        ),
      );
    } catch (e) {
      emit(QuestionBankError(e.toString()));
    }
  }

  Future<void> loadQuestionReview(String questionId) async {
    emit(const QuestionBankLoading());
    try {
      final question = await repository.getQuestionById(questionId);
      final revision = await repository.getLatestRevision(questionId);
      final history = await repository.getRevisionHistory(questionId);
      final issues = revision != null
          ? await repository.getValidationIssues(revision.id)
          : <ValidationIssueEntity>[];

      emit(
        QuestionBankReviewLoaded(
          question: question,
          revision: revision,
          issues: issues,
          revisionHistory: history,
          acknowledgedIssueIds: const {},
        ),
      );
    } catch (e) {
      emit(QuestionBankError(e.toString()));
    }
  }

  Future<void> acknowledgeIssue(String issueId, {String? rationale}) async {
    final currentState = state;
    if (currentState is! QuestionBankReviewLoaded ||
        currentState.revision == null) {
      return;
    }

    try {
      await repository.acknowledgeIssue(
        revisionId: currentState.revision!.id,
        issueId: issueId,
        rationale: rationale,
      );

      final newAcknowledged = Set<String>.from(
        currentState.acknowledgedIssueIds,
      )..add(issueId);
      emit(
        currentState.copyWith(
          acknowledgedIssueIds: newAcknowledged,
          actionMessage: 'Issue $issueId acknowledged.',
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(actionMessage: 'Failed to acknowledge issue: $e'),
      );
    }
  }

  Future<void> selectAnswer(String selectedKey) async {
    final currentState = state;
    if (currentState is! QuestionBankReviewLoaded) return;

    emit(currentState.copyWith(isActionLoading: true));
    try {
      final newRev = await repository.selectAnswer(
        questionId: currentState.question.id,
        selectedKey: selectedKey,
      );

      final issues = await repository.getValidationIssues(newRev.id);
      final history = await repository.getRevisionHistory(
        currentState.question.id,
      );

      emit(
        currentState.copyWith(
          revision: newRev,
          issues: issues,
          revisionHistory: history,
          isActionLoading: false,
          actionMessage: 'Answer confirmed: $selectedKey',
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(
          isActionLoading: false,
          actionMessage: 'Failed to confirm answer: $e',
        ),
      );
    }
  }

  Future<void> editBlock({
    required String blockId,
    required String newValue,
    required String reason,
  }) async {
    final currentState = state;
    if (currentState is! QuestionBankReviewLoaded) return;

    emit(currentState.copyWith(isActionLoading: true));
    try {
      final newRev = await repository.editBlock(
        questionId: currentState.question.id,
        blockId: blockId,
        newValue: newValue,
        reason: reason,
      );

      final issues = await repository.getValidationIssues(newRev.id);
      final history = await repository.getRevisionHistory(
        currentState.question.id,
      );

      emit(
        currentState.copyWith(
          revision: newRev,
          issues: issues,
          revisionHistory: history,
          isActionLoading: false,
          actionMessage: 'New revision created: rev_no ${newRev.revNo}',
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(
          isActionLoading: false,
          actionMessage: 'Failed to save block edit: $e',
        ),
      );
    }
  }

  Future<void> mergeWithNext() async {
    final currentState = state;
    if (currentState is! QuestionBankReviewLoaded) return;

    emit(currentState.copyWith(isActionLoading: true));
    try {
      await repository.mergeWithNext(questionId: currentState.question.id);
      emit(
        currentState.copyWith(
          isActionLoading: false,
          actionMessage: 'Question merged with next question.',
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(
          isActionLoading: false,
          actionMessage: 'Failed to merge: $e',
        ),
      );
    }
  }

  Future<void> splitQuestion({required int splitIndex}) async {
    final currentState = state;
    if (currentState is! QuestionBankReviewLoaded) return;

    emit(currentState.copyWith(isActionLoading: true));
    try {
      await repository.splitQuestion(
        questionId: currentState.question.id,
        splitIndex: splitIndex,
      );
      emit(
        currentState.copyWith(
          isActionLoading: false,
          actionMessage: 'Question split requested.',
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(
          isActionLoading: false,
          actionMessage: 'Failed to split: $e',
        ),
      );
    }
  }

  Future<void> markSourceUnreadable({required String reason}) async {
    final currentState = state;
    if (currentState is! QuestionBankReviewLoaded) return;

    emit(currentState.copyWith(isActionLoading: true));
    try {
      await repository.markSourceUnreadable(
        questionId: currentState.question.id,
        reason: reason,
      );
      final updatedQ = await repository.getQuestionById(
        currentState.question.id,
      );
      emit(
        currentState.copyWith(
          question: updatedQ,
          isActionLoading: false,
          actionMessage: 'Marked source as unreadable/quarantined.',
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(
          isActionLoading: false,
          actionMessage: 'Failed to mark unreadable: $e',
        ),
      );
    }
  }

  Future<void> restoreRevision(String revisionId) async {
    final currentState = state;
    if (currentState is! QuestionBankReviewLoaded) return;

    emit(currentState.copyWith(isActionLoading: true));
    try {
      final restoredRev = await repository.restoreRevision(
        questionId: currentState.question.id,
        revisionId: revisionId,
      );
      final issues = await repository.getValidationIssues(restoredRev.id);
      final history = await repository.getRevisionHistory(
        currentState.question.id,
      );

      emit(
        currentState.copyWith(
          revision: restoredRev,
          issues: issues,
          revisionHistory: history,
          isActionLoading: false,
          actionMessage: 'Restored revision rev_no ${restoredRev.revNo}',
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(
          isActionLoading: false,
          actionMessage: 'Failed to restore revision: $e',
        ),
      );
    }
  }

  void toggleFastDiffMode() {
    final currentState = state;
    if (currentState is QuestionBankReviewLoaded) {
      emit(currentState.copyWith(isFastDiffMode: !currentState.isFastDiffMode));
    }
  }

  Future<void> sampleSecondReview() async {
    final currentState = state;
    if (currentState is! QuestionBankReviewLoaded) return;

    try {
      await repository.sampleSecondReview(questionId: currentState.question.id);
      final updatedQ = await repository.getQuestionById(
        currentState.question.id,
      );
      emit(
        currentState.copyWith(
          question: updatedQ,
          actionMessage: 'Tagged for second review.',
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(actionMessage: 'Failed to tag second review: $e'),
      );
    }
  }

  Future<String> createManualQuestion({
    required String sourceLabel,
    required String questionType,
    required String stemText,
    required List<Map<String, dynamic>> options,
    required String correctAnswer,
    required Map<String, dynamic> rightsAttestation,
    String? imageUrl,
    Map<String, dynamic>? imageMeta,
  }) async {
    emit(const QuestionBankLoading());
    try {
      final questionId = await repository.createManualQuestion(
        sourceLabel: sourceLabel,
        questionType: questionType,
        stemText: stemText,
        options: options,
        correctAnswer: correctAnswer,
        rightsAttestation: rightsAttestation,
        imageUrl: imageUrl,
        imageMeta: imageMeta,
      );
      AppCache.questionBank.clear();
      emit(
        QuestionBankActionSuccess(
          message: 'Question created successfully',
          questionId: questionId,
        ),
      );
      return questionId;
    } catch (e) {
      emit(QuestionBankError(e.toString()));
      rethrow;
    }
  }

  Future<void> approveRevision({
    required String revisionId,
    required String contentHash,
    List<String>? acknowledgedIssueIds,
  }) async {
    final currentState = state;
    if (currentState is! QuestionBankReviewLoaded) return;

    emit(currentState.copyWith(isActionLoading: true));
    try {
      final ackIds =
          acknowledgedIssueIds ?? currentState.acknowledgedIssueIds.toList();
      await repository.approveRevision(
        revisionId: revisionId,
        contentHash: contentHash,
        acknowledgedIssueIds: ackIds,
      );
      AppCache.questionBank.clear();

      final updatedQuestion = await repository.getQuestionById(
        currentState.question.id,
      );
      final updatedRevision = await repository.getLatestRevision(
        currentState.question.id,
      );
      final issues = updatedRevision != null
          ? await repository.getValidationIssues(updatedRevision.id)
          : currentState.issues;

      emit(
        currentState.copyWith(
          question: updatedQuestion,
          revision: updatedRevision,
          issues: issues,
          isActionLoading: false,
          actionMessage: 'Revision approved successfully',
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(
          isActionLoading: false,
          actionMessage: 'Approval failed: $e',
        ),
      );
    }
  }

  Future<void> publishRevision({required String revisionId}) async {
    final currentState = state;
    if (currentState is! QuestionBankReviewLoaded) return;

    emit(currentState.copyWith(isActionLoading: true));
    try {
      await repository.publishRevision(revisionId: revisionId);
      AppCache.questionBank.clear();

      final updatedQuestion = await repository.getQuestionById(
        currentState.question.id,
      );
      emit(
        currentState.copyWith(
          question: updatedQuestion,
          isActionLoading: false,
          actionMessage: 'Question published successfully',
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(
          isActionLoading: false,
          actionMessage: 'Publish failed: $e',
        ),
      );
    }
  }

  Future<List<QuestionEntity>> ingestExamDocument({
    required String filename,
    required List<int> bytes,
    String? answerKeyFilename,
    required Map<String, dynamic> rightsAttestation,
  }) async {
    final questions = await repository.ingestExamDocument(
      filename: filename,
      bytes: bytes,
      answerKeyFilename: answerKeyFilename,
      rightsAttestation: rightsAttestation,
    );
    AppCache.questionBank.clear();
    // After ingestion, reload documents list and highlight the new one
    emit(const QuestionBankLoading());
    try {
      final documents = await repository.getDocuments();
      // Find the document that was just uploaded (newest with matching filename)
      final matchingDoc = documents.firstWhere(
        (d) => d.originalFilename == filename,
        orElse: () => documents.first,
      );
      emit(
        QuestionBankDocumentsLoaded(
          documents: documents,
          lastUploadedDocumentId: matchingDoc.id,
        ),
      );
    } catch (_) {
      // fallback: just reload normally
      await loadDocuments();
    }
    return questions;
  }

  Future<String> createExamFromQuestions({
    required String groupId,
    required String title,
    required int durationMinutes,
    required List<QuestionEntity> questions,
  }) async {
    return await repository.createExamFromQuestions(
      groupId: groupId,
      title: title,
      durationMinutes: durationMinutes,
      questions: questions,
    );
  }

  /// Called when the teacher dismisses the post-extraction highlight.
  void clearLastUploadHighlight() {
    final cur = state;
    if (cur is QuestionBankDocumentsLoaded &&
        cur.lastUploadedDocumentId != null) {
      emit(cur.copyWith(clearLastUpload: true));
    }
  }

  /// Legacy: clear extraction banner (kept for backward compatibility)
  void clearExtractionBanner() {
    final cur = state;
    if (cur is QuestionBankLoaded && cur.lastExtractionResult != null) {
      emit(cur.copyWith(clearExtractionResult: true));
    }
  }
}
