import 'package:flutter_test/flutter_test.dart';

import 'package:edu_saas/core/errors/failures.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/utils/cache_manager.dart';

import 'package:edu_saas/features/exams/domain/entities/exam_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_folder_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_parent_dispatch_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/mistake_entities.dart';
import 'package:edu_saas/features/exams/domain/repositories/exams_repository.dart';
import 'package:edu_saas/features/exams/data/datasources/exam_answers_local_datasource.dart';
import 'package:edu_saas/features/exams/presentation/cubit/exams_cubit.dart';
import 'package:edu_saas/features/exams/presentation/cubit/exams_state.dart';

// ---------------------------------------------------------------------------
// IN-MEMORY SIMULATED LOCAL STORAGE (Per-Device Storage Simulation)
// ---------------------------------------------------------------------------
class _SimulatedDeviceLocalStorage implements ExamAnswersLocalDataSource {
  final Map<String, Map<String, String>> _storage = {};

  @override
  Future<void> saveAnswers({
    required String attemptId,
    required Map<String, String> answers,
  }) async {
    _storage[attemptId] = Map<String, String>.from(answers);
  }

  @override
  Future<Map<String, String>> getAnswers(String attemptId) async {
    return Map<String, String>.from(_storage[attemptId] ?? {});
  }

  @override
  Future<void> clearAnswers(String attemptId) async {
    _storage.remove(attemptId);
  }
}

// ---------------------------------------------------------------------------
// SIMULATED ATOMIC BACKEND ENGINE (Multi-Device Session & Attempt Idempotency)
// ---------------------------------------------------------------------------
class _SimulatedAtomicBackend {
  // Database of active attempts keyed by examId_studentId
  final Map<String, ExamAttemptEntity> _attempts = {};

  // Lock to simulate atomic database row-level locking on submission
  final Set<String> _submissionLocks = {};

  // Stored submission counts per attempt
  final Map<String, int> submissionCallCount = {};

  // The base published exam
  late final ExamEntity satOfficialExam;

  _SimulatedAtomicBackend() {
    final now = DateTime.now();
    satOfficialExam = ExamEntity(
      id: 'exam-sat-official-2026',
      contentId: 'cnt-sat-official',
      tenantId: 'tenant-sat-academy',
      groupId: 'grp-sat-elite',
      title: 'SAT Digital Math Module 1 — Real Official Mock',
      durationMinutes: 35,
      maxScore: 100,
      passingScore: 70,
      createdAt: now.subtract(const Duration(days: 3)),
      updatedAt: now,
      activeVersion: ExamVersionEntity(
        id: 'ver-sat-01',
        examId: 'exam-sat-official-2026',
        versionNumber: 1,
        status: ExamStatus.published,
        createdAt: now.subtract(const Duration(days: 3)),
        questions: const [
          ExamQuestionEntity(
            id: 'q-math-01',
            examVersionId: 'ver-sat-01',
            sortOrder: 1,
            questionText: 'If 3x + 7 = 22, what is the value of 6x - 4?',
            questionType: QuestionType.multipleChoice,
            points: 25,
            options: [
              QuestionOptionEntity(id: 'opt-01-a', questionId: 'q-math-01', optionText: '26', sortOrder: 1),
              QuestionOptionEntity(id: 'opt-01-b', questionId: 'q-math-01', optionText: '30', sortOrder: 2),
            ],
          ),
          ExamQuestionEntity(
            id: 'q-math-02',
            examVersionId: 'ver-sat-01',
            sortOrder: 2,
            questionText: 'Which expression is equivalent to (2x - 3)(x + 4)?',
            questionType: QuestionType.multipleChoice,
            points: 25,
            options: [
              QuestionOptionEntity(id: 'opt-02-a', questionId: 'q-math-02', optionText: '2x² + 5x - 12', sortOrder: 1),
              QuestionOptionEntity(id: 'opt-02-b', questionId: 'q-math-02', optionText: '2x² - 5x - 12', sortOrder: 2),
            ],
          ),
          ExamQuestionEntity(
            id: 'q-math-03',
            examVersionId: 'ver-sat-01',
            sortOrder: 3,
            questionText: 'The vertex of the parabola y = (x - 2)² + 5 is:',
            questionType: QuestionType.multipleChoice,
            points: 25,
            options: [
              QuestionOptionEntity(id: 'opt-03-a', questionId: 'q-math-03', optionText: '(2, 5)', sortOrder: 1),
              QuestionOptionEntity(id: 'opt-03-b', questionId: 'q-math-03', optionText: '(-2, 5)', sortOrder: 2),
            ],
          ),
          ExamQuestionEntity(
            id: 'q-math-04',
            examVersionId: 'ver-sat-01',
            sortOrder: 4,
            questionText: 'If f(x) = 2x² - 3x + 1, find f(3).',
            questionType: QuestionType.multipleChoice,
            points: 25,
            options: [
              QuestionOptionEntity(id: 'opt-04-a', questionId: 'q-math-04', optionText: '10', sortOrder: 1),
              QuestionOptionEntity(id: 'opt-04-b', questionId: 'q-math-04', optionText: '12', sortOrder: 2),
            ],
          ),
        ],
      ),
    );
  }

