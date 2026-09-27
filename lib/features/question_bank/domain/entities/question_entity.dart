import 'package:equatable/equatable.dart';

/// Question entity representing a stable question identity across revisions (§7.1, §10).
class QuestionEntity extends Equatable {
  final String id;
  final String tenantId;
  final String? documentId;
  final String? sectionId;
  final String sourceLabel;
  final String questionType;
  final String status;
  final String? currentPublishedRevisionId;
  final double priorityScore;
  final String policyState;
  final String? duplicateClusterId;
  final bool requiresSecondReview;
  final DateTime createdAt;
  final DateTime updatedAt;

  const QuestionEntity({
    required this.id,
    required this.tenantId,
    this.documentId,
    this.sectionId,
    required this.sourceLabel,
    required this.questionType,
    required this.status,
    this.currentPublishedRevisionId,
    this.priorityScore = 0.0,
    this.policyState = 'REVIEW_FAST',
    this.duplicateClusterId,
    this.requiresSecondReview = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPublished => status == 'published';
  bool get isApproved => status == 'approved';
  bool get isReviewRequired =>
      status == 'review_required' || status == 'extracted';
  bool get isQuarantined =>
      status == 'quarantined' || policyState == 'SOURCE_UNREADABLE';

  QuestionEntity copyWith({
    String? id,
    String? tenantId,
    String? documentId,
    String? sectionId,
    String? sourceLabel,
    String? questionType,
    String? status,
    String? currentPublishedRevisionId,
    double? priorityScore,
    String? policyState,
    String? duplicateClusterId,
    bool? requiresSecondReview,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuestionEntity(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      documentId: documentId ?? this.documentId,
      sectionId: sectionId ?? this.sectionId,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      questionType: questionType ?? this.questionType,
      status: status ?? this.status,
      currentPublishedRevisionId:
          currentPublishedRevisionId ?? this.currentPublishedRevisionId,
      priorityScore: priorityScore ?? this.priorityScore,
      policyState: policyState ?? this.policyState,
      duplicateClusterId: duplicateClusterId ?? this.duplicateClusterId,
      requiresSecondReview: requiresSecondReview ?? this.requiresSecondReview,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tenantId,
    documentId,
    sectionId,
    sourceLabel,
    questionType,
    status,
    currentPublishedRevisionId,
    priorityScore,
    policyState,
    duplicateClusterId,
    requiresSecondReview,
    createdAt,
    updatedAt,
  ];
}
