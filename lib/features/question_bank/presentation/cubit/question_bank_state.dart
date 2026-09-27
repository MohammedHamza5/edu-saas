import 'package:equatable/equatable.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/question_entity.dart';
import '../../domain/entities/question_revision_entity.dart';
import '../../domain/entities/validation_issue_entity.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Base State
// ══════════════════════════════════════════════════════════════════════════════

abstract class QuestionBankState extends Equatable {
  const QuestionBankState();

  @override
  List<Object?> get props => [];
}

class QuestionBankInitial extends QuestionBankState {
  const QuestionBankInitial();
}

class QuestionBankLoading extends QuestionBankState {
  const QuestionBankLoading();
}

class QuestionBankError extends QuestionBankState {
  final String message;

  const QuestionBankError(this.message);

  @override
  List<Object?> get props => [message];
}

class QuestionBankActionSuccess extends QuestionBankState {
  final String message;
  final String? questionId;

  const QuestionBankActionSuccess({required this.message, this.questionId});

  @override
  List<Object?> get props => [message, questionId];
}

// ══════════════════════════════════════════════════════════════════════════════
// Documents List State (main screen)
// ══════════════════════════════════════════════════════════════════════════════

class QuestionBankDocumentsLoaded extends QuestionBankState {
  final List<DocumentEntity> documents;

  /// Non-null when the page just completed an extraction — drives the highlight.
  final String? lastUploadedDocumentId;

  const QuestionBankDocumentsLoaded({
    required this.documents,
    this.lastUploadedDocumentId,
  });

  QuestionBankDocumentsLoaded copyWith({
    List<DocumentEntity>? documents,
    String? lastUploadedDocumentId,
    bool clearLastUpload = false,
  }) {
    return QuestionBankDocumentsLoaded(
      documents: documents ?? this.documents,
      lastUploadedDocumentId: clearLastUpload
          ? null
          : (lastUploadedDocumentId ?? this.lastUploadedDocumentId),
    );
  }

  int get totalQuestions =>
      documents.fold(0, (sum, d) => sum + d.questionCount);
  int get doneCount => documents.where((d) => d.isDone).length;
  int get pendingCount =>
      documents.where((d) => d.isPending || d.isProcessing).length;
  int get failedCount => documents.where((d) => d.isFailed).length;

  @override
  List<Object?> get props => [documents, lastUploadedDocumentId];
}

// ══════════════════════════════════════════════════════════════════════════════
// Document Questions State (drill-down screen)
// ══════════════════════════════════════════════════════════════════════════════

class QuestionBankDocumentQuestionsLoaded extends QuestionBankState {
  final DocumentEntity document;
  final List<QuestionEntity> questions;
  final String selectedFilter;

  const QuestionBankDocumentQuestionsLoaded({
    required this.document,
    required this.questions,
    this.selectedFilter = 'all',
  });

  QuestionBankDocumentQuestionsLoaded copyWith({
    DocumentEntity? document,
    List<QuestionEntity>? questions,
    String? selectedFilter,
  }) {
    return QuestionBankDocumentQuestionsLoaded(
      document: document ?? this.document,
      questions: questions ?? this.questions,
      selectedFilter: selectedFilter ?? this.selectedFilter,
    );
  }

  int get extractedCount =>
      questions.where((q) => q.status == 'extracted').length;
  int get reviewCount =>
      questions.where((q) => q.status == 'review_required').length;
  int get approvedCount =>
      questions.where((q) => q.status == 'approved').length;
  int get publishedCount =>
      questions.where((q) => q.status == 'published').length;
  int get quarantinedCount =>
      questions.where((q) => q.status == 'quarantined').length;

  @override
  List<Object?> get props => [document, questions, selectedFilter];
}

// ══════════════════════════════════════════════════════════════════════════════
// Legacy: Questions flat list (kept for backward compatibility)
// ══════════════════════════════════════════════════════════════════════════════

/// Carries the result of the last PDF extraction so the page can show
/// a prominent banner immediately after the upload dialog closes.
class LastExtractionResult extends Equatable {
  final int count;
  final String filename;
  const LastExtractionResult({required this.count, required this.filename});
  @override
  List<Object?> get props => [count, filename];
}

class QuestionBankLoaded extends QuestionBankState {
  final List<QuestionEntity> questions;
  final String selectedFilter;
  final bool isSortedByPriority;

  /// Non-null when the page just completed an extraction — drives the banner.
  final LastExtractionResult? lastExtractionResult;

  const QuestionBankLoaded({
    required this.questions,
    this.selectedFilter = 'all',
    this.isSortedByPriority = false,
    this.lastExtractionResult,
  });

  QuestionBankLoaded copyWith({
    List<QuestionEntity>? questions,
    String? selectedFilter,
    bool? isSortedByPriority,
    LastExtractionResult? lastExtractionResult,
    bool clearExtractionResult = false,
  }) {
    return QuestionBankLoaded(
      questions: questions ?? this.questions,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      isSortedByPriority: isSortedByPriority ?? this.isSortedByPriority,
      lastExtractionResult: clearExtractionResult
          ? null
          : (lastExtractionResult ?? this.lastExtractionResult),
    );
  }

  @override
  List<Object?> get props => [
    questions,
    selectedFilter,
    isSortedByPriority,
    lastExtractionResult,
  ];
}

// ══════════════════════════════════════════════════════════════════════════════
// Review Console State
// ══════════════════════════════════════════════════════════════════════════════

class QuestionBankReviewLoaded extends QuestionBankState {
  final QuestionEntity question;
  final QuestionRevisionEntity? revision;
  final List<ValidationIssueEntity> issues;
  final Set<String> acknowledgedIssueIds;
  final List<QuestionRevisionEntity> revisionHistory;
  final QuestionEntity? peerDuplicateQuestion;
  final bool isFastDiffMode;
  final bool isActionLoading;
  final String? actionMessage;

  const QuestionBankReviewLoaded({
    required this.question,
    this.revision,
    this.issues = const [],
    this.acknowledgedIssueIds = const {},
    this.revisionHistory = const [],
    this.peerDuplicateQuestion,
    this.isFastDiffMode = false,
    this.isActionLoading = false,
    this.actionMessage,
  });

  /// Blockers that are neither resolved in DB nor acknowledged by teacher in this review session
  bool get hasBlockers => issues.any(
    (i) => i.isBlocker && !i.isResolved && !acknowledgedIssueIds.contains(i.id),
  );

  QuestionBankReviewLoaded copyWith({
    QuestionEntity? question,
    QuestionRevisionEntity? revision,
    List<ValidationIssueEntity>? issues,
    Set<String>? acknowledgedIssueIds,
    List<QuestionRevisionEntity>? revisionHistory,
    QuestionEntity? peerDuplicateQuestion,
    bool? isFastDiffMode,
    bool? isActionLoading,
    String? actionMessage,
  }) {
    return QuestionBankReviewLoaded(
      question: question ?? this.question,
      revision: revision ?? this.revision,
      issues: issues ?? this.issues,
      acknowledgedIssueIds: acknowledgedIssueIds ?? this.acknowledgedIssueIds,
      revisionHistory: revisionHistory ?? this.revisionHistory,
      peerDuplicateQuestion:
          peerDuplicateQuestion ?? this.peerDuplicateQuestion,
      isFastDiffMode: isFastDiffMode ?? this.isFastDiffMode,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [
    question,
    revision,
    issues,
    acknowledgedIssueIds,
    revisionHistory,
    peerDuplicateQuestion,
    isFastDiffMode,
    isActionLoading,
    actionMessage,
  ];
}