  /// Atomic start/resume attempt RPC
  ExamAttemptEntity startOrResumeAttempt({
    required String examId,
    required String studentId,
    int? simulatedRemainingSeconds,
  }) {
    final key = '${examId}_$studentId';
    if (_attempts.containsKey(key)) {
      // Existing attempt found — return existing attempt for resumption
      return _attempts[key]!;
    }

    final newAttempt = ExamAttemptEntity(
      id: 'att-${studentId.substring(4)}-${DateTime.now().millisecondsSinceEpoch}',
      examId: examId,
      examVersionId: satOfficialExam.activeVersion!.id,
      studentId: studentId,
      status: AttemptStatus.inProgress,
      startedAt: DateTime.now().toUtc(),
      remainingSeconds: simulatedRemainingSeconds ?? (35 * 60),
      questions: satOfficialExam.activeVersion!.questions,
      answers: const [],
    );

    _attempts[key] = newAttempt;
    return newAttempt;
  }

  /// Syncs partial answers into the server attempt row
  void syncServerAnswers(String examId, String studentId, Map<String, String> answers) {
    final key = '${examId}_$studentId';
    final existing = _attempts[key];
    if (existing == null) return;

    final updatedAnswers = answers.entries.map((e) {
      return ExamAnswerEntity(
        id: 'ans-${e.key}',
        attemptId: existing.id,
        questionId: e.key,
        selectedOptionId: e.value,
        answeredAt: DateTime.now().toUtc(),
      );
    }).toList();

    _attempts[key] = existing.copyWith(answers: updatedAnswers);
  }

  /// Atomic Submit RPC with concurrency idempotency lock
  Future<Result<ExamAttemptEntity>> atomicSubmitExam({
    required String attemptId,
    required Map<String, String> answers,
    required ExamSubmissionReason reason,
  }) async {
    submissionCallCount[attemptId] = (submissionCallCount[attemptId] ?? 0) + 1;

    // 1. Check if attempt exists
    ExamAttemptEntity? attempt;
    String? matchedKey;
    for (final entry in _attempts.entries) {
      if (entry.value.id == attemptId) {
        attempt = entry.value;
        matchedKey = entry.key;
        break;
      }
    }

    if (attempt == null) {
      return const FailureResult(NotFoundFailure('Attempt record not found'));
    }

    // 2. Concurrency Guard: Check if attempt is already submitted
    if (attempt.status == AttemptStatus.submitted) {
      return const FailureResult(ConflictFailure('EXAM_ALREADY_SUBMITTED: Attempt has already been submitted'));
    }

    if (attempt.status == AttemptStatus.expired) {
      return const FailureResult(ConflictFailure('EXAM_EXPIRED: Attempt duration has expired'));
    }

    // 3. Row-level Lock Simulation
    if (_submissionLocks.contains(attemptId)) {
      // Another thread is actively processing this submission
      return const FailureResult(ConflictFailure('EXAM_SUBMISSION_IN_PROGRESS: Concurrent submission collision'));
    }

    _submissionLocks.add(attemptId);

    // Simulate atomic grading & transaction execution
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final totalScore = answers.length * 25; // 25 pts each
    final submittedAttempt = attempt.copyWith(
      status: reason == ExamSubmissionReason.timeExpired ? AttemptStatus.expired : AttemptStatus.submitted,
      submittedAt: DateTime.now().toUtc(),
      score: totalScore,
      percentage: (totalScore / 100.0) * 100.0,
      submissionReason: reason,
    );

    _attempts[matchedKey!] = submittedAttempt;
    _submissionLocks.remove(attemptId);

    return Success(submittedAttempt);
  }
}

