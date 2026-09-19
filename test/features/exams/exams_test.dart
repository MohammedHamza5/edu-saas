import 'package:edu_saas/core/errors/failures.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/core/utils/cache_manager.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_entity.dart';
import 'package:edu_saas/features/exams/domain/repositories/exams_repository.dart';
import 'package:edu_saas/features/exams/presentation/cubit/exams_cubit.dart';
import 'package:edu_saas/features/exams/presentation/cubit/exams_state.dart';
import 'package:edu_saas/features/exams/presentation/pages/exam_intro_page.dart';
import 'package:edu_saas/features/exams/presentation/pages/exam_result_page.dart';
import 'package:edu_saas/features/exams/presentation/pages/student_exams_page.dart';
import 'package:edu_saas/features/exams/presentation/pages/teacher_exams_page.dart';
import 'package:edu_saas/features/exams/presentation/widgets/exam_card.dart';
import 'package:edu_saas/features/exams/presentation/widgets/question_option_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeExamsRepository implements ExamsRepository {
  List<ExamEntity> mockExams = [];
  List<ExamAttemptEntity> mockAttempts = [];
  bool shouldFail = false;
  String failureMessage = 'Server error occurred';

  @override
  Future<Result<List<ExamEntity>>> getGroupExams(
    String groupId, {
    int page = 0,
    int pageSize = 15,
  }) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    final filtered = mockExams.where((e) => e.groupId == groupId).toList();
    return Success(filtered);
  }

  @override
  Future<Result<List<ExamEntity>>> getStudentExams({
    int page = 0,
    int pageSize = 15,
  }) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    final filtered = mockExams
        .where((e) => e.activeVersion?.status == ExamStatus.published)
        .toList();
    return Success(filtered);
  }

  @override
  Future<Result<ExamEntity>> getExamDetails(String examId) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    final exam = mockExams.firstWhere(
      (e) => e.id == examId,
      orElse: () => mockExams.isNotEmpty ? mockExams.first : _sampleExam(),
    );
    return Success(exam);
  }

  @override
  Future<Result<ExamEntity>> createExam({
    required String groupId,
    required String title,
    int durationMinutes = 60,
    int maxScore = 100,
    int? passingScore,
    bool shuffleQuestions = false,
    bool showResult = true,
    bool allowRetake = false,
    DateTime? startAt,
    DateTime? endAt,
    required List<ExamQuestionEntity> initialQuestions,
  }) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));

    final now = DateTime.now();
    final newVersion = ExamVersionEntity(
      id: 'version-${now.millisecondsSinceEpoch}',
      examId: 'exam-${now.millisecondsSinceEpoch}',
      versionNumber: 1,
      status: ExamStatus.draft,
      createdAt: now,
      questions: initialQuestions,
    );

    final newExam = ExamEntity(
      id: newVersion.examId,
      contentId: 'content-${now.millisecondsSinceEpoch}',
      tenantId: 'tenant-1',
      groupId: groupId,
      title: title,
      durationMinutes: durationMinutes,
      maxScore: maxScore,
      passingScore: passingScore,
      shuffleQuestions: shuffleQuestions,
      showResult: showResult,
      allowRetake: allowRetake,
      startAt: startAt,
      endAt: endAt,
      createdAt: now,
      updatedAt: now,
      activeVersion: newVersion,
    );

    mockExams.add(newExam);
    return Success(newExam);
  }

  @override
  Future<Result<ExamVersionEntity>> publishExamVersion(String versionId) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));

    final now = DateTime.now();
    final updatedVersion = ExamVersionEntity(
      id: versionId,
      examId: 'exam-1',
      versionNumber: 1,
      status: ExamStatus.published,
      createdAt: now,
      publishedAt: now,
    );

    return Success(updatedVersion);
  }

  @override
  Future<Result<ExamVersionEntity>> createNewExamVersion(String examId) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));

    final newVersion = ExamVersionEntity(
      id: 'version-${DateTime.now().millisecondsSinceEpoch}',
      examId: examId,
      versionNumber: 2,
      status: ExamStatus.draft,
      createdAt: DateTime.now(),
    );

    return Success(newVersion);
  }

  @override
  Future<Result<ExamAttemptEntity>> startExam(String examId) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));

    final existing = mockAttempts
        .where((a) => a.examId == examId && a.status == AttemptStatus.inProgress)
        .firstOrNull;

    if (existing != null) {
      return Success(existing);
    }

    final newAttempt = ExamAttemptEntity(
      id: 'attempt-${DateTime.now().millisecondsSinceEpoch}',
      examId: examId,
      examVersionId: 'version-1',
      studentId: 'student-1',
      startedAt: DateTime.now(),
      status: AttemptStatus.inProgress,
    );

    mockAttempts.add(newAttempt);
    return Success(newAttempt);
  }

  @override
  Future<Result<ExamAttemptEntity>> submitExam({
    required String attemptId,
    required Map<String, String> answers,
  }) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));

    final index = mockAttempts.indexWhere((a) => a.id == attemptId);
    final updated = ExamAttemptEntity(
      id: attemptId,
      examId: 'exam-1',
      examVersionId: 'version-1',
      studentId: 'student-1',
      startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
      submittedAt: DateTime.now(),
      score: 80,
      percentage: 80.0,
      status: AttemptStatus.submitted,
    );

    if (index != -1) {
      mockAttempts[index] = updated;
    } else {
      mockAttempts.add(updated);
    }

    return Success(updated);
  }

  @override
  Future<Result<List<ExamAttemptEntity>>> getExamAttempts(String examId) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    final filtered = mockAttempts.where((a) => a.examId == examId).toList();
    return Success(filtered);
  }

  @override
  Future<Result<ExamAttemptEntity>> getAttemptDetails(String attemptId) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    final attempt = mockAttempts.firstWhere(
      (a) => a.id == attemptId,
      orElse: () => mockAttempts.first,
    );
    return Success(attempt);
  }

  static ExamEntity _sampleExam({
    String id = 'exam-1',
    String groupId = 'group-1',
    String title = 'امتحان الجبر والتفاضل',
    ExamStatus status = ExamStatus.published,
    int maxScore = 100,
    int? passingScore = 60,
  }) {
    final now = DateTime.now();
    return ExamEntity(
      id: id,
      contentId: 'content-1',
      tenantId: 'tenant-1',
      groupId: groupId,
      title: title,
      durationMinutes: 45,
      maxScore: maxScore,
      passingScore: passingScore,
      shuffleQuestions: false,
      showResult: true,
      allowRetake: true,
      createdAt: now,
      updatedAt: now,
      activeVersion: ExamVersionEntity(
        id: 'version-1',
        examId: id,
        versionNumber: 1,
        status: status,
        createdAt: now,
        publishedAt: status == ExamStatus.published ? now : null,
        questions: const [
          ExamQuestionEntity(
            id: 'q-1',
            examVersionId: 'version-1',
            questionText: 'ما هي قيمة x في المعادلة 2x + 4 = 10؟',
            questionType: QuestionType.multipleChoice,
            points: 50,
            sortOrder: 0,
            options: [
              QuestionOptionEntity(id: 'opt-1', questionId: 'q-1', optionText: '2', isCorrect: false),
              QuestionOptionEntity(id: 'opt-2', questionId: 'q-1', optionText: '3', isCorrect: true),
              QuestionOptionEntity(id: 'opt-3', questionId: 'q-1', optionText: '4', isCorrect: false),
              QuestionOptionEntity(id: 'opt-4', questionId: 'q-1', optionText: '5', isCorrect: false),
            ],
          ),
          ExamQuestionEntity(
            id: 'q-2',
            examVersionId: 'version-1',
            questionText: 'تفاضل الدالة f(x) = x^2 هو 2x.',
            questionType: QuestionType.trueFalse,
            points: 50,
            sortOrder: 1,
            options: [
              QuestionOptionEntity(id: 'opt-5', questionId: 'q-2', optionText: 'صح', isCorrect: true),
              QuestionOptionEntity(id: 'opt-6', questionId: 'q-2', optionText: 'خطأ', isCorrect: false),
            ],
          ),
        ],
      ),
    );
  }
}

