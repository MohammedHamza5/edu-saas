import 'package:flutter_test/flutter_test.dart';

import 'package:edu_saas/core/errors/failures.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/utils/cache_manager.dart';

// Exams Domain & Data
import 'package:edu_saas/features/exams/domain/entities/exam_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_folder_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_parent_dispatch_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/mistake_entities.dart';
import 'package:edu_saas/features/exams/domain/repositories/exams_repository.dart';
import 'package:edu_saas/features/exams/data/datasources/exam_answers_local_datasource.dart';
import 'package:edu_saas/features/exams/presentation/cubit/exams_cubit.dart';
import 'package:edu_saas/features/exams/presentation/cubit/exams_state.dart';

// ---------------------------------------------------------------------------
// Realistic In-Memory Local Answer Draft DataSource (Simulates Secure Storage)
// ---------------------------------------------------------------------------
class SimulatedExamAnswersLocalDataSource implements ExamAnswersLocalDataSource {
  final Map<String, Map<String, String>> _storage = {};
  int saveCount = 0;
  int readCount = 0;

  @override
  Future<void> saveAnswers({
    required String attemptId,
    required Map<String, String> answers,
  }) async {
    saveCount++;
    _storage[attemptId] = Map<String, String>.from(answers);
  }

  @override
  Future<Map<String, String>> getAnswers(String attemptId) async {
    readCount++;
    return Map<String, String>.from(_storage[attemptId] ?? {});
  }

  @override
  Future<void> clearAnswers(String attemptId) async {
    _storage.remove(attemptId);
  }
}