// ---------------------------------------------------------------------------
// SIMULATED REPOSITORY WRAPPER
// ---------------------------------------------------------------------------
class _SimulatedExamsRepo implements ExamsRepository {
  final _SimulatedAtomicBackend backend;
  final String activeStudentId;

  _SimulatedExamsRepo(this.backend, {this.activeStudentId = 'std-omar-01'});

  @override
  Future<Result<ExamEntity>> getExamDetails(String examId) async {
    return Success(backend.satOfficialExam);
  }

  @override
  Future<Result<ExamAttemptEntity>> startExam(String examId) async {
    final attempt = backend.startOrResumeAttempt(
      examId: examId,
      studentId: activeStudentId,
    );
    return Success(attempt);
  }

  @override
  Future<Result<void>> syncExamAnswers({
    required String attemptId,
    required Map<String, String> answers,
  }) async {
    backend.syncServerAnswers(backend.satOfficialExam.id, activeStudentId, answers);
    return const Success(null);
  }

  @override
  Future<Result<ExamAttemptEntity>> submitExam({
    required String attemptId,
    required Map<String, String> answers,
    ExamSubmissionReason reason = ExamSubmissionReason.studentSubmitted,
  }) async {
    return backend.atomicSubmitExam(
      attemptId: attemptId,
      answers: answers,
      reason: reason,
    );
  }