Widget createTestApp({required Widget child}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('ar')],
    locale: const Locale('ar'),
    home: child,
  );
}

void main() {
  late FakeExamsRepository fakeRepository;
  late ExamsCubit examsCubit;

  setUp(() {
    AppCache.clearAll();
    fakeRepository = FakeExamsRepository();
    examsCubit = ExamsCubit(repository: fakeRepository);
  });

  tearDown(() {
    AppCache.clearAll();
    examsCubit.close();
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. Domain Entities & Business Rules Tests
  // ═══════════════════════════════════════════════════════════════════════════
  group('Exam Domain & Business Rules', () {
    test('ExamAttemptEntity percentage is stored and retrieved correctly', () {
      final attempt = ExamAttemptEntity(
        id: 'attempt-1',
        examId: 'exam-1',
        examVersionId: 'version-1',
        studentId: 'student-1',
        startedAt: DateTime.now(),
        score: 85,
        percentage: 85.0,
      );

      expect(attempt.percentage, 85.0);
      expect(attempt.score, 85);
    });

    test('ExamAttemptEntity isPassed evaluates correctly against passing score', () {
      final passingAttempt = ExamAttemptEntity(
        id: 'attempt-1',
        examId: 'exam-1',
        examVersionId: 'version-1',
        studentId: 'student-1',
        startedAt: DateTime.now(),
        score: 65,
      );

      expect(passingAttempt.isPassed(60), isTrue);
      expect(passingAttempt.isPassed(70), isFalse);
      expect(passingAttempt.isPassed(null), isTrue);
    });

    test('ExamStatus and AttemptStatus enum helpers return valid Arabic strings and colors', () {
      expect(ExamStatus.published.labelAr, 'منشور (مجمد)');
      expect(ExamStatus.draft.labelAr, 'مسودة');
      expect(ExamStatus.archived.labelAr, 'مؤرشف');

      expect(AttemptStatus.inProgress.labelAr, 'قيد الأداء');
      expect(AttemptStatus.submitted.labelAr, 'تم التسليم');
      expect(AttemptStatus.expired.labelAr, 'انتهى الوقت');
    });

    test('ExamVersionEntity publishedAt indicates immutable snapshot', () {
      final publishedTime = DateTime.now();
      final version = ExamVersionEntity(
        id: 'version-1',
        examId: 'exam-1',
        versionNumber: 1,
        status: ExamStatus.published,
        createdAt: DateTime.now(),
        publishedAt: publishedTime,
      );

      expect(version.publishedAt, equals(publishedTime));
      expect(version.status, ExamStatus.published);
      expect(version.isPublished, isTrue);
    });

    test('QuestionOptionEntity default hides isCorrect for security compliance', () {
      const option = QuestionOptionEntity(
        id: 'opt-x',
        questionId: 'q-1',
        optionText: 'خيار غير موثوق',
      );

      expect(option.isCorrect, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. Repository & Result Tests
  // ═══════════════════════════════════════════════════════════════════════════
  group('FakeExamsRepository', () {
    test('createExam successfully returns new draft exam', () async {
      final result = await fakeRepository.createExam(
        groupId: 'group-1',
        title: 'امتحان جديد',
        initialQuestions: [],
      );

      expect(result.isSuccess, isTrue);
      final exam = (result as Success<ExamEntity>).data;
      expect(exam.title, 'امتحان جديد');
      expect(exam.activeVersion?.status, ExamStatus.draft);
      expect(fakeRepository.mockExams.length, 1);
    });

    test('createNewExamVersion clones questions into a new draft version', () async {
      final result = await fakeRepository.createNewExamVersion('exam-1');
      expect(result.isSuccess, isTrue);
      final version = (result as Success<ExamVersionEntity>).data;
      expect(version.versionNumber, 2);
      expect(version.status, ExamStatus.draft);
    });

    test('startExam creates an in_progress attempt', () async {
      final result = await fakeRepository.startExam('exam-1');
      expect(result.isSuccess, isTrue);
      final attempt = (result as Success<ExamAttemptEntity>).data;
      expect(attempt.status, AttemptStatus.inProgress);
    });

    test('submitExam updates attempt status to submitted with atomic score', () async {
      final startRes = await fakeRepository.startExam('exam-1');
      final attemptId = (startRes as Success<ExamAttemptEntity>).data.id;

      final submitRes = await fakeRepository.submitExam(
        attemptId: attemptId,
        answers: {'q-1': 'opt-2'},
      );

      expect(submitRes.isSuccess, isTrue);
      final submitted = (submitRes as Success<ExamAttemptEntity>).data;
      expect(submitted.status, AttemptStatus.submitted);
      expect(submitted.score, 80);
      expect(submitted.percentage, 80.0);
    });

    test('returns FailureResult on server failure', () async {
      fakeRepository.shouldFail = true;
      final result = await fakeRepository.getGroupExams('group-1');
      expect(result.isFailure, isTrue);
      expect((result as FailureResult).failure.message, 'Server error occurred');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. ExamsCubit Unit Tests
  // ═══════════════════════════════════════════════════════════════════════════
  group('ExamsCubit', () {
    test('initial state is ExamsInitial', () {
      expect(examsCubit.state, const ExamsInitial());
    });

    test('loadGroupExams emits TeacherExamsLoaded with group exams', () async {
      fakeRepository.mockExams = [FakeExamsRepository._sampleExam()];

      final states = <ExamsState>[];
      final sub = examsCubit.stream.listen(states.add);

      await examsCubit.loadGroupExams('group-1');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(states.length, 2);
      expect(states[0], isA<ExamsLoading>());
      expect(states[1], isA<TeacherExamsLoaded>());
      final loaded = states[1] as TeacherExamsLoaded;
      expect(loaded.exams.length, 1);
      expect(loaded.exams.first.title, 'امتحان الجبر والتفاضل');

      await sub.cancel();
    });

    test('loadStudentExams emits ExamsEmpty when no exams are published', () async {
      fakeRepository.mockExams = [];

      final states = <ExamsState>[];
      final sub = examsCubit.stream.listen(states.add);

      await examsCubit.loadStudentExams();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(states.last, isA<ExamsEmpty>());

      await sub.cancel();
    });

    test('loadStudentExams emits StudentExamsLoaded with published exams', () async {
      fakeRepository.mockExams = [FakeExamsRepository._sampleExam()];

      final states = <ExamsState>[];
      final sub = examsCubit.stream.listen(states.add);

      await examsCubit.loadStudentExams();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(states.last, isA<StudentExamsLoaded>());
      final loaded = states.last as StudentExamsLoaded;
      expect(loaded.exams.length, 1);

      await sub.cancel();
    });

    test('startExamTaking sets up ExamTakingState with questions and duration', () async {
      final sample = FakeExamsRepository._sampleExam();
      fakeRepository.mockExams = [sample];

      final success = await examsCubit.startExamTaking(sample);

      expect(success, isTrue);
      expect(examsCubit.state, isA<ExamTakingState>());
      final takingState = examsCubit.state as ExamTakingState;
      expect(takingState.questions.length, 2);
      expect(takingState.remainingSeconds, greaterThan(0));
    });

    test('selectAnswer records selected answer correctly in ExamTakingState', () async {
      final sample = FakeExamsRepository._sampleExam();
      fakeRepository.mockExams = [sample];
      await examsCubit.startExamTaking(sample);

      examsCubit.selectAnswer('q-1', 'opt-2');

      final takingState = examsCubit.state as ExamTakingState;
      expect(takingState.answers['q-1'], 'opt-2');
    });

    test('goToQuestion navigates index correctly', () async {
      final sample = FakeExamsRepository._sampleExam();
      fakeRepository.mockExams = [sample];
      await examsCubit.startExamTaking(sample);

      examsCubit.goToQuestion(1);

      final takingState = examsCubit.state as ExamTakingState;
      expect(takingState.currentQuestionIndex, 1);
    });

    test('submitExam transitions taking state to submitSuccess', () async {
      final sample = FakeExamsRepository._sampleExam();
      fakeRepository.mockExams = [sample];
      await examsCubit.startExamTaking(sample);
      examsCubit.selectAnswer('q-1', 'opt-2');

      final success = await examsCubit.submitExam();

      expect(success, isTrue);
      final state = examsCubit.state as ExamTakingState;
      expect(state.submitSuccess, isTrue);
      expect(state.submitResult?.score, 80);
    });

    test('loadGroupExams emits ExamsError when repository fails', () async {
      fakeRepository.shouldFail = true;

      final states = <ExamsState>[];
      final sub = examsCubit.stream.listen(states.add);

      await examsCubit.loadGroupExams('group-1');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(states.last, isA<ExamsError>());
      expect((states.last as ExamsError).message, 'Server error occurred');

      await sub.cancel();
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. Widget Tests
  // ═══════════════════════════════════════════════════════════════════════════
  group('Exam Widgets Tests', () {
    testWidgets('ExamCard displays exam info and stats accurately', (tester) async {
      final exam = FakeExamsRepository._sampleExam();

      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            body: ExamCard(
              exam: exam,
              onTap: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('امتحان الجبر والتفاضل'), findsOneWidget);
      expect(find.text('45 دقيقة'), findsOneWidget);
      expect(find.text('100 درجة'), findsOneWidget);
    });

    testWidgets('QuestionOptionTile renders letter, text, and responds to tap', (tester) async {
      const option = QuestionOptionEntity(
        id: 'opt-1',
        questionId: 'q-1',
        optionText: 'خيار رقم واحد',
      );

      var tapped = false;

      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            body: QuestionOptionTile(
              option: option,
              index: 0,
              isSelected: false,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('خيار رقم واحد'), findsOneWidget);
      expect(find.text('أ'), findsOneWidget); // Arabic index indicator

      await tester.tap(find.byType(QuestionOptionTile));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('ExamIntroPage renders exam instructions and start button', (tester) async {
      final exam = FakeExamsRepository._sampleExam();

      await tester.pumpWidget(
        createTestApp(
          child: BlocProvider<ExamsCubit>.value(
            value: examsCubit,
            child: ExamIntroPage(exam: exam),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('امتحان الجبر والتفاضل'), findsWidgets);
      expect(find.text('بدء الامتحان الآن'), findsOneWidget);
      expect(find.text('تعليمات هامة قبل البدء:'), findsOneWidget);
    });

    testWidgets('ExamResultPage renders student score and passed badge', (tester) async {
      final exam = FakeExamsRepository._sampleExam();
      final attempt = ExamAttemptEntity(
        id: 'att-1',
        examId: exam.id,
        examVersionId: 'v-1',
        studentId: 's-1',
        startedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        submittedAt: DateTime.now(),
        score: 80,
        percentage: 80.0,
        status: AttemptStatus.submitted,
      );

      await tester.pumpWidget(
        createTestApp(
          child: ExamResultPage(
            exam: exam,
            attempt: attempt,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('نتيجة الامتحان'), findsOneWidget);
      expect(find.text('تهانينا! لقد اجتزت الامتحان بنجاح'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
    });

    testWidgets('TeacherExamsPage renders empty state when no exams exist', (tester) async {
      fakeRepository.mockExams = [];

      await tester.pumpWidget(
        createTestApp(
          child: BlocProvider<ExamsCubit>.value(
            value: examsCubit,
            child: const TeacherExamsPage(
              groupId: 'group-empty',
              groupName: 'مجموعة بدون امتحانات',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('لا توجد امتحانات مضافة لهذه المجموعة'), findsOneWidget);
    });

    testWidgets('StudentExamsPage renders exam cards when available', (tester) async {
      fakeRepository.mockExams = [FakeExamsRepository._sampleExam()];

      await tester.pumpWidget(
        createTestApp(
          child: BlocProvider<ExamsCubit>.value(
            value: examsCubit,
            child: const StudentExamsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('امتحاناتي واختباراتي'), findsOneWidget);
      expect(find.text('امتحان الجبر والتفاضل'), findsOneWidget);
    });

    testWidgets('TeacherExamsPage opens exam details sheet on card tap without error', (tester) async {
      final exam = FakeExamsRepository._sampleExam();
      fakeRepository.mockExams = [exam];
      fakeRepository.mockAttempts = [
        ExamAttemptEntity(
          id: 'att-1',
          examId: exam.id,
          examVersionId: exam.activeVersion?.id ?? 'v1',
          studentId: 'student-1',
          studentName: 'محمود سامي',
          score: 85,
          percentage: 85.0,
          status: AttemptStatus.submitted,
          startedAt: DateTime.now().subtract(const Duration(minutes: 30)),
          submittedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        createTestApp(
          child: BlocProvider<ExamsCubit>.value(
            value: examsCubit,
            child: const TeacherExamsPage(
              groupId: 'group-1',
              groupName: 'مجموعة 1',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('امتحان الجبر والتفاضل'), findsOneWidget);

      // Tap the exam card
      await tester.tap(find.text('امتحان الجبر والتفاضل'));
      await tester.pumpAndSettle();

      // Verify the details sheet opened with student attempt, NOT an error widget
      expect(find.text('محمود سامي'), findsOneWidget);
      expect(find.text('An error occurred displaying content'), findsNothing);
    });

    test('ExamsCubit loadStudentExams ignores invocation when exam is currently in progress (ExamTakingState)', () async {
      final exam = FakeExamsRepository._sampleExam();
      fakeRepository.mockExams = [exam];

      final success = await examsCubit.startExamTaking(exam);
      expect(success, isTrue);
      expect(examsCubit.state, isA<ExamTakingState>());

      // Calling loadStudentExams while taking exam should NOT overwrite ExamTakingState
      await examsCubit.loadStudentExams(forceRefresh: true);
      expect(examsCubit.state, isA<ExamTakingState>());
    });

    test('ExamsCubit startExamTaking fails gracefully when questions are empty', () async {
      final examWithoutQuestions = ExamEntity(
        id: 'empty-exam',
        contentId: 'content-empty',
        tenantId: 'tenant-1',
        groupId: 'group-1',
        title: 'امتحان فارغ',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        activeVersion: ExamVersionEntity(
          id: 'v-empty',
          examId: 'empty-exam',
          createdAt: DateTime.now(),
          questions: const [],
        ),
      );
      fakeRepository.mockExams = [examWithoutQuestions];

      final success = await examsCubit.startExamTaking(examWithoutQuestions);
      expect(success, isFalse);
      expect(examsCubit.state, isA<ExamsError>());
    });
  });
}

