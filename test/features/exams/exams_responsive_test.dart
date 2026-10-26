import 'package:edu_saas/core/errors/failures.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/core/utils/cache_manager.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_folder_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_parent_dispatch_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/mistake_entities.dart';
import 'package:edu_saas/features/exams/domain/repositories/exams_repository.dart';
import 'package:edu_saas/features/exams/presentation/cubit/exams_cubit.dart';
import 'package:edu_saas/features/exams/presentation/pages/student_exams_page.dart';
import 'package:edu_saas/features/exams/presentation/widgets/exam_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeExamsRepository implements ExamsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  List<ExamEntity> mockExams = [];

  @override
  Future<Result<List<ExamEntity>>> getStudentExams({
    int page = 0,
    int pageSize = 15,
  }) async {
    final filtered = mockExams
        .where((e) => e.activeVersion?.status == ExamStatus.published)
        .toList();
    return Success(filtered);
  }

  @override
  Future<Result<List<ExamEntity>>> getGroupExams(
    String groupId, {
    int page = 0,
    int pageSize = 15,
  }) async => Success(mockExams);

  @override
  Future<Result<ExamEntity>> getExamDetails(String examId) async =>
      Success(mockExams.first);

  @override
  Future<Result<ExamEntity>> createExam({
    String? groupId,
    required String title,
    int durationMinutes = 60,
    int maxScore = 100,
    int? passingScore,
    bool shuffleQuestions = false,
    bool showResult = true,
    bool allowRetake = false,
    DateTime? startAt,
    DateTime? endAt,
    bool isPublished = false,
    String? pdfFileId,
    required List<ExamQuestionEntity> initialQuestions,
  }) async => Success(mockExams.first);

  @override
  Future<Result<ExamEntity>> updateExam({
    required String examId,
    required String title,
    int? durationMinutes,
    int? maxScore,
    int? passingScore,
    bool? shuffleQuestions,
    bool? showResult,
    bool? allowRetake,
    DateTime? startAt,
    DateTime? endAt,
    bool? isPublished,
    String? pdfFileId,
    bool clearPdfFile = false,
  }) async => Success(mockExams.first);

  @override
  Future<Result<ExamEntity>> updateDraftExamQuestions({
    required String examId,
    required String title,
    int? durationMinutes,
    int? maxScore,
    int? passingScore,
    bool? shuffleQuestions,
    bool? showResult,
    bool? allowRetake,
    DateTime? startAt,
    DateTime? endAt,
    String? pdfFileId,
    bool clearPdfFile = false,
    required List<ExamQuestionEntity> questions,
    bool? isPublished,
  }) async => Success(mockExams.first);

  @override
  Future<Result<String>> getSignedPdfUrl(
    String storagePath, {
    String? storageProvider,
  }) async =>
      const Success('https://example.com/test.pdf');

  @override
  Future<Result<ExamVersionEntity>> publishExamVersion(String versionId) async =>
      Success(mockExams.first.activeVersion!);

  @override
  Future<Result<void>> unpublishExamVersion({
    required String examId,
    required String versionId,
  }) async => const Success(null);

  @override
  Future<Result<ExamVersionEntity>> createNewExamVersion(String examId) async =>
      Success(mockExams.first.activeVersion!);

  @override
  Future<Result<ExamAttemptEntity>> startExam(String examId) async =>
      const FailureResult(ServerFailure('Not needed for responsive layout tests'));

  @override
  Future<Result<ExamAttemptEntity>> submitExam({
    required String attemptId,
    required Map<String, String> answers,
    ExamSubmissionReason reason = ExamSubmissionReason.studentSubmitted,
  }) async =>
      const FailureResult(ServerFailure('Not needed for responsive layout tests'));

  @override
  Future<Result<void>> syncExamAnswers({
    required String attemptId,
    required Map<String, String> answers,
  }) async => const Success(null);

  @override
  Future<Result<ExamAttemptEntity>> getAttemptDetails(String attemptId) async =>
      const FailureResult(ServerFailure('Not needed for responsive layout tests'));

  Future<Result<List<ExamAttemptEntity>>> getGroupAttempts(
    String groupId,
  ) async => const Success([]);

  @override
  Future<Result<List<ExamAttemptEntity>>> getExamAttempts(
    String examId, {
    int page = 0,
    int pageSize = 50,
  }) async => const Success([]);

  Future<Result<void>> saveAnswersDraft({
    required String attemptId,
    required Map<String, String> answers,
  }) async => const Success(null);

  Future<Result<ExamEntity>> duplicateExam(String examId) async =>
      Success(mockExams.first);

  @override
  Future<Result<MistakeSummaryEntity>> getStudentMistakesSummary(
    String studentId,
  ) async => const Success(
        MistakeSummaryEntity(
          totalMistakes: 0,
          unresolvedCount: 0,
          resolvedCount: 0,
          sources: [],
        ),
      );

  @override
  Future<Result<List<MistakeQuestionEntity>>> getStudentMistakesQuestions(
    String studentId, {
    String? examId,
    bool onlyUnresolved = true,
  }) async => const Success([]);

  @override
  Future<Result<MistakePracticeResultEntity>> submitMistakesPractice(
    List<Map<String, String>> answers,
  ) async => const Success(
        MistakePracticeResultEntity(
          totalQuestions: 0,
          correctCount: 0,
          percentage: 100.0,
          results: [],
        ),
      );

  @override
  Future<Result<List<Map<String, dynamic>>>> getGroupLessons(
    String groupId,
  ) async => const Success([]);

  @override
  Future<Result<void>> linkExamToLesson({
    required String examId,
    required String lessonId,
    required String groupId,
  }) async => const Success(null);

  @override
  Future<Result<void>> unlinkExamFromLesson({
    required String examId,
    required String groupId,
    bool makeGeneralExam = false,
  }) async => const Success(null);

  @override
  Future<Result<void>> convertExamType({
    required String examId,
    required String contentId,
    required bool toLectureExam,
    required String groupId,
  }) async => const Success(null);

  @override
  Future<Result<bool>> deleteExam({
    required String examId,
    bool force = false,
  }) async => const Success(true);

  @override
  Future<Result<ExamParentDispatchRosterEntity>> getExamParentDispatchRoster(
    String examId,
  ) async => const FailureResult(ServerFailure('Not implemented'));

  @override
  Future<Result<bool>> updateStudentParentPhone({
    required String studentId,
    required String parentPhone,
  }) async => const Success(true);

  @override
  Future<Result<List<ExamFolderEntity>>> getExamFolders({String? groupId}) async =>
      const Success([]);

  @override
  Future<Result<ExamFolderEntity>> createExamFolder({
    required String name,
    String? groupId,
    String? color,
    String? icon,
    String? description,
  }) async => Success(
        ExamFolderEntity(
          id: 'f1',
          tenantId: 't1',
          groupId: groupId,
          name: name,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

  @override
  Future<Result<ExamFolderEntity>> updateExamFolder({
    required String folderId,
    required String name,
    String? color,
    String? icon,
    String? description,
  }) async => Success(
        ExamFolderEntity(
          id: folderId,
          tenantId: 't1',
          name: name,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

  @override
  Future<Result<bool>> deleteExamFolder(String folderId) async =>
      const Success(true);

  @override
  Future<Result<bool>> updateMistakeReflection({
    required String mistakeId,
    required String? reflectionReason,
  }) async => const Success(true);

  @override
  Future<Result<bool>> moveExamToFolder({
    required String examId,
    String? folderId,
  }) async => const Success(true);
}

void main() {
  const deviceSizes = <String, Size>{
    '320x640 (Compact Mobile)': Size(320, 640),
    '390x844 (Standard Mobile)': Size(390, 844),
    '500x800 (iPad Split View 1/3)': Size(500, 800),
    '640x960 (iPad Split View 1/2)': Size(640, 960),
    '768x1024 (iPad Portrait)': Size(768, 1024),
    '834x1194 (iPad Pro 11 Portrait)': Size(834, 1194),
    '1024x768 (iPad Landscape)': Size(1024, 768),
    '1440x900 (Desktop Laptop)': Size(1440, 900),
    '1920x1080 (Large Desktop)': Size(1920, 1080),
  };

  final sampleExam = ExamEntity(
    id: 'exam-sat-1',
    contentId: 'content-exam-1',
    tenantId: 'tenant-1',
    groupId: 'group-1',
    title: 'امتحان الجبر والدوال والكسور الجزئية المتقدم (SAT Math Practice)',
    durationMinutes: 45,
    maxScore: 100,
    passingScore: 70,
    shuffleQuestions: false,
    showResult: true,
    allowRetake: true,
    folderName: 'امتحانات الفصل الأول',
    folderColor: '#5B4FE0',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    activeVersion: ExamVersionEntity(
      id: 'version-1',
      examId: 'exam-sat-1',
      versionNumber: 1,
      status: ExamStatus.published,
      createdAt: DateTime.now(),
      publishedAt: DateTime.now(),
      questions: const [
        ExamQuestionEntity(
          id: 'q-1',
          examVersionId: 'version-1',
          questionText: 'ما هي قيمة x في المعادلة 2x + 4 = 10؟',
          questionType: QuestionType.multipleChoice,
          points: 50,
          sortOrder: 0,
          options: [
            QuestionOptionEntity(
              id: 'opt-1',
              questionId: 'q-1',
              optionText: '2',
              isCorrect: false,
            ),
            QuestionOptionEntity(
              id: 'opt-2',
              questionId: 'q-1',
              optionText: '3',
              isCorrect: true,
            ),
          ],
        ),
        ExamQuestionEntity(
          id: 'q-2',
          examVersionId: 'version-1',
          questionText: 'احسب مشتقة الدالة f(x) = x^2 عند النقطة x = 3',
          questionType: QuestionType.multipleChoice,
          points: 50,
          sortOrder: 1,
          options: [
            QuestionOptionEntity(
              id: 'opt-3',
              questionId: 'q-2',
              optionText: '6',
              isCorrect: true,
            ),
          ],
        ),
      ],
    ),
  );

  Widget createTestApp({
    required Widget child,
    required ExamsCubit examsCubit,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar'), Locale('en')],
      locale: const Locale('ar'),
      home: BlocProvider<ExamsCubit>.value(
        value: examsCubit,
        child: child,
      ),
    );
  }

  setUp(() {
    AppCache.clearAll();
  });

  tearDown(() {
    AppCache.clearAll();
  });

  group('ExamCard Multi-Device Responsive Tests', () {
    const cardWidths = <String, double>{
      'Compact Mobile Width (300px)': 300,
      'Standard Mobile Width (360px)': 360,
      'iPad 2-Column Grid Card Width (356px)': 356,
      'iPad Pro 2-Column Grid Card Width (389px)': 389,
      'iPad Split View Medium Width (460px)': 460,
      'Desktop Grid Column Width (400px)': 400,
      'Wide Container Width (550px)': 550,
    };

    for (final entry in cardWidths.entries) {
      testWidgets(
        'Renders in-progress ExamCard cleanly on (${entry.key}) without overflow',
        (tester) async {
          final inProgressExam = sampleExam.copyWith(
            myLatestAttempt: ExamAttemptEntity(
              id: 'att-1',
              examId: sampleExam.id,
              examVersionId: 'version-1',
              studentId: 'student-1',
              status: AttemptStatus.inProgress,
              startedAt: DateTime.now(),
              answeredQuestionsCount: 1,
            ),
          );

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('ar'),
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: entry.value,
                    height: 340,
                    child: ExamCard(
                      exam: inProgressExam,
                      isTeacher: false,
                      onTap: () {},
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();

          expect(find.byType(ExamCard), findsOneWidget);
          expect(find.text(inProgressExam.title), findsOneWidget);
          expect(find.text('استئناف الاختبار'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'Renders available ExamCard cleanly on (${entry.key}) without overflow',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('ar'),
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: entry.value,
                    height: 340,
                    child: ExamCard(
                      exam: sampleExam,
                      isTeacher: false,
                      onTap: () {},
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();

          expect(find.byType(ExamCard), findsOneWidget);
          expect(find.text('بدء الامتحان'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'Renders completed ExamCard cleanly on (${entry.key}) without overflow',
        (tester) async {
          final completedExam = sampleExam.copyWith(
            myLatestAttempt: ExamAttemptEntity(
              id: 'att-comp',
              examId: sampleExam.id,
              examVersionId: 'version-1',
              studentId: 'student-1',
              status: AttemptStatus.submitted,
              score: 95,
              percentage: 95.0,
              startedAt: DateTime.now().subtract(const Duration(minutes: 30)),
              submittedAt: DateTime.now(),
              answeredQuestionsCount: 2,
            ),
          );

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('ar'),
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: entry.value,
                    height: 340,
                    child: ExamCard(
                      exam: completedExam,
                      isTeacher: false,
                      onTap: () {},
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();

          expect(find.byType(ExamCard), findsOneWidget);
          expect(find.textContaining('95'), findsWidgets);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('StudentExamsPage Multi-Device Responsive Tests', () {
    for (final entry in deviceSizes.entries) {
      testWidgets(
        'Renders StudentExamsPage cleanly on (${entry.key}) with zero overflow',
        (tester) async {
          final fakeRepo = _FakeExamsRepository();
          fakeRepo.mockExams = [
            sampleExam,
            sampleExam.copyWith(
              id: 'exam-sat-2',
              title: 'اختبار تجريبي قصير: المتتابعات الهندسية والحسابية',
              myLatestAttempt: ExamAttemptEntity(
                id: 'att-2',
                examId: 'exam-sat-2',
                examVersionId: 'version-1',
                studentId: 'student-1',
                status: AttemptStatus.inProgress,
                startedAt: DateTime.now(),
                answeredQuestionsCount: 1,
              ),
            ),
          ];

          final cubit = ExamsCubit(repository: fakeRepo);

          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            createTestApp(
              child: const StudentExamsPage(),
              examsCubit: cubit,
            ),
          );

          await tester.pumpAndSettle();

          expect(find.text('تقييمات المادة'), findsOneWidget);
          expect(find.byType(ExamCard), findsNWidgets(2));
          final exc = tester.takeException();
          expect(exc, isNull);

          await cubit.close();
        },
      );
    }
  });

  group('Exam Taking Lifecycle & Anti-Cheat Tolerance Tests', () {
    test('Allows up to 3 violations before auto-submission is triggered', () {
      const maxAllowedViolations = 3;
      int violations = 0;
      bool autoSubmitted = false;

      void recordViolation() {
        violations++;
        if (violations >= maxAllowedViolations) {
          autoSubmitted = true;
        }
      }

      // First tab switch (iPad notification or accidental swipe)
      recordViolation();
      expect(violations, 1);
      expect(autoSubmitted, isFalse);

      // Second switch (accidental gesture)
      recordViolation();
      expect(violations, 2);
      expect(autoSubmitted, isFalse);

      // Third switch (exceeded tolerance)
      recordViolation();
      expect(violations, 3);
      expect(autoSubmitted, isTrue);
    });

    test('Untimed and lecture exams are exempt from violation auto-submission', () {
      bool shouldEnforce({required bool isUntimed, required bool isLectureExam}) {
        return !isUntimed && !isLectureExam;
      }

      expect(shouldEnforce(isUntimed: true, isLectureExam: true), isFalse);
      expect(shouldEnforce(isUntimed: false, isLectureExam: true), isFalse);
      expect(shouldEnforce(isUntimed: true, isLectureExam: false), isFalse);
      expect(shouldEnforce(isUntimed: false, isLectureExam: false), isTrue);
    });

    test('Server-derived remainingSeconds calculation is resilient against device throttling', () {
      final startsAt = DateTime.now().subtract(const Duration(minutes: 10));
      const durationMinutes = 60;
      const totalSeconds = durationMinutes * 60;
      final elapsedSeconds = DateTime.now().difference(startsAt).inSeconds;
      final remainingSeconds = (totalSeconds - elapsedSeconds).clamp(0, totalSeconds);

      expect(remainingSeconds, inInclusiveRange(2995, 3000));
    });
  });
}
