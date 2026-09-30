import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/features/question_bank/domain/entities/document_entity.dart';
import 'package:edu_saas/features/question_bank/domain/entities/question_entity.dart';
import 'package:edu_saas/features/question_bank/domain/entities/question_revision_entity.dart';
import 'package:edu_saas/features/question_bank/domain/entities/validation_issue_entity.dart';
import 'package:edu_saas/features/question_bank/domain/repositories/question_bank_repository.dart';
import 'package:edu_saas/features/question_bank/presentation/cubit/question_bank_cubit.dart';
import 'package:edu_saas/features/question_bank/presentation/pages/question_bank_page.dart';

class _MockQuestionBankRepository implements QuestionBankRepository {
  final List<QuestionEntity> sampleQuestions;
  final List<DocumentEntity> sampleDocuments;

  _MockQuestionBankRepository(this.sampleQuestions, this.sampleDocuments);

  @override
  Future<List<DocumentEntity>> getDocuments() async => sampleDocuments;

  @override
  Future<DocumentEntity> getDocumentById(String documentId) async =>
      sampleDocuments.firstWhere((d) => d.id == documentId);

  @override
  Future<List<QuestionEntity>> getQuestionsByDocument(
    String documentId, {
    String? statusFilter,
  }) async => sampleQuestions;

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
    var result = List<QuestionEntity>.from(sampleQuestions);
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
    return sampleQuestions.firstWhere((q) => q.id == questionId);
  }

  @override
  Future<QuestionRevisionEntity?> getLatestRevision(String questionId) async =>
      null;

  @override
  Future<List<QuestionRevisionEntity>> getRevisionHistory(
    String questionId,
  ) async => [];

  @override
  Future<List<ValidationIssueEntity>> getValidationIssues(
    String revisionId,
  ) async => [];

  @override
  Future<void> acknowledgeIssue({
    required String revisionId,
    required String issueId,
    String? rationale,
  }) async {}

  @override
  Future<QuestionRevisionEntity> editBlock({
    required String questionId,
    required String blockId,
    required String newValue,
    required String reason,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<QuestionRevisionEntity> selectAnswer({
    required String questionId,
    required String selectedKey,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> mergeWithNext({required String questionId}) async {}

  @override
  Future<void> splitQuestion({
    required String questionId,
    required int splitIndex,
  }) async {}

  @override
  Future<void> markSourceUnreadable({
    required String questionId,
    required String reason,
  }) async {}

  @override
  Future<QuestionRevisionEntity> restoreRevision({
    required String questionId,
    required String revisionId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> sampleSecondReview({required String questionId}) async {}

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
  }) async => 'new-q-id';

  @override
  Future<void> approveRevision({
    required String revisionId,
    required String contentHash,
    List<String>? acknowledgedIssueIds,
  }) async {}

  @override
  Future<void> publishRevision({required String revisionId}) async {}

  @override
  Future<List<QuestionEntity>> ingestExamDocument({
    required String filename,
    required List<int> bytes,
    String? answerKeyFilename,
    required Map<String, dynamic> rightsAttestation,
  }) async => sampleQuestions;

  @override
  Future<String> createExamFromQuestions({
    required String groupId,
    required String title,
    required int durationMinutes,
    required List<QuestionEntity> questions,
  }) async => 'mock-exam-id';

  @override
  Future<Map<String, dynamic>> getJobStatus(String jobId) async => {
    'id': jobId,
    'status': 'done',
    'created_count': 1,
  };
}

void main() {
  final testQuestions = [
    QuestionEntity(
      id: 'q-1',
      tenantId: 'tenant-1',
      sourceLabel: 'SAT-M-2023-OCT-Q14',
      questionType: 'multiple_choice',
      status: 'published',
      priorityScore: 0.0,
      createdAt: DateTime(2026, 9, 20),
      updatedAt: DateTime(2026, 9, 20),
    ),
  ];

  final testDocuments = [
    DocumentEntity(
      id: 'doc-1',
      tenantId: 'tenant-1',
      originalFilename: 'SAT_Exam_Oct_2023.pdf',
      status: 'done',
      questionCount: 45,
      pageCount: 12,
      sizeBytes: 2048000,
      createdAt: DateTime(2026, 9, 20),
    ),
    DocumentEntity(
      id: 'doc-2',
      tenantId: 'tenant-1',
      originalFilename: 'EST_Math_2024.pdf',
      status: 'failed',
      questionCount: 0,
      pageCount: 8,
      sizeBytes: 1024000,
      createdAt: DateTime(2026, 9, 21),
    ),
  ];

  late _MockQuestionBankRepository repository;
  late QuestionBankCubit cubit;

  setUp(() {
    repository = _MockQuestionBankRepository(testQuestions, testDocuments);
    cubit = QuestionBankCubit(repository: repository);
  });

  tearDown(() {
    cubit.close();
  });

  Widget buildTestApp() {
    return BlocProvider<QuestionBankCubit>.value(
      value: cubit,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ar'),
        theme: AppTheme.lightTheme,
        home: const QuestionBankPage(),
      ),
    );
  }

  group('QuestionBankPage Multi-Device Responsive Tests', () {
    testWidgets(
      'Renders cleanly on Extra Small Mobile (360x640) with zero overflow',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(360, 640);
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('بنك الأسئلة'), findsWidgets);
        expect(find.textContaining('SAT/EST'), findsOneWidget);
        expect(find.textContaining('إجمالي المستندات'), findsOneWidget);
      },
    );

    testWidgets(
      'Renders cleanly on Standard Mobile (390x844) with zero overflow',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('SAT Exam Oct 2023'), findsOneWidget);
        expect(find.textContaining('إجمالي الأسئلة'), findsOneWidget);
        expect(find.textContaining('مكتمل'), findsWidgets);
      },
    );

    testWidgets('Renders cleanly on Tablet Portrait (768x1024)', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(768, 1024);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('بنك الأسئلة'), findsWidgets);
      expect(find.textContaining('رفع ملف امتحان'), findsOneWidget);
      expect(find.textContaining('إدخال سؤال يدوي'), findsOneWidget);
    });

    testWidgets(
      'Renders cleanly on Desktop/Laptop (1440x900)',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1440, 900);
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('SAT Exam Oct 2023'), findsOneWidget);
        expect(find.textContaining('EST Math 2024'), findsOneWidget);
      },
    );

    testWidgets('Renders cleanly on 1080p Desktop (1920x1080)', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1920, 1080);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('بنك الأسئلة'), findsWidgets);
      expect(find.textContaining('عرض الأسئلة'), findsWidgets);
    });
  });
}