// ---------------------------------------------------------------------------
// High-Stakes Exam Realistic Server Repository
// ---------------------------------------------------------------------------
class SimulatedHighStakesExamsRepository implements ExamsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  bool networkOnline = true;
  int syncAttemptsCount = 0;
  int submitAttemptsCount = 0;

  final ExamEntity satPracticeExam = ExamEntity(
    id: 'exam-sat-practice-01',
    contentId: 'cnt-sat-01',
    tenantId: 'tenant-1',
    groupId: 'group-sat-masters',
    title: 'Digital SAT 2026 Practice Test: Advanced Math & Quadratics',
    durationMinutes: 45,
    maxScore: 100,
    passingScore: 75,
    shuffleQuestions: true,
    showResult: true,
    allowRetake: true,
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
    updatedAt: DateTime.now(),
    activeVersion: ExamVersionEntity(
      id: 'version-sat-01',
      examId: 'exam-sat-practice-01',
      versionNumber: 1,
      status: ExamStatus.published,
      createdAt: DateTime.now(),
      questions: List.generate(
        10,
        (i) {
          final qId = 'q-${i + 1}';
          return ExamQuestionEntity(
            id: qId,
            examVersionId: 'version-sat-01',
            questionText: 'SAT Question ${i + 1}: Solve for x when 2x² - 8 = 0',
            questionType: QuestionType.multipleChoice,
            points: 10,
            sortOrder: i + 1,
            options: [
              QuestionOptionEntity(id: '$qId-correct', questionId: qId, optionText: 'x = ±2', sortOrder: 1),
              QuestionOptionEntity(id: '$qId-wrong-a', questionId: qId, optionText: 'x = 4', sortOrder: 2),
              QuestionOptionEntity(id: '$qId-wrong-b', questionId: qId, optionText: 'x = ±4', sortOrder: 3),
              QuestionOptionEntity(id: '$qId-wrong-c', questionId: qId, optionText: 'x = 8', sortOrder: 4),
            ],
          );
        },
      ),
    ),
  );

  ExamAttemptEntity? currentAttempt;
  final List<MistakeQuestionEntity> studentMistakes = [];

  @override
  Future<Result<ExamAttemptEntity>> startExam(String examId) async {
    if (!networkOnline) {
      return const FailureResult(NetworkFailure('No internet connection'));
    }

    final attempt = ExamAttemptEntity(
      id: 'attempt-sat-999',
      examId: examId,
      examVersionId: satPracticeExam.activeVersion!.id,
      studentId: 'student-sat-01',
      score: null,
      percentage: null,
      startedAt: DateTime.now(),
      submittedAt: null,
      status: AttemptStatus.inProgress,
      submissionReason: ExamSubmissionReason.studentSubmitted,
    );

    currentAttempt = attempt;
    return Success(attempt);
  }

  @override
  Future<Result<void>> syncExamAnswers({
    required String attemptId,
    required Map<String, String> answers,
  }) async {
    syncAttemptsCount++;
    if (!networkOnline) {
      return const FailureResult(NetworkFailure('Network unreachable: saved to local draft'));
    }
    return const Success(null);
  }

  @override
  Future<Result<ExamAttemptEntity>> submitExam({
    required String attemptId,
    required Map<String, String> answers,
    ExamSubmissionReason reason = ExamSubmissionReason.studentSubmitted,
  }) async {
    submitAttemptsCount++;
    if (!networkOnline) {
      return const FailureResult(NetworkFailure('Network down during final submission'));
    }

    // SERVER-SIDE SCORING & ZERO-CLIENT-TRUST VALIDATION
    int earnedPoints = 0;
    studentMistakes.clear();

    for (int i = 1; i <= 10; i++) {
      final qId = 'q-$i';
      final selectedOpt = answers[qId];
      final correctOpt = '$qId-correct';

      if (selectedOpt == correctOpt) {
        earnedPoints += 10;
      } else {
        // Record into Mistakes Bank
        studentMistakes.add(MistakeQuestionEntity(
          mistakeId: 'mstk-$qId',
          questionId: qId,
          questionText: 'SAT Question $i: Solve for x when 2x² - 8 = 0',
          questionType: 'multiple_choice',
          points: 10,
          sortOrder: i,
          isResolved: false,
          failureCount: 1,
          sourceExamId: satPracticeExam.id,
          sourceExamTitle: satPracticeExam.title,
          lastSelectedOptionId: selectedOpt,
          selectedOptionText: selectedOpt != null ? 'Option $selectedOpt' : 'لم تتم الإجابة',
          options: const [],
        ));
      }
    }

    final double percentage = (earnedPoints / satPracticeExam.maxScore) * 100;

    final submittedAttempt = ExamAttemptEntity(
      id: attemptId,
      examId: satPracticeExam.id,
      examVersionId: satPracticeExam.activeVersion!.id,
      studentId: 'student-sat-01',
      score: earnedPoints,
      percentage: percentage,
      startedAt: currentAttempt?.startedAt ?? DateTime.now().subtract(const Duration(minutes: 45)),
      submittedAt: DateTime.now(),
      status: AttemptStatus.submitted,
      submissionReason: reason,
    );

    currentAttempt = submittedAttempt;
    return Success(submittedAttempt);
  }

  @override
  Future<Result<MistakeSummaryEntity>> getStudentMistakesSummary(String studentId) async {
    final unresolved = studentMistakes.where((m) => !m.isResolved).length;
    final resolved = studentMistakes.where((m) => m.isResolved).length;
    return Success(MistakeSummaryEntity(
      totalMistakes: studentMistakes.length,
      unresolvedCount: unresolved,
      resolvedCount: resolved,
      unresolvedWrongCount: unresolved,
      unresolvedSkippedCount: 0,
      sources: const [],
    ));
  }

  @override
  Future<Result<List<MistakeQuestionEntity>>> getStudentMistakesQuestions(
    String studentId, {
    String? examId,
    bool onlyUnresolved = true,
  }) async {
    final list = onlyUnresolved ? studentMistakes.where((m) => !m.isResolved).toList() : studentMistakes;
    return Success(list);
  }

  @override
  Future<Result<MistakePracticeResultEntity>> submitMistakesPractice(
    List<Map<String, String>> answers,
  ) async {
    int correct = 0;
    for (final item in answers) {
      final qId = item['question_id'];
      final optId = item['selected_option_id'];
      if (optId == '$qId-correct') {
        correct++;
        final idx = studentMistakes.indexWhere((m) => m.questionId == qId);
        if (idx != -1) {
          studentMistakes[idx] = MistakeQuestionEntity(
            mistakeId: studentMistakes[idx].mistakeId,
            questionId: studentMistakes[idx].questionId,
            questionText: studentMistakes[idx].questionText,
            questionType: studentMistakes[idx].questionType,
            points: studentMistakes[idx].points,
            sortOrder: studentMistakes[idx].sortOrder,
            isResolved: true,
            failureCount: studentMistakes[idx].failureCount,
            sourceExamId: studentMistakes[idx].sourceExamId,
            sourceExamTitle: studentMistakes[idx].sourceExamTitle,
            lastSelectedOptionId: optId,
            selectedOptionText: 'Correct Solution',
            options: const [],
          );
        }
      }
    }

    return Success(MistakePracticeResultEntity(
      totalQuestions: answers.length,
      correctCount: correct,
      percentage: (correct / answers.length) * 100,
      results: const [],
    ));
  }

  @override
  Future<Result<List<ExamEntity>>> getStudentExams({int page = 0, int pageSize = 15}) async => Success([satPracticeExam]);
  @override
  Future<Result<List<ExamEntity>>> getGroupExams(String groupId, {int page = 0, int pageSize = 15}) async => Success([satPracticeExam]);
  @override
  Future<Result<ExamEntity>> getExamDetails(String examId) async => Success(satPracticeExam);
  @override
  Future<Result<ExamEntity>> createExam({String? groupId, required String title, int durationMinutes = 60, int maxScore = 100, int? passingScore, bool shuffleQuestions = false, bool showResult = true, bool allowRetake = false, DateTime? startAt, DateTime? endAt, bool isPublished = false, String? pdfFileId, required List<ExamQuestionEntity> initialQuestions}) async => throw UnimplementedError();
  @override
  Future<Result<ExamEntity>> updateExam({required String examId, required String title, int? durationMinutes, int? maxScore, int? passingScore, bool? shuffleQuestions, bool? showResult, bool? allowRetake, DateTime? startAt, DateTime? endAt, bool? isPublished, String? pdfFileId, bool clearPdfFile = false}) async => throw UnimplementedError();
  @override
  Future<Result<ExamEntity>> updateDraftExamQuestions({required String examId, required String title, int? durationMinutes, int? maxScore, int? passingScore, bool? shuffleQuestions, bool? showResult, bool? allowRetake, DateTime? startAt, DateTime? endAt, bool? isPublished, String? pdfFileId, bool clearPdfFile = false, required List<ExamQuestionEntity> questions}) async => throw UnimplementedError();
  @override
  Future<Result<ExamVersionEntity>> publishExamVersion(String versionId) async => throw UnimplementedError();
  @override
  Future<Result<void>> unpublishExamVersion({required String examId, required String versionId}) async => const Success(null);
  @override
  Future<Result<ExamVersionEntity>> createNewExamVersion(String examId) async => throw UnimplementedError();
  @override
  Future<Result<ExamAttemptEntity>> getAttemptDetails(String attemptId) async => Success(currentAttempt!);
  @override
  Future<Result<List<ExamAttemptEntity>>> getExamAttempts(String examId, {int page = 0, int pageSize = 50}) async => const Success([]);
  @override
  Future<Result<void>> convertExamType({required String examId, required String contentId, required bool toLectureExam, required String groupId}) async => const Success(null);
  @override
  Future<Result<bool>> deleteExam({required String examId, bool force = false}) async => const Success(true);
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
  Future<Result<bool>> updateMistakeReflection({
    required String mistakeId,
    required String? reflectionReason,
  }) async => const Success(true);
  @override
  Future<Result<bool>> moveExamToFolder({required String examId, String? folderId}) async => const Success(true);
  @override
  Future<Result<List<Map<String, dynamic>>>> getGroupLessons(String groupId) async => const Success([]);
  @override
  Future<Result<String>> getSignedPdfUrl(String storagePath, {String? storageProvider}) async => const Success('https://storage.supabase.co/file.pdf');
  @override
  Future<Result<void>> linkExamToLesson({required String examId, required String lessonId, required String groupId}) async => const Success(null);
  @override
  Future<Result<void>> unlinkExamFromLesson({required String examId, required String groupId, bool makeGeneralExam = false}) async => const Success(null);
}

