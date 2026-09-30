import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/features/question_bank/domain/entities/document_entity.dart';
import 'package:edu_saas/features/question_bank/domain/entities/question_entity.dart';
import 'package:edu_saas/features/question_bank/domain/entities/question_revision_entity.dart';
import 'package:edu_saas/features/question_bank/domain/entities/validation_issue_entity.dart';
import 'package:edu_saas/features/question_bank/domain/repositories/question_bank_repository.dart';
import 'package:edu_saas/features/question_bank/presentation/cubit/question_bank_cubit.dart';
import 'package:edu_saas/features/question_bank/presentation/cubit/question_bank_state.dart';

class MockQuestionBankRepository implements QuestionBankRepository {
  List<QuestionEntity> questions = [];
  QuestionRevisionEntity? latestRevision;
  List<QuestionRevisionEntity> revisionsHistory = [];
  List<ValidationIssueEntity> issues = [];
  bool approveCalled = false;
  bool publishCalled = false;
  bool acknowledgeCalled = false;
  bool mergeCalled = false;
  bool splitCalled = false;
  bool unreadableCalled = false;
  bool secondReviewCalled = false;

  @override
  Future<List<DocumentEntity>> getDocuments() async => [];

  @override
  Future<DocumentEntity> getDocumentById(String documentId) async =>
      throw UnimplementedError();

  @override
  Future<List<QuestionEntity>> getQuestionsByDocument(
    String documentId, {
    String? statusFilter,
  }) async => [];

  @override
  Future<void> deleteDocument(String documentId) async {}

  @override
  Future<void> deleteQuestion(String questionId) async {}

  @override
  Future<String> retryDocumentIngestion(String documentId) async => 'job-1';

  @override
  Future<List<QuestionEntity>> getQuestions({
    String? statusFilter,
    bool sortByPriority = false,
  }) async {
    var result = List<QuestionEntity>.from(questions);
    if (statusFilter != null && statusFilter != 'all') {
      result = result.where((q) => q.status == statusFilter).toList();
    }
    if (sortByPriority) {
      result.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
    }
    return result;
  }

  @override
  Future<QuestionEntity> getQuestionById(String questionId) async {
    return questions.firstWhere((q) => q.id == questionId);
  }

  @override
  Future<QuestionRevisionEntity?> getLatestRevision(String questionId) async {
    return latestRevision;
  }

  @override
  Future<List<QuestionRevisionEntity>> getRevisionHistory(
    String questionId,
  ) async {
    return revisionsHistory;
  }

  @override
  Future<List<ValidationIssueEntity>> getValidationIssues(
    String revisionId,
  ) async {
    return issues;
  }

  @override
  Future<void> acknowledgeIssue({
    required String revisionId,
    required String issueId,
    String? rationale,
  }) async {
    acknowledgeCalled = true;
    for (int i = 0; i < issues.length; i++) {
      if (issues[i].id == issueId) {
        issues[i] = ValidationIssueEntity(
          id: issues[i].id,
          ruleId: issues[i].ruleId,
          severity: issues[i].severity,
          message: issues[i].message,
          resolvableBy: issues[i].resolvableBy,
          resolvedAt: DateTime.now(),
          resolvedBy: 'mock-teacher',
        );
      }
    }
  }

  @override
  Future<QuestionRevisionEntity> editBlock({
    required String questionId,
    required String blockId,
    required String newValue,
    required String reason,
  }) async {
    final current = latestRevision!;
    final newRev = QuestionRevisionEntity(
      id: 'rev-edited',
      questionId: questionId,
      tenantId: current.tenantId,
      revNo: current.revNo + 1,
      content: {
        'stem': [
          {
            'id': blockId,
            'type': 'text',
            'value': newValue,
            'source_refs': ['mock'],
          },
        ],
        'options': current.options,
      },
      answer: current.answer,
      confidence: current.confidence,
      provenance: {'stage': 'mock_edit'},
      contentHash: 'hash-edited',
      createdVia: 'teacher_edit',
      editNote: reason,
      createdAt: DateTime.now(),
    );
    latestRevision = newRev;
    revisionsHistory.insert(0, newRev);
    return newRev;
  }