  // Stubs for interface
  @override
  Future<Result<List<ExamEntity>>> getGroupExams(String groupId, {int page = 0, int pageSize = 15}) async => const Success([]);
  @override
  Future<Result<List<ExamEntity>>> getStudentExams({int page = 0, int pageSize = 15}) async => const Success([]);
  @override
  Future<Result<ExamEntity>> createExam({String? groupId, required String title, int durationMinutes = 60, int maxScore = 100, int? passingScore, bool shuffleQuestions = false, bool showResult = true, bool allowRetake = false, DateTime? startAt, DateTime? endAt, bool isPublished = false, String? pdfFileId, required List<ExamQuestionEntity> initialQuestions}) async => throw UnimplementedError();
  @override
  Future<Result<ExamEntity>> updateExam({required String examId, required String title, int? durationMinutes, int? maxScore, int? passingScore, bool? shuffleQuestions, bool? showResult, bool? allowRetake, DateTime? startAt, DateTime? endAt, bool? isPublished, String? pdfFileId, bool clearPdfFile = false}) async => throw UnimplementedError();
  @override
  Future<Result<ExamEntity>> updateDraftExamQuestions({required String examId, required String title, int? durationMinutes, int? maxScore, int? passingScore, bool? shuffleQuestions, bool? showResult, bool? allowRetake, DateTime? startAt, DateTime? endAt, bool? isPublished, String? pdfFileId, bool clearPdfFile = false, required List<ExamQuestionEntity> questions}) async => throw UnimplementedError();
  @override
  Future<Result<String>> getSignedPdfUrl(String storagePath) async => const Success('https://cdn.sat.academy/mock.pdf');
  @override
  Future<Result<ExamVersionEntity>> publishExamVersion(String versionId) async => throw UnimplementedError();
  @override
  Future<Result<void>> unpublishExamVersion({required String examId, required String versionId}) async => const Success(null);
  @override
  Future<Result<ExamVersionEntity>> createNewExamVersion(String examId) async => throw UnimplementedError();
  @override
  Future<Result<bool>> deleteExam({required String examId, bool force = false}) async => const Success(true);
  @override
  Future<Result<List<ExamAttemptEntity>>> getExamAttempts(String examId, {int page = 0, int pageSize = 20}) async => const Success([]);
  @override
  Future<Result<ExamAttemptEntity>> getAttemptDetails(String attemptId) async => throw UnimplementedError();
  @override
  Future<Result<MistakeSummaryEntity>> getStudentMistakesSummary(String studentId) async => throw UnimplementedError();
  @override
  Future<Result<List<MistakeQuestionEntity>>> getStudentMistakesQuestions(String studentId, {String? examId, bool onlyUnresolved = true}) async => const Success([]);
  @override
  Future<Result<MistakePracticeResultEntity>> submitMistakesPractice(List<Map<String, String>> answers) async => throw UnimplementedError();
  @override
  Future<Result<List<Map<String, dynamic>>>> getGroupLessons(String groupId) async => const Success([]);
  @override
  Future<Result<void>> linkExamToLesson({required String examId, required String lessonId, required String groupId}) async => const Success(null);
  @override
  Future<Result<void>> unlinkExamFromLesson({required String examId, required String groupId, bool makeGeneralExam = false}) async => const Success(null);
  @override
  Future<Result<void>> convertExamType({required String examId, required String contentId, required bool toLectureExam, required String groupId}) async => const Success(null);
  @override
  Future<Result<ExamParentDispatchRosterEntity>> getExamParentDispatchRoster(String examId) async => throw UnimplementedError();
  @override
  Future<Result<bool>> updateStudentParentPhone({required String studentId, required String parentPhone}) async => const Success(true);
  @override
  Future<Result<List<ExamFolderEntity>>> getExamFolders({String? groupId}) async => const Success([]);
  @override
  Future<Result<ExamFolderEntity>> createExamFolder({required String name, String? groupId, String? color, String? icon, String? description}) async => throw UnimplementedError();
  @override
  Future<Result<ExamFolderEntity>> updateExamFolder({required String folderId, required String name, String? color, String? icon, String? description}) async => throw UnimplementedError();
  @override
  Future<Result<bool>> deleteExamFolder(String folderId) async => const Success(true);
  @override
  Future<Result<bool>> moveExamToFolder({required String examId, String? folderId}) async => const Success(true);
}