// ---------------------------------------------------------------------------
// Simulation Test Suite
// ---------------------------------------------------------------------------
void main() {
  setUp(() {
    AppCache.clearAll();
  });

  group('🎓 [High-Stakes SAT Digital Exam Real-World Simulation]', () {
    late SimulatedHighStakesExamsRepository examsRepo;
    late SimulatedExamAnswersLocalDataSource localDataSource;
    late ExamsCubit examsCubit;

    setUp(() {
      examsRepo = SimulatedHighStakesExamsRepository();
      localDataSource = SimulatedExamAnswersLocalDataSource();
      examsCubit = ExamsCubit(
        repository: examsRepo,
        answersStorage: localDataSource,
      );
    });

    tearDown(() {
      examsCubit.close();
    });

    test(
      'Phase 1: Student initiates timed exam -> Verifies attempt creation with clean state',
      () async {
        final success = await examsCubit.startExamTaking(examsRepo.satPracticeExam);
        expect(success, isTrue);

        expect(examsCubit.state, isA<ExamTakingState>());
        final takingState = examsCubit.state as ExamTakingState;

        expect(takingState.attempt.id, equals('attempt-sat-999'));
        expect(takingState.attempt.examId, equals('exam-sat-practice-01'));
        expect(takingState.attempt.isInProgress, isTrue);
        expect(takingState.attempt.score, isNull, reason: 'Scores must never be computed or set on start');
        expect(takingState.attempt.percentage, isNull);
        expect(takingState.questions.length, equals(10));
      },
    );

    test(
      'Phase 2 & 3: Answer drafting with Sudden Network Drop -> Local draft persistence prevents data loss',
      () async {
        // Start Exam
        await examsCubit.startExamTaking(examsRepo.satPracticeExam);
        const attemptId = 'attempt-sat-999';

        // Student answers Questions 1, 2, 3 while network is online
        examsCubit.selectAnswer('q-1', 'q-1-correct');
        examsCubit.selectAnswer('q-2', 'q-2-correct');
        examsCubit.selectAnswer('q-3', 'q-3-correct');

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(localDataSource.saveCount, greaterThanOrEqualTo(1));

        var savedDraft = await localDataSource.getAnswers(attemptId);
        expect(savedDraft.length, equals(3));
        expect(savedDraft['q-1'], equals('q-1-correct'));

        // SUDDEN NETWORK FAILURE: Student enters elevator / Wi-Fi drops
        examsRepo.networkOnline = false;

        // Student continues solving questions 4, 5, 6, 7 while completely offline
        examsCubit.selectAnswer('q-4', 'q-4-correct');
        examsCubit.selectAnswer('q-5', 'q-5-correct');
        examsCubit.selectAnswer('q-6', 'q-6-wrong-a'); // deliberate wrong answer
        examsCubit.selectAnswer('q-7', 'q-7-wrong-b'); // deliberate wrong answer

        await Future<void>.delayed(const Duration(milliseconds: 50));

        savedDraft = await localDataSource.getAnswers(attemptId);
        expect(savedDraft.length, equals(7), reason: 'Zero data loss: all 7 answers preserved in local draft');
        expect(savedDraft['q-6'], equals('q-6-wrong-a'));
      },
    );

    test(
      'Phase 4 & 5: Network restores -> Timer expires -> Auto-submit triggered with timeExpired reason',
      () async {
        // Start Exam
        await examsCubit.startExamTaking(examsRepo.satPracticeExam);

        // Solve all 10 questions (7 correct, 3 wrong)
        examsCubit.selectAnswer('q-1', 'q-1-correct');
        examsCubit.selectAnswer('q-2', 'q-2-correct');
        examsCubit.selectAnswer('q-3', 'q-3-correct');
        examsCubit.selectAnswer('q-4', 'q-4-correct');
        examsCubit.selectAnswer('q-5', 'q-5-correct');
        examsCubit.selectAnswer('q-6', 'q-6-correct');
        examsCubit.selectAnswer('q-7', 'q-7-correct');
        examsCubit.selectAnswer('q-8', 'q-8-wrong-a'); // WRONG
        examsCubit.selectAnswer('q-9', 'q-9-wrong-b'); // WRONG
        examsCubit.selectAnswer('q-10', 'q-10-wrong-c'); // WRONG

        // Network Restores
        examsRepo.networkOnline = true;

        // TIMER EXPIRY: 45:00 hits 00:00 -> auto-submit triggered with timeExpired
        final submitted = await examsCubit.submitExam(reason: ExamSubmissionReason.timeExpired);
        expect(submitted, isTrue);

        expect(examsCubit.state, isA<ExamTakingState>());
        final takingState = examsCubit.state as ExamTakingState;

        // Verification of Server-Side Scoring & Zero Client Trust
        expect(takingState.submitSuccess, isTrue);
        final result = takingState.submitResult!;
        expect(result.status, equals(AttemptStatus.submitted));
        expect(result.submissionReason, equals(ExamSubmissionReason.timeExpired));
        expect(result.score, equals(70), reason: '7 correct questions x 10 points = 70 points');
        expect(result.percentage, equals(70.0));
        expect(result.isPassed(75), isFalse, reason: 'Passing score was 75%, student achieved 70% -> failed');
      },
    );

    test(
      'Phase 6: Mistakes Cataloging & Remediation -> Practicing and resolving failed questions',
      () async {
        // Submit exam with 3 wrong answers to populate mistakes
        await examsRepo.submitExam(
          attemptId: 'attempt-sat-999',
          answers: {
            'q-1': 'q-1-correct',
            'q-2': 'q-2-correct',
            'q-3': 'q-3-correct',
            'q-4': 'q-4-correct',
            'q-5': 'q-5-correct',
            'q-6': 'q-6-correct',
            'q-7': 'q-7-correct',
            'q-8': 'q-8-wrong-a', // WRONG
            'q-9': 'q-9-wrong-b', // WRONG
            'q-10': 'q-10-wrong-c', // WRONG
          },
        );

        // Step 1: Query student's mistakes summary
        final summaryResult = await examsRepo.getStudentMistakesSummary('student-sat-01');
        expect(summaryResult.isSuccess, isTrue);
        final summary = summaryResult.dataOrNull!;
        expect(summary.totalMistakes, equals(3));
        expect(summary.unresolvedCount, equals(3));
        expect(summary.resolvedCount, equals(0));

        // Step 2: Student enters Mistakes Practice Mode (only loads unresolved questions)
        final questionsResult = await examsRepo.getStudentMistakesQuestions('student-sat-01', onlyUnresolved: true);
        expect(questionsResult.isSuccess, isTrue);
        final unresolvedQuestions = questionsResult.dataOrNull!;
        expect(unresolvedQuestions.length, equals(3));
        expect(unresolvedQuestions.map((q) => q.questionId), containsAll(['q-8', 'q-9', 'q-10']));

        // Step 3: Student solves the 3 mistakes with correct answers
        final practiceSubmission = [
          {'question_id': 'q-8', 'selected_option_id': 'q-8-correct'},
          {'question_id': 'q-9', 'selected_option_id': 'q-9-correct'},
          {'question_id': 'q-10', 'selected_option_id': 'q-10-correct'},
        ];

        final practiceResult = await examsRepo.submitMistakesPractice(practiceSubmission);
        expect(practiceResult.isSuccess, isTrue);
        final practiceData = practiceResult.dataOrNull!;
        expect(practiceData.correctCount, equals(3));
        expect(practiceData.percentage, equals(100.0));

        // Step 4: Verification of resolution
        final updatedSummaryResult = await examsRepo.getStudentMistakesSummary('student-sat-01');
        final updatedSummary = updatedSummaryResult.dataOrNull!;
        expect(updatedSummary.unresolvedCount, equals(0), reason: 'All mistakes successfully resolved!');
        expect(updatedSummary.resolvedCount, equals(3));
      },
    );
  });
}