  @override
  Future<QuestionRevisionEntity> selectAnswer({
    required String questionId,
    required String selectedKey,
  }) async {
    final current = latestRevision!;
    final newRev = QuestionRevisionEntity(
      id: 'rev-answer-confirmed',
      questionId: questionId,
      tenantId: current.tenantId,
      revNo: current.revNo + 1,
      content: current.content,
      answer: {
        'status': 'teacher_confirmed',
        'raw': selectedKey,
        'normalized': selectedKey,
      },
      confidence: current.confidence,
      provenance: {'stage': 'answer_confirmed'},
      contentHash: current.contentHash,
      createdVia: 'teacher_edit',
      editNote: 'Teacher confirmed answer $selectedKey',
      createdAt: DateTime.now(),
    );
    latestRevision = newRev;
    revisionsHistory.insert(0, newRev);
    return newRev;
  }

  @override
  Future<void> mergeWithNext({required String questionId}) async {
    mergeCalled = true;
  }

  @override
  Future<void> splitQuestion({
    required String questionId,
    required int splitIndex,
  }) async {
    splitCalled = true;
  }

  @override
  Future<void> markSourceUnreadable({
    required String questionId,
    required String reason,
  }) async {
    unreadableCalled = true;
    final q = questions.firstWhere((item) => item.id == questionId);
    final idx = questions.indexOf(q);
    questions[idx] = q.copyWith(
      status: 'quarantined',
      policyState: 'SOURCE_UNREADABLE',
    );
  }

  @override
  Future<QuestionRevisionEntity> restoreRevision({
    required String questionId,
    required String revisionId,
  }) async {
    final target = revisionsHistory.firstWhere((r) => r.id == revisionId);
    final current = latestRevision!;
    final restoredRev = QuestionRevisionEntity(
      id: 'rev-restored',
      questionId: questionId,
      tenantId: target.tenantId,
      revNo: current.revNo + 1,
      content: target.content,
      answer: target.answer,
      confidence: target.confidence,
      provenance: target.provenance,
      contentHash: target.contentHash,
      createdVia: 'teacher_edit',
      editNote: 'Restored from rev ${target.revNo}',
      createdAt: DateTime.now(),
    );
    latestRevision = restoredRev;
    revisionsHistory.insert(0, restoredRev);
    return restoredRev;
  }