// ---------------------------------------------------------------------------
// TEST SUITE: Concurrent Multi-Device Session Collision & Exam Lockout
// ---------------------------------------------------------------------------
void main() {
  late _SimulatedAtomicBackend backend;

  setUp(() {
    AppCache.clearAll();
    backend = _SimulatedAtomicBackend();
  });

  tearDown(() {
    AppCache.clearAll();
  });

  group('⚔️ [Simulation: Multi-Device Session Concurrency & Collision Lockout]', () {
    test('SCENARIO 1: Single Active Attempt Resumption Across Device Migration', () async {
      const studentId = 'std-omar-01';
      final repoIpad = _SimulatedExamsRepo(backend, activeStudentId: studentId);
      final storageIpad = _SimulatedDeviceLocalStorage();
      final cubitIpad = ExamsCubit(repository: repoIpad, answersStorage: storageIpad);

      // 1. Student starts exam on iPad (Device A)
      final startedOnIpad = await cubitIpad.startExamTaking(backend.satOfficialExam);
      expect(startedOnIpad, isTrue);
      expect(cubitIpad.state, isA<ExamTakingState>());

      final ipadState = cubitIpad.state as ExamTakingState;
      final attemptId = ipadState.attempt.id;

      // 2. Student selects answers on iPad for Q1 and Q2
      cubitIpad.selectAnswer('q-math-01', 'opt-01-a');
      cubitIpad.selectAnswer('q-math-02', 'opt-02-a');

      // Sync partial answers to server
      backend.syncServerAnswers(backend.satOfficialExam.id, studentId, {
        'q-math-01': 'opt-01-a',
        'q-math-02': 'opt-02-a',
      });

      // 3. Student device dies / student opens Web Browser on Laptop (Device B)
      final repoLaptop = _SimulatedExamsRepo(backend, activeStudentId: studentId);
      final storageLaptop = _SimulatedDeviceLocalStorage();
      final cubitLaptop = ExamsCubit(repository: repoLaptop, answersStorage: storageLaptop);

      // Start taking on Laptop
      final startedOnLaptop = await cubitLaptop.startExamTaking(backend.satOfficialExam);
      expect(startedOnLaptop, isTrue);
      expect(cubitLaptop.state, isA<ExamTakingState>());

      final laptopState = cubitLaptop.state as ExamTakingState;

      // Assert that it RESUMED the exact same attemptId (zero duplicate attempts created)
      expect(laptopState.attempt.id, equals(attemptId));

      // Assert that answers saved on iPad were seamlessly restored on the Laptop
      expect(laptopState.answers['q-math-01'], equals('opt-01-a'));
      expect(laptopState.answers['q-math-02'], equals('opt-02-a'));

      // 4. Student continues on Laptop, answering Q3 and Q4
      cubitLaptop.selectAnswer('q-math-03', 'opt-03-a');
      cubitLaptop.selectAnswer('q-math-04', 'opt-04-a');

      expect((cubitLaptop.state as ExamTakingState).answers.length, equals(4));

      await cubitIpad.close();
      await cubitLaptop.close();
    });

    test('SCENARIO 2: Concurrent Multi-Device Simultaneous Submission Race & Idempotency Lock', () async {
      const studentId = 'std-omar-01';
      final repoDeviceA = _SimulatedExamsRepo(backend, activeStudentId: studentId);
      final repoDeviceB = _SimulatedExamsRepo(backend, activeStudentId: studentId);

      final cubitA = ExamsCubit(repository: repoDeviceA, answersStorage: _SimulatedDeviceLocalStorage());
      final cubitB = ExamsCubit(repository: repoDeviceB, answersStorage: _SimulatedDeviceLocalStorage());

      await cubitA.startExamTaking(backend.satOfficialExam);
      await cubitB.startExamTaking(backend.satOfficialExam);

      cubitA.selectAnswer('q-math-01', 'opt-01-a');
      cubitA.selectAnswer('q-math-02', 'opt-02-a');
      cubitA.selectAnswer('q-math-03', 'opt-03-a');
      cubitA.selectAnswer('q-math-04', 'opt-04-a');

      cubitB.selectAnswer('q-math-01', 'opt-01-a');
      cubitB.selectAnswer('q-math-02', 'opt-02-a');
      cubitB.selectAnswer('q-math-03', 'opt-03-b'); // Divergent answer
      cubitB.selectAnswer('q-math-04', 'opt-04-a');

      // Both devices fire submit concurrently at the exact same millisecond
      final futureA = cubitA.submitExam();
      final futureB = cubitB.submitExam();

      final results = await Future.wait([futureA, futureB]);

      // Exactly ONE submission must succeed, and the collision must be rejected
      final successCount = results.where((r) => r == true).length;
      final failureCount = results.where((r) => r == false).length;

      expect(successCount, equals(1), reason: 'Only one submission transaction can commit');
      expect(failureCount, equals(1), reason: 'Concurrent second submission must be rejected');

      // Verify that backend submission call count registered the conflict
      final attemptId = (cubitA.state as ExamTakingState).attempt.id;
      expect(backend.submissionCallCount[attemptId], equals(2));

      await cubitA.close();
      await cubitB.close();
    });

    test('SCENARIO 3: Client Local Clock Skew Immunity (Server-Authoritative Timer)', () async {
      const studentId = 'std-omar-01';
      // Simulate that the server created the attempt with remaining 900 seconds (15 mins left)
      final existingAttempt = backend.startOrResumeAttempt(
        examId: backend.satOfficialExam.id,
        studentId: studentId,
        simulatedRemainingSeconds: 900,
      );

      expect(existingAttempt.remainingSeconds, equals(900));

      final repo = _SimulatedExamsRepo(backend, activeStudentId: studentId);
      final cubit = ExamsCubit(repository: repo, answersStorage: _SimulatedDeviceLocalStorage());

      // Start taking
      await cubit.startExamTaking(backend.satOfficialExam);

      expect(cubit.state, isA<ExamTakingState>());
      final takingState = cubit.state as ExamTakingState;

      // The remaining seconds must strictly reflect the server's 900 seconds
      // rather than blindly resetting to exam.durationMinutes (35 mins = 2100s)
      expect(takingState.remainingSeconds, equals(900));

      await cubit.close();
    });

    test('SCENARIO 4: Hard Expiration Lockout (Zero-Second Auto-Submit & Expired Rejection)', () async {
      const studentId = 'std-omar-01';
      final repo = _SimulatedExamsRepo(backend, activeStudentId: studentId);
      final cubit = ExamsCubit(repository: repo, answersStorage: _SimulatedDeviceLocalStorage());

      await cubit.startExamTaking(backend.satOfficialExam);
      cubit.selectAnswer('q-math-01', 'opt-01-a');

      // Submit triggered by timer expiration
      final submitted = await cubit.submitExam(reason: ExamSubmissionReason.timeExpired);
      expect(submitted, isTrue);

      final state = cubit.state as ExamTakingState;
      expect(state.submitSuccess, isTrue);
      expect(state.submitResult?.status, equals(AttemptStatus.expired));

      // Attempting to submit again to the expired attempt is strictly rejected
      final secondAttemptResult = await repo.submitExam(
        attemptId: state.attempt.id,
        answers: {'q-math-01': 'opt-01-b'},
        reason: ExamSubmissionReason.studentSubmitted,
      );

      expect(secondAttemptResult.isFailure, isTrue);
      expect(secondAttemptResult.failureOrNull?.message, contains('EXAM_EXPIRED'));

      await cubit.close();
    });

    test('SCENARIO 5: Multi-Tenant & Multi-Student Attempt Data Isolation', () async {
      const studentTenantA = 'std-alice-tenantA';
      const studentTenantB = 'std-bob-tenantB';

      final repoA = _SimulatedExamsRepo(backend, activeStudentId: studentTenantA);
      final repoB = _SimulatedExamsRepo(backend, activeStudentId: studentTenantB);

      final cubitA = ExamsCubit(repository: repoA, answersStorage: _SimulatedDeviceLocalStorage());
      final cubitB = ExamsCubit(repository: repoB, answersStorage: _SimulatedDeviceLocalStorage());

      await cubitA.startExamTaking(backend.satOfficialExam);
      await cubitB.startExamTaking(backend.satOfficialExam);

      final attemptA = (cubitA.state as ExamTakingState).attempt;
      final attemptB = (cubitB.state as ExamTakingState).attempt;

      // Different student IDs must yield distinct attempt IDs
      expect(attemptA.id, isNot(equals(attemptB.id)));
      expect(attemptA.studentId, equals(studentTenantA));
      expect(attemptB.studentId, equals(studentTenantB));

      cubitA.selectAnswer('q-math-01', 'opt-01-a');
      cubitB.selectAnswer('q-math-01', 'opt-01-b');

      expect((cubitA.state as ExamTakingState).answers['q-math-01'], equals('opt-01-a'));
      expect((cubitB.state as ExamTakingState).answers['q-math-01'], equals('opt-01-b'));

      await cubitA.close();
      await cubitB.close();
    });
  });
}