  @override
  Future<void> sampleSecondReview({required String questionId}) async {
    secondReviewCalled = true;
    final q = questions.firstWhere((item) => item.id == questionId);
    final idx = questions.indexOf(q);
    questions[idx] = q.copyWith(requiresSecondReview: true);
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
  }) async {
    const newId = 'q-new-1';
    final question = QuestionEntity(
      id: newId,
      tenantId: 'tenant-1',
      sourceLabel: sourceLabel,
      questionType: questionType,
      status: 'review_required',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    questions.add(question);
    return newId;
  }

  @override
  Future<void> approveRevision({
    required String revisionId,
    required String contentHash,
    List<String>? acknowledgedIssueIds,
  }) async {
    approveCalled = true;
    final q = questions.first;
    questions[0] = QuestionEntity(
      id: q.id,
      tenantId: q.tenantId,
      sourceLabel: q.sourceLabel,
      questionType: q.questionType,
      status: 'approved',
      createdAt: q.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> publishRevision({required String revisionId}) async {
    publishCalled = true;
    final q = questions.first;
    questions[0] = QuestionEntity(
      id: q.id,
      tenantId: q.tenantId,
      sourceLabel: q.sourceLabel,
      questionType: q.questionType,
      status: 'published',
      currentPublishedRevisionId: revisionId,
      createdAt: q.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<QuestionEntity>> ingestExamDocument({
    required String filename,
    required List<int> bytes,
    String? answerKeyFilename,
    required Map<String, dynamic> rightsAttestation,
  }) async {
    final q = QuestionEntity(
      id: 'q-ingested-1',
      tenantId: 'tenant-1',
      sourceLabel: '$filename - Q1',
      questionType: 'multiple_choice',
      status: 'review_required',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    questions.add(q);
    return [q];
  }

  @override
  Future<String> createExamFromQuestions({
    required String groupId,
    required String title,
    required int durationMinutes,
    required List<QuestionEntity> questions,
  }) async {
    return 'exam-mock-123';
  }

  @override
  Future<Map<String, dynamic>> getJobStatus(String jobId) async {
    return {'id': jobId, 'status': 'done', 'created_count': 1};
  }
}

void main() {
  late MockQuestionBankRepository repository;
  late QuestionBankCubit cubit;

  setUp(() {
    repository = MockQuestionBankRepository();
    cubit = QuestionBankCubit(repository: repository);

    repository.questions = [
      QuestionEntity(
        id: 'q-101',
        tenantId: 'tenant-1',
        sourceLabel: 'Q1',
        questionType: 'multiple_choice',
        status: 'review_required',
        priorityScore: 30.0,
        policyState: 'BLOCKED',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    repository.latestRevision = QuestionRevisionEntity(
      id: 'rev-1',
      questionId: 'q-101',
      tenantId: 'tenant-1',
      revNo: 1,
      content: {
        'stem': [
          {
            'id': 'b1',
            'type': 'text',
            'value': 'Calculate 2+2',
            'source_refs': ['ev-1'],
          },
        ],
        'options': [
          {
            'key': 'A',
            'content': [
              {'type': 'text', 'value': '4'},
            ],
            'source_refs': ['ev-1'],
          },
          {
            'key': 'B',
            'content': [
              {'type': 'text', 'value': '5'},
            ],
            'source_refs': ['ev-1'],
          },
        ],
      },
      answer: {'status': 'unknown', 'raw': null},
      provenance: {'stage': 'ocr'},
      contentHash: 'hash-abc-123',
      createdAt: DateTime.now(),
    );

    repository.revisionsHistory = [repository.latestRevision!];
  });

  tearDown(() {
    cubit.close();
  });

  group('QuestionBank Entities Tests', () {
    test('QuestionEntity status getters work accurately', () {
      final q = QuestionEntity(
        id: 'q-1',
        tenantId: 't-1',
        sourceLabel: 'M1-Q1',
        questionType: 'multiple_choice',
        status: 'published',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(q.isPublished, true);
      expect(q.isApproved, false);
      expect(q.isReviewRequired, false);
    });

    test('QuestionRevisionEntity parses stemText and options correctly', () {
      final rev = QuestionRevisionEntity(
        id: 'r-1',
        questionId: 'q-1',
        tenantId: 't-1',
        revNo: 1,
        content: {
          'stem': [
            {'type': 'text', 'value': 'Solve equation:'},
            {'type': 'math', 'latex': 'x^2 = 4'},
          ],
          'options': [
            {
              'key': 'A',
              'content': [
                {'value': '2'},
              ],
            },
          ],
        },
        answer: {'status': 'source_extracted', 'raw': 'A'},
        provenance: {},
        contentHash: 'hash-123',
        createdAt: DateTime.now(),
      );

      expect(rev.stemText, 'Solve equation: \$x^2 = 4\$');
      expect(rev.options.length, 1);
      expect(rev.answerStatus, 'source_extracted');
      expect(rev.answerKey, 'A');
    });

    test('ValidationIssueEntity localized message and blocker flags work', () {
      const issue = ValidationIssueEntity(
        id: 'iss-1',
        ruleId: 'B-041',
        severity: 'BLOCKER',
        message: {'en': 'Answer Conflict', 'ar': 'تعارض في الإجابة'},
        resolvableBy: 'confirm',
      );

      expect(issue.isBlocker, true);
      expect(issue.isResolved, false);
      expect(issue.getLocalizedMessage('ar'), 'تعارض في الإجابة');
      expect(issue.getLocalizedMessage('en'), 'Answer Conflict');
    });
  });

  group('QuestionBankCubit Tests', () {
    test('initial state is QuestionBankInitial', () {
      expect(cubit.state, isA<QuestionBankInitial>());
    });

    test('loadQuestions loads and filters questions properly', () async {
      await cubit.loadQuestions();
      expect(cubit.state, isA<QuestionBankLoaded>());
      final loaded = cubit.state as QuestionBankLoaded;
      expect(loaded.questions.length, 1);
    });

    test(
      'loadQuestionReview loads question, latest revision, and issues',
      () async {
        await cubit.loadQuestionReview('q-101');
        expect(cubit.state, isA<QuestionBankReviewLoaded>());
        final review = cubit.state as QuestionBankReviewLoaded;
        expect(review.question.id, 'q-101');
        expect(review.revision?.id, 'rev-1');
        expect(review.hasBlockers, false);
      },
    );

    test(
      'hasBlockers is true when an unresolved blocker issue is present',
      () async {
        repository.issues = [
          const ValidationIssueEntity(
            id: 'i-1',
            ruleId: 'B-020',
            severity: 'BLOCKER',
            message: {'en': 'Reader disagreement'},
          ),
        ];

        await cubit.loadQuestionReview('q-101');
        final review = cubit.state as QuestionBankReviewLoaded;
        expect(review.hasBlockers, true);
      },
    );

    test(
      'acknowledgeIssue resolves blocker and unblocks approve action',
      () async {
        repository.issues = [
          const ValidationIssueEntity(
            id: 'i-conf',
            ruleId: 'B-041',
            severity: 'BLOCKER',
            message: {'en': 'Answer conflict'},
            resolvableBy: 'confirm',
          ),
        ];

        await cubit.loadQuestionReview('q-101');
        var review = cubit.state as QuestionBankReviewLoaded;
        expect(review.hasBlockers, true);

        // Acknowledge the issue
        await cubit.acknowledgeIssue('i-conf');
        expect(repository.acknowledgeCalled, true);
        review = cubit.state as QuestionBankReviewLoaded;
        expect(review.acknowledgedIssueIds.contains('i-conf'), true);
        expect(review.hasBlockers, false); // Blockers unblocked!
      },
    );

    test(
      'selectAnswer creates new revision with teacher_confirmed status',
      () async {
        await cubit.loadQuestionReview('q-101');
        await cubit.selectAnswer('A');

        final review = cubit.state as QuestionBankReviewLoaded;
        expect(review.revision?.answerStatus, 'teacher_confirmed');
        expect(review.revision?.answerKey, 'A');
        expect(review.revision?.revNo, 2);
      },
    );

    test(
      'editBlock creates new immutable revision with incremented rev_no',
      () async {
        await cubit.loadQuestionReview('q-101');
        await cubit.editBlock(
          blockId: 'b1',
          newValue: 'Calculate 2+2=4',
          reason: 'ocr_error',
        );

        final review = cubit.state as QuestionBankReviewLoaded;
        expect(review.revision?.revNo, 2);
        expect(review.revision?.editNote, 'ocr_error');
      },
    );

    test(
      'toggleFastDiffMode switches between standard and diff overlay view',
      () async {
        await cubit.loadQuestionReview('q-101');
        var review = cubit.state as QuestionBankReviewLoaded;
        expect(review.isFastDiffMode, false);

        cubit.toggleFastDiffMode();
        review = cubit.state as QuestionBankReviewLoaded;
        expect(review.isFastDiffMode, true);

        cubit.toggleFastDiffMode();
        review = cubit.state as QuestionBankReviewLoaded;
        expect(review.isFastDiffMode, false);
      },
    );

    test(
      'mergeWithNext, splitQuestion, markSourceUnreadable invoke repository methods',
      () async {
        await cubit.loadQuestionReview('q-101');
        await cubit.mergeWithNext();
        expect(repository.mergeCalled, true);

        await cubit.splitQuestion(splitIndex: 1);
        expect(repository.splitCalled, true);

        await cubit.markSourceUnreadable(reason: 'Ink truncated');
        expect(repository.unreadableCalled, true);
      },
    );

    test(
      'createManualQuestion adds new question and emits ActionSuccess',
      () async {
        final id = await cubit.createManualQuestion(
          sourceLabel: 'Q2',
          questionType: 'multiple_choice',
          stemText: 'Solve for x: 2x = 10',
          options: [
            {'key': 'A', 'text': '5'},
            {'key': 'B', 'text': '10'},
          ],
          correctAnswer: 'A',
          rightsAttestation: {'license': 'teacher_owned'},
        );

        expect(id, 'q-new-1');
        expect(cubit.state, isA<QuestionBankActionSuccess>());
      },
    );

    test(
      'approveRevision calls repository and updates question status to approved',
      () async {
        await cubit.loadQuestionReview('q-101');
        await cubit.approveRevision(
          revisionId: 'rev-1',
          contentHash: 'hash-abc-123',
        );

        expect(repository.approveCalled, true);
        expect(cubit.state, isA<QuestionBankReviewLoaded>());
        final review = cubit.state as QuestionBankReviewLoaded;
        expect(review.question.status, 'approved');
      },
    );

    test(
      'publishRevision triggers publish and updates question status to published',
      () async {
        await cubit.loadQuestionReview('q-101');
        await cubit.publishRevision(revisionId: 'rev-1');

        expect(repository.publishCalled, true);
        expect(cubit.state, isA<QuestionBankReviewLoaded>());
        final review = cubit.state as QuestionBankReviewLoaded;
        expect(review.question.status, 'published');
      },
    );
  });
}
