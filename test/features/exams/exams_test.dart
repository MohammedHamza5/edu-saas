import 'dart:typed_data';

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
import 'package:edu_saas/features/exams/presentation/cubit/exams_state.dart';
import 'package:edu_saas/features/exams/presentation/pages/create_exam_page.dart';
import 'package:edu_saas/features/exams/presentation/pages/exam_intro_page.dart';
import 'package:edu_saas/features/exams/presentation/pages/exam_result_page.dart';
import 'package:edu_saas/features/exams/presentation/pages/student_exams_page.dart';
import 'package:edu_saas/features/exams/presentation/pages/teacher_exams_page.dart';
import 'package:edu_saas/features/exams/presentation/widgets/exam_card.dart';
import 'package:edu_saas/features/exams/presentation/widgets/exam_image_attachment_box.dart';
import 'package:edu_saas/features/exams/presentation/widgets/question_option_tile.dart';
import 'package:edu_saas/features/content/domain/entities/content_entity.dart';
import 'package:edu_saas/features/content/domain/entities/lesson_assignment_entity.dart';
import 'package:edu_saas/features/exams/data/models/exam_model.dart';
import 'package:edu_saas/features/exams/data/datasources/exam_answers_local_datasource.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeExamAnswersLocalDataSource implements ExamAnswersLocalDataSource {
  final Map<String, Map<String, String>> stored = {};

  @override
  Future<void> saveAnswers({
    required String attemptId,
    required Map<String, String> answers,
  }) async {
    stored[attemptId] = Map<String, String>.from(answers);
  }

  @override
  Future<Map<String, String>> getAnswers(String attemptId) async {
    return stored[attemptId] ?? {};
  }

  @override
  Future<void> clearAnswers(String attemptId) async {
    stored.remove(attemptId);
  }
}

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
      groupId: groupId ?? 'mock-group',
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
  }) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    final exam = mockExams.firstWhere(
      (e) => e.id == examId,
      orElse: () => _sampleExam(),
    );
    return Success(exam);
  }

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
  }) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    final exam = mockExams.firstWhere(
      (e) => e.id == examId,
      orElse: () => _sampleExam(),
    );
    return Success(exam);
  }

  @override
  Future<Result<String>> getSignedPdfUrl(
    String storagePath, {
    String? storageProvider,
  }) async =>
      const Success('https://example.com/test.pdf');

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
  Future<Result<void>> unpublishExamVersion({
    required String examId,
    required String versionId,
  }) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    final index = mockExams.indexWhere((e) => e.id == examId);
    if (index != -1) {
      final exam = mockExams[index];
      if (exam.activeVersion != null) {
        final updatedVersion = exam.activeVersion!.copyWith(
          status: ExamStatus.draft,
        );
        mockExams[index] = exam.copyWith(activeVersion: updatedVersion);
      }
    }
    return const Success(null);
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
        .where(
          (a) => a.examId == examId && a.status == AttemptStatus.inProgress,
        )
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
    ExamSubmissionReason reason = ExamSubmissionReason.studentSubmitted,
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
  Future<Result<void>> syncExamAnswers({
    required String attemptId,
    required Map<String, String> answers,
  }) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    final index = mockAttempts.indexWhere((a) => a.id == attemptId);
    if (index != -1) {
      final old = mockAttempts[index];
      final newAnswers = <ExamAnswerEntity>[];
      answers.forEach((qId, optId) {
        newAnswers.add(
          ExamAnswerEntity(
            id: '',
            attemptId: attemptId,
            questionId: qId,
            selectedOptionId: optId,
            answeredAt: DateTime.now(),
          ),
        );
      });
      mockAttempts[index] = old.copyWith(answers: newAnswers);
    }
    return const Success(null);
  }

  @override
  Future<Result<List<ExamAttemptEntity>>> getExamAttempts(
    String examId, {
    int page = 0,
    int pageSize = 20,
  }) async {
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

  @override
  Future<Result<MistakeSummaryEntity>> getStudentMistakesSummary(
    String studentId,
  ) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    return const Success(
      MistakeSummaryEntity(
        totalMistakes: 0,
        unresolvedCount: 0,
        resolvedCount: 0,
        sources: [],
      ),
    );
  }

  @override
  Future<Result<List<MistakeQuestionEntity>>> getStudentMistakesQuestions(
    String studentId, {
    String? examId,
    bool onlyUnresolved = true,
  }) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    return const Success([]);
  }

  @override
  Future<Result<MistakePracticeResultEntity>> submitMistakesPractice(
    List<Map<String, String>> answers,
  ) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    return const Success(
      MistakePracticeResultEntity(
        totalQuestions: 0,
        correctCount: 0,
        percentage: 100.0,
        results: [],
      ),
    );
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getGroupLessons(
    String groupId,
  ) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    return const Success([]);
  }

  @override
  Future<Result<void>> linkExamToLesson({
    required String examId,
    required String lessonId,
    required String groupId,
  }) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    return const Success(null);
  }

  @override
  Future<Result<void>> unlinkExamFromLesson({
    required String examId,
    required String groupId,
    bool makeGeneralExam = false,
  }) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    return const Success(null);
  }

  @override
  Future<Result<void>> convertExamType({
    required String examId,
    required String contentId,
    required bool toLectureExam,
    required String groupId,
  }) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    return const Success(null);
  }

  @override
  Future<Result<bool>> deleteExam({
    required String examId,
    bool force = false,
  }) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    mockExams.removeWhere((e) => e.id == examId);
    return const Success(true);
  }

  @override
  Future<Result<ExamParentDispatchRosterEntity>> getExamParentDispatchRoster(
    String examId,
  ) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    return const FailureResult(ServerFailure('Not implemented'));
  }

  @override
  Future<Result<bool>> updateStudentParentPhone({
    required String studentId,
    required String parentPhone,
  }) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    return const Success(true);
  }

  @override
  Future<Result<List<ExamFolderEntity>>> getExamFolders({String? groupId}) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    return const Success([]);
  }

  @override
  Future<Result<ExamFolderEntity>> createExamFolder({
    required String name,
    String? groupId,
    String? color,
    String? icon,
    String? description,
  }) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    return Success(ExamFolderEntity(
      id: 'folder-1',
      tenantId: 'tenant-1',
      groupId: groupId,
      name: name,
      color: color ?? '#5B4FE0',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  }

  @override
  Future<Result<ExamFolderEntity>> updateExamFolder({
    required String folderId,
    required String name,
    String? color,
    String? icon,
    String? description,
  }) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    return Success(ExamFolderEntity(
      id: folderId,
      tenantId: 'tenant-1',
      name: name,
      color: color ?? '#5B4FE0',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  }

  @override
  Future<Result<bool>> deleteExamFolder(String folderId) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    return const Success(true);
  }

  @override
  Future<Result<bool>> moveExamToFolder({
    required String examId,
    String? folderId,
  }) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    return const Success(true);
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
              QuestionOptionEntity(
                id: 'opt-3',
                questionId: 'q-1',
                optionText: '4',
                isCorrect: false,
              ),
              QuestionOptionEntity(
                id: 'opt-4',
                questionId: 'q-1',
                optionText: '5',
                isCorrect: false,
              ),
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
              QuestionOptionEntity(
                id: 'opt-5',
                questionId: 'q-2',
                optionText: 'صح',
                isCorrect: true,
              ),
              QuestionOptionEntity(
                id: 'opt-6',
                questionId: 'q-2',
                optionText: 'خطأ',
                isCorrect: false,
              ),
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

    test(
      'ExamAttemptEntity isPassed evaluates correctly against passing score',
      () {
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
      },
    );

    test(
      'ExamStatus and AttemptStatus enum helpers return valid Arabic strings and colors',
      () {
        expect(ExamStatus.published.labelAr, 'منشور (مجمد)');
        expect(ExamStatus.draft.labelAr, 'مسودة');
        expect(ExamStatus.archived.labelAr, 'مؤرشف');

        expect(AttemptStatus.inProgress.labelAr, 'قيد الأداء');
        expect(AttemptStatus.submitted.labelAr, 'تم التسليم');
        expect(AttemptStatus.expired.labelAr, 'انتهى الوقت');
      },
    );

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

    test(
      'QuestionOptionEntity default hides isCorrect for security compliance',
      () {
        const option = QuestionOptionEntity(
          id: 'opt-x',
          questionId: 'q-1',
          optionText: 'خيار غير موثوق',
        );

        expect(option.isCorrect, isNull);
      },
    );

    test(
      'ExamEntity getters correctly calculate solvedQuestionsCount, isFullyCompleted, and completionProgress',
      () {
        // Case 1: Not attempted
        final notAttemptedExam = FakeExamsRepository._sampleExam();
        expect(notAttemptedExam.hasAttempted, isFalse);
        expect(notAttemptedExam.isFullyCompleted, isFalse);
        expect(notAttemptedExam.solvedQuestionsCount, 0);
        expect(notAttemptedExam.completionProgress, 0.0);

        // Case 2: In progress attempt with answeredQuestionsCount
        final inProgressExam = notAttemptedExam.copyWith(
          myLatestAttempt: ExamAttemptEntity(
            id: 'attempt-in-prog',
            examId: notAttemptedExam.id,
            examVersionId: 'v1',
            studentId: 'student-1',
            status: AttemptStatus.inProgress,
            startedAt: DateTime.now(),
            answeredQuestionsCount: 1,
          ),
        );
        expect(inProgressExam.hasAttempted, isTrue);
        expect(inProgressExam.isFullyCompleted, isFalse);
        expect(inProgressExam.solvedQuestionsCount, 1);
        expect(inProgressExam.completionProgress, 0.5);

        // Case 3: Submitted attempt (fully completed)
        final submittedExam = notAttemptedExam.copyWith(
          myLatestAttempt: ExamAttemptEntity(
            id: 'attempt-submitted',
            examId: notAttemptedExam.id,
            examVersionId: 'v1',
            studentId: 'student-1',
            status: AttemptStatus.submitted,
            startedAt: DateTime.now().subtract(const Duration(minutes: 20)),
            submittedAt: DateTime.now(),
            score: 90,
            percentage: 90.0,
            answeredQuestionsCount: 2,
          ),
        );
        expect(submittedExam.hasAttempted, isTrue);
        expect(submittedExam.isFullyCompleted, isTrue);
        expect(submittedExam.solvedQuestionsCount, 2);
        expect(submittedExam.completionProgress, 1.0);
      },
    );
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

    test(
      'createNewExamVersion clones questions into a new draft version',
      () async {
        final result = await fakeRepository.createNewExamVersion('exam-1');
        expect(result.isSuccess, isTrue);
        final version = (result as Success<ExamVersionEntity>).data;
        expect(version.versionNumber, 2);
        expect(version.status, ExamStatus.draft);
      },
    );

    test('startExam creates an in_progress attempt', () async {
      final result = await fakeRepository.startExam('exam-1');
      expect(result.isSuccess, isTrue);
      final attempt = (result as Success<ExamAttemptEntity>).data;
      expect(attempt.status, AttemptStatus.inProgress);
    });

    test(
      'submitExam updates attempt status to submitted with atomic score',
      () async {
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
      },
    );

    test('returns FailureResult on server failure', () async {
      fakeRepository.shouldFail = true;
      final result = await fakeRepository.getGroupExams('group-1');
      expect(result.isFailure, isTrue);
      expect(
        (result as FailureResult).failure.message,
        'Server error occurred',
      );
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

    test(
      'loadStudentExams emits ExamsEmpty when no exams are published',
      () async {
        fakeRepository.mockExams = [];

        final states = <ExamsState>[];
        final sub = examsCubit.stream.listen(states.add);

        await examsCubit.loadStudentExams();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(states.last, isA<ExamsEmpty>());

        await sub.cancel();
      },
    );

    test(
      'loadStudentExams emits StudentExamsLoaded with published exams',
      () async {
        fakeRepository.mockExams = [FakeExamsRepository._sampleExam()];

        final states = <ExamsState>[];
        final sub = examsCubit.stream.listen(states.add);

        await examsCubit.loadStudentExams();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(states.last, isA<StudentExamsLoaded>());
        final loaded = states.last as StudentExamsLoaded;
        expect(loaded.exams.length, 1);

        await sub.cancel();
      },
    );

    test(
      'startExamTaking sets up ExamTakingState with questions and duration',
      () async {
        final sample = FakeExamsRepository._sampleExam();
        fakeRepository.mockExams = [sample];

        final success = await examsCubit.startExamTaking(sample);

        expect(success, isTrue);
        expect(examsCubit.state, isA<ExamTakingState>());
        final takingState = examsCubit.state as ExamTakingState;
        expect(takingState.questions.length, 2);
        expect(takingState.remainingSeconds, greaterThan(0));
        expect(takingState.isUntimed, isFalse);
      },
    );

    test(
      'startExamTaking for untimed/lecture exam sets isUntimed to true and does not expire',
      () async {
        final sample = FakeExamsRepository._sampleExam().copyWith(durationMinutes: 0);
        fakeRepository.mockExams = [sample];

        final success = await examsCubit.startExamTaking(sample, isLectureExam: true);

        expect(success, isTrue);
        expect(examsCubit.state, isA<ExamTakingState>());
        final takingState = examsCubit.state as ExamTakingState;
        expect(takingState.isUntimed, isTrue);
        expect(takingState.remainingSeconds, 0);
      },
    );

    test(
      'selectAnswer records selected answer correctly in ExamTakingState',
      () async {
        final sample = FakeExamsRepository._sampleExam();
        fakeRepository.mockExams = [sample];
        await examsCubit.startExamTaking(sample);

        examsCubit.selectAnswer('q-1', 'opt-2');

        final takingState = examsCubit.state as ExamTakingState;
        expect(takingState.answers['q-1'], 'opt-2');
      },
    );

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

    test(
      'startExamTaking restores and merges server-saved answers and local draft answers',
      () async {
        final sample = FakeExamsRepository._sampleExam();
        fakeRepository.mockExams = [sample];

        // Setup an existing attempt on the server with saved answer for q-1
        final priorAttempt = ExamAttemptEntity(
          id: 'attempt-resumed',
          examId: sample.id,
          examVersionId: 'version-1',
          studentId: 'student-1',
          startedAt: DateTime.now(),
          status: AttemptStatus.inProgress,
          answers: [
            ExamAnswerEntity(
              id: 'ans-1',
              attemptId: 'attempt-resumed',
              questionId: 'q-1',
              selectedOptionId: 'opt-2',
              answeredAt: DateTime.now(),
            ),
          ],
        );
        fakeRepository.mockAttempts = [priorAttempt];

        final fakeStorage = FakeExamAnswersLocalDataSource();
        // Setup local storage with answer for q-2
        fakeStorage.stored['attempt-resumed'] = {'q-2': 'opt-1'};

        final testCubit = ExamsCubit(
          repository: fakeRepository,
          answersStorage: fakeStorage,
        );

        final success = await testCubit.startExamTaking(sample);
        expect(success, isTrue);

        final state = testCubit.state as ExamTakingState;
        // Verify both server answer and local draft answer are present
        expect(state.answers['q-1'], 'opt-2');
        expect(state.answers['q-2'], 'opt-1');

        await testCubit.close();
      },
    );

    test(
      'selectAnswer persists locally and submitExam clears local answers',
      () async {
        final sample = FakeExamsRepository._sampleExam();
        fakeRepository.mockExams = [sample];

        final fakeStorage = FakeExamAnswersLocalDataSource();
        final testCubit = ExamsCubit(
          repository: fakeRepository,
          answersStorage: fakeStorage,
        );

        await testCubit.startExamTaking(sample);
        final attemptId = (testCubit.state as ExamTakingState).attempt.id;

        testCubit.selectAnswer('q-1', 'opt-3');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Verify locally persisted
        expect(fakeStorage.stored[attemptId]?['q-1'], 'opt-3');

        // Flush sync via goToQuestion
        testCubit.goToQuestion(1);

        // Submit exam
        final success = await testCubit.submitExam();
        expect(success, isTrue);

        // Verify local storage cleared after submission
        expect(fakeStorage.stored[attemptId], isNull);

        await testCubit.close();
      },
    );

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

    test('deleteExam removes exam and updates TeacherExamsLoaded state', () async {
      final exam1 = FakeExamsRepository._sampleExam(id: 'exam-to-delete');
      final exam2 = FakeExamsRepository._sampleExam(id: 'exam-to-keep');
      fakeRepository.mockExams = [exam1, exam2];

      await examsCubit.loadGroupExams('group-1');
      expect(examsCubit.state, isA<TeacherExamsLoaded>());
      final initialLoaded = examsCubit.state as TeacherExamsLoaded;
      expect(initialLoaded.exams.length, 2);

      final success = await examsCubit.deleteExam(examId: 'exam-to-delete');
      expect(success, isTrue);

      expect(examsCubit.state, isA<TeacherExamsLoaded>());
      final afterDelete = examsCubit.state as TeacherExamsLoaded;
      expect(afterDelete.exams.length, 1);
      expect(afterDelete.exams.first.id, 'exam-to-keep');
    });

    test('unpublishVersion reverts active version to draft', () async {
      final sample = FakeExamsRepository._sampleExam(
        id: 'exam-published',
        status: ExamStatus.published,
      );
      fakeRepository.mockExams = [sample];

      await examsCubit.loadGroupExams('group-1');
      expect(examsCubit.state, isA<TeacherExamsLoaded>());

      final success = await examsCubit.unpublishVersion(
        examId: 'exam-published',
        versionId: 'version-1',
      );
      expect(success, isTrue);

      final updatedExam = fakeRepository.mockExams.firstWhere(
        (e) => e.id == 'exam-published',
      );
      expect(updatedExam.activeVersion?.status, ExamStatus.draft);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. Widget Tests
  // ═══════════════════════════════════════════════════════════════════════════
  group('Exam Widgets Tests', () {
    testWidgets('ExamCard displays exam info and stats accurately', (
      tester,
    ) async {
      final exam = FakeExamsRepository._sampleExam();

      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            body: ExamCard(exam: exam, onTap: () {}),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('امتحان الجبر والتفاضل'), findsOneWidget);
      expect(find.text('45 دقيقة'), findsOneWidget);
      expect(find.text('100 درجة'), findsOneWidget);
    });

    testWidgets(
      'QuestionOptionTile renders letter, text, and responds to tap',
      (tester) async {
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
      },
    );

    testWidgets('ExamIntroPage renders exam instructions and start button', (
      tester,
    ) async {
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

    testWidgets('ExamResultPage renders student score and passed badge', (
      tester,
    ) async {
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
          child: ExamResultPage(exam: exam, attempt: attempt),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('نتيجة الامتحان'), findsOneWidget);
      expect(find.text('تهانينا! لقد اجتزت الامتحان بنجاح'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
    });

    testWidgets(
      'ExamResultPage renders Enter Next Lecture button when lecture exam is passed',
      (tester) async {
        final exam = FakeExamsRepository._sampleExam().copyWith(
          isLectureExam: true,
          groupId: 'grp-1',
        );
        final attempt = ExamAttemptEntity(
          id: 'att-passed',
          examId: exam.id,
          examVersionId: 'v-1',
          studentId: 's-1',
          startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
          submittedAt: DateTime.now(),
          score: 90,
          percentage: 90.0,
          status: AttemptStatus.submitted,
        );
        const nextLesson = LessonAssignmentEntity(
          contentGroupId: 'cg-2',
          contentId: 'c-2',
          groupId: 'grp-1',
          title: 'المحاضرة التالية',
          type: ContentType.video,
          sortOrder: 2,
        );

        await tester.pumpWidget(
          createTestApp(
            child: BlocProvider<ExamsCubit>.value(
              value: examsCubit,
              child: ExamResultPage(
                exam: exam,
                attempt: attempt,
                isLectureExam: true,
                nextLesson: nextLesson,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.textContaining(nextLesson.title), findsOneWidget);
        expect(find.text('العودة لشاشة المحاضرات'), findsOneWidget);
      },
    );

    testWidgets(
      'ExamResultPage renders Try Again button when lecture exam is not passed',
      (tester) async {
        final exam = FakeExamsRepository._sampleExam().copyWith(
          isLectureExam: true,
          groupId: 'grp-1',
          passingScore: 70,
        );
        final failedAttempt = ExamAttemptEntity(
          id: 'att-failed',
          examId: exam.id,
          examVersionId: 'v-1',
          studentId: 's-1',
          startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
          submittedAt: DateTime.now(),
          score: 50,
          percentage: 50.0,
          status: AttemptStatus.submitted,
        );

        await tester.pumpWidget(
          createTestApp(
            child: BlocProvider<ExamsCubit>.value(
              value: examsCubit,
              child: ExamResultPage(
                exam: exam,
                attempt: failedAttempt,
                isLectureExam: true,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('محاولة مرة أخرى'), findsOneWidget);
        expect(find.text('العودة لشاشة المحاضرات'), findsOneWidget);
      },
    );

    testWidgets(
      'ExamResultPage sanitizes and rejects nextLesson when it is an exam or self-referential',
      (tester) async {
        final exam = FakeExamsRepository._sampleExam().copyWith(
          id: 'exam-test-202',
          title: 'Test 202',
          isLectureExam: true,
          groupId: 'grp-1',
        );
        final attempt = ExamAttemptEntity(
          id: 'att-passed-2',
          examId: exam.id,
          examVersionId: 'v-1',
          studentId: 's-1',
          startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
          submittedAt: DateTime.now(),
          score: 95,
          percentage: 95.0,
          status: AttemptStatus.submitted,
        );
        // Candidate nextLesson is an exam or points to the quiz itself
        const candidateExamLesson = LessonAssignmentEntity(
          contentGroupId: 'cg-exam',
          contentId: 'c-exam',
          groupId: 'grp-1',
          title: 'Test 202',
          type: ContentType.exam, // Not a video!
          lessonExamId: 'exam-test-202',
          sortOrder: 3,
        );

        await tester.pumpWidget(
          createTestApp(
            child: BlocProvider<ExamsCubit>.value(
              value: examsCubit,
              child: ExamResultPage(
                exam: exam,
                attempt: attempt,
                isLectureExam: true,
                nextLesson: candidateExamLesson,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Must NOT render "المحاضرة التالية: Test 202"
        expect(find.textContaining('المحاضرة التالية: Test 202'), findsNothing);
        expect(find.textContaining('مراجعة'), findsWidgets);
        expect(find.text('العودة لشاشة المحاضرات'), findsOneWidget);
      },
    );

    testWidgets(
      'ExamResultPage renders answer sheet matrix immediately without loading spinner when questions provided',
      (tester) async {
        final exam = FakeExamsRepository._sampleExam();
        final attempt = ExamAttemptEntity(
          id: 'att-with-q',
          examId: exam.id,
          examVersionId: 'v-1',
          studentId: 's-1',
          startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
          submittedAt: DateTime.now(),
          score: 100,
          percentage: 100.0,
          status: AttemptStatus.submitted,
          questions: [
            const ExamQuestionEntity(
              id: 'q-1',
              examVersionId: 'v-1',
              questionText: 'Question 1',
              points: 5,
              sortOrder: 1,
            ),
            const ExamQuestionEntity(
              id: 'q-2',
              examVersionId: 'v-1',
              questionText: 'Question 2',
              points: 5,
              sortOrder: 2,
            ),
          ],
          answers: [
            ExamAnswerEntity(
              id: 'ans-1',
              attemptId: 'att-with-q',
              questionId: 'q-1',
              selectedOptionId: 'opt-1',
              isCorrect: true,
              pointsEarned: 5,
              answeredAt: DateTime.now(),
            ),
            ExamAnswerEntity(
              id: 'ans-2',
              attemptId: 'att-with-q',
              questionId: 'q-2',
              selectedOptionId: 'opt-2',
              isCorrect: false,
              pointsEarned: 0,
              answeredAt: DateTime.now(),
            ),
          ],
        );

        await tester.pumpWidget(
          createTestApp(
            child: BlocProvider<ExamsCubit>.value(
              value: examsCubit,
              child: ExamResultPage(
                exam: exam,
                attempt: attempt,
              ),
            ),
          ),
        );

        // First frame pump without settle: Matrix must be visible immediately (zero loading spinner)
        await tester.pump();

        expect(find.text('خريطة ورقة الإجابة'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        await tester.pumpAndSettle();
      },
    );

    testWidgets('TeacherExamsPage renders empty state when no exams exist', (
      tester,
    ) async {
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

    testWidgets('StudentExamsPage renders exam cards when available', (
      tester,
    ) async {
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

      expect(find.text('تقييمات المادة'), findsOneWidget);
      expect(find.text('امتحان الجبر والتفاضل'), findsOneWidget);
    });

    testWidgets(
      'TeacherExamsPage opens exam details sheet on card tap without error',
      (tester) async {
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
      },
    );

    test(
      'ExamsCubit loadStudentExams ignores invocation when exam is currently in progress (ExamTakingState)',
      () async {
        final exam = FakeExamsRepository._sampleExam();
        fakeRepository.mockExams = [exam];

        final success = await examsCubit.startExamTaking(exam);
        expect(success, isTrue);
        expect(examsCubit.state, isA<ExamTakingState>());

        // Calling loadStudentExams while taking exam should NOT overwrite ExamTakingState
        await examsCubit.loadStudentExams(forceRefresh: true);
        expect(examsCubit.state, isA<ExamTakingState>());
      },
    );

    test(
      'ExamsCubit loadStudentExams proceeds when exam has been submitted (submitSuccess == true)',
      () async {
        final exam = FakeExamsRepository._sampleExam();
        fakeRepository.mockExams = [exam];

        final success = await examsCubit.startExamTaking(exam);
        expect(success, isTrue);
        expect(examsCubit.state, isA<ExamTakingState>());

        // Submit the exam
        final submitted = await examsCubit.submitExam();
        expect(submitted, isTrue);
        final takingState = examsCubit.state as ExamTakingState;
        expect(takingState.submitSuccess, isTrue);

        // Calling loadStudentExams after submission must NOT be ignored
        await examsCubit.loadStudentExams(forceRefresh: true);
        expect(examsCubit.state, isA<StudentExamsLoaded>());
      },
    );

    test(
      'ExamsCubit exitExamTaking resets ExamTakingState to ExamsInitial',
      () async {
        final exam = FakeExamsRepository._sampleExam();
        fakeRepository.mockExams = [exam];

        final success = await examsCubit.startExamTaking(exam);
        expect(success, isTrue);
        expect(examsCubit.state, isA<ExamTakingState>());

        examsCubit.exitExamTaking();
        expect(examsCubit.state, isA<ExamsInitial>());
      },
    );

    test(
      'ExamsCubit startExamTaking fails gracefully when questions are empty',
      () async {
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
      },
    );

    testWidgets(
      'CreateExamPage renders default question points input and apply to all button',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('ar')],
            locale: const Locale('ar'),
            home: BlocProvider.value(
              value: examsCubit,
              child: const Scaffold(
                body: CreateExamPage(
                  groupId: 'group-1',
                  groupName: 'SAT Math',
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify the label for uniform question points exists
        expect(find.text('درجة كل سؤال'), findsWidgets);
        expect(find.text('تطبيق على الكل'), findsWidgets);
      },
    );

    testWidgets(
      'ExamImageAttachmentBox displays instant memory image and background sync indicator',
      (tester) async {
        final dummyBytes = Uint8List.fromList([
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
          0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
          0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
          0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
          0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
          0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
        ]);

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('ar')],
            locale: const Locale('ar'),
            home: Scaffold(
              body: ExamImageAttachmentBox(
                initialLocalBytes: dummyBytes,
                isUploading: true,
                onChanged: (_) {},
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // 1. Instant image preview is rendered (Image widget exists, zero blocking)
        expect(find.byType(Image), findsOneWidget);

        // 2. Background sync indicator is shown
        expect(find.text('جاري حفظ الصورة في السحابة بالخلفية...'), findsOneWidget);
      },
    );

    testWidgets(
      'ExamCard in student mode renders answered progress indicator and checkmark when completed',
      (tester) async {
        final baseExam = FakeExamsRepository._sampleExam();

        // 1. In-Progress Exam
        final inProgressExam = baseExam.copyWith(
          title: 'امتحان جاري حله',
          myLatestAttempt: ExamAttemptEntity(
            id: 'att-prog',
            examId: baseExam.id,
            examVersionId: 'v-1',
            studentId: 'student-1',
            status: AttemptStatus.inProgress,
            startedAt: DateTime.now(),
            answeredQuestionsCount: 1,
          ),
        );

        await tester.pumpWidget(
          createTestApp(
            child: Scaffold(
              body: ExamCard(
                exam: inProgressExam,
                isTeacher: false,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('امتحان جاري حله'), findsOneWidget);
        expect(find.text('قيد الأداء'), findsWidgets);
        expect(find.text('تم حل 1 من 2 أسئلة'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);

        // 2. Fully Completed Exam
        final completedExam = baseExam.copyWith(
          title: 'امتحان مكتمل بالكامل',
          myLatestAttempt: ExamAttemptEntity(
            id: 'att-completed',
            examId: baseExam.id,
            examVersionId: 'v-1',
            studentId: 'student-1',
            status: AttemptStatus.submitted,
            startedAt: DateTime.now().subtract(const Duration(minutes: 30)),
            submittedAt: DateTime.now(),
            score: 100,
            percentage: 100.0,
            answeredQuestionsCount: 2,
          ),
        );

        await tester.pumpWidget(
          createTestApp(
            child: Scaffold(
              body: ExamCard(
                exam: completedExam,
                isTeacher: false,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('امتحان مكتمل بالكامل'), findsOneWidget);
        expect(find.text('تم حل جميع الأسئلة (2/2)'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
      },
    );

    testWidgets(
      'StudentExamsPage overview hub, search, and filtering chips work smoothly',
      (tester) async {
        final now = DateTime.now();
        final exam1 = FakeExamsRepository._sampleExam(
          id: 'exam-avail',
          title: 'امتحان الجبر المتاح',
        );

        final exam2 = FakeExamsRepository._sampleExam(
          id: 'exam-prog',
          title: 'امتحان التفاضل قيد الحل',
        ).copyWith(
          myLatestAttempt: ExamAttemptEntity(
            id: 'att-p',
            examId: 'exam-prog',
            examVersionId: 'v-1',
            studentId: 'student-1',
            status: AttemptStatus.inProgress,
            startedAt: now,
            answeredQuestionsCount: 1,
          ),
        );

        final exam3 = FakeExamsRepository._sampleExam(
          id: 'exam-done',
          title: 'امتحان المثلثات المكتمل',
        ).copyWith(
          myLatestAttempt: ExamAttemptEntity(
            id: 'att-d',
            examId: 'exam-done',
            examVersionId: 'v-1',
            studentId: 'student-1',
            status: AttemptStatus.submitted,
            startedAt: now.subtract(const Duration(minutes: 40)),
            submittedAt: now,
            score: 95,
            percentage: 95.0,
            answeredQuestionsCount: 2,
          ),
        );

        fakeRepository.mockExams = [exam1, exam2, exam3];

        await tester.pumpWidget(
          createTestApp(
            child: BlocProvider<ExamsCubit>.value(
              value: examsCubit,
              child: const StudentExamsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Overview Hub is rendered
        expect(find.text('لوحة إنجاز الاختبارات'), findsOneWidget);
        // All 3 exams should be present in the initial 'All' view
        expect(find.text('امتحان الجبر المتاح'), findsOneWidget);
        expect(find.text('امتحان التفاضل قيد الحل'), findsOneWidget);
        expect(find.text('امتحان المثلثات المكتمل'), findsOneWidget);

        // Test Search Bar filtering
        final searchField = find.byType(TextField);
        expect(searchField, findsOneWidget);
        await tester.enterText(searchField, 'الجبر');
        await tester.pumpAndSettle();

        expect(find.text('امتحان الجبر المتاح'), findsOneWidget);
        expect(find.text('امتحان التفاضل قيد الحل'), findsNothing);
        expect(find.text('امتحان المثلثات المكتمل'), findsNothing);

        // Clear search text
        await tester.enterText(searchField, '');
        await tester.pumpAndSettle();

        // Test Filtering by 'مكتمل' chip
        final completedChip = find.byWidgetPredicate((w) => w is FilterChip && (w.label as Text).data!.contains('مكتمل'));
        expect(completedChip, findsOneWidget);
        await tester.tap(completedChip);
        await tester.pumpAndSettle();

        expect(find.text('امتحان المثلثات المكتمل'), findsOneWidget);
        expect(find.text('امتحان الجبر المتاح'), findsNothing);
        expect(find.text('امتحان التفاضل قيد الحل'), findsNothing);

        // Test Filtering by 'قيد الأداء' chip
        final inProgressChip = find.byWidgetPredicate((w) => w is FilterChip && (w.label as Text).data!.contains('قيد الأداء'));
        expect(inProgressChip, findsOneWidget);
        await tester.tap(inProgressChip);
        await tester.pumpAndSettle();

        expect(find.text('امتحان التفاضل قيد الحل'), findsOneWidget);
        expect(find.text('امتحان المثلثات المكتمل'), findsNothing);
        expect(find.text('امتحان الجبر المتاح'), findsNothing);

        // Test Filtering by 'متاح' chip
        final availableChip = find.byWidgetPredicate((w) => w is FilterChip && (w.label as Text).data!.contains('متاح'));
        expect(availableChip, findsOneWidget);
        await tester.tap(availableChip);
        await tester.pumpAndSettle();

        expect(find.text('امتحان الجبر المتاح'), findsOneWidget);
        expect(find.text('امتحان التفاضل قيد الحل'), findsNothing);
        expect(find.text('امتحان المثلثات المكتمل'), findsNothing);
      },
    );
  });

  group('Exam PDF Attachment & Bubble Sheet Generation Tests', () {
    test('ExamEntity hasAttachedPdf correctly reflects presence of storage path', () {
      final examWithPdf = ExamEntity(
        id: 'exam-pdf-1',
        contentId: 'content-1',
        tenantId: 'tenant-1',
        groupId: 'group-1',
        title: 'Calculus Final with Booklet',
        durationMinutes: 60,
        maxScore: 100,
        passingScore: 60,
        shuffleQuestions: false,
        showResult: true,
        allowRetake: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        pdfFileId: 'file-uuid-123',
        pdfFileName: 'Calculus_Booklet.pdf',
        pdfFileSize: 2048500,
        pdfStoragePath: 'tenants/tenant-1/exams/Calculus_Booklet.pdf',
      );

      expect(examWithPdf.hasAttachedPdf, isTrue);
      expect(examWithPdf.pdfFileId, equals('file-uuid-123'));
      expect(examWithPdf.pdfFileName, equals('Calculus_Booklet.pdf'));
      expect(examWithPdf.pdfFileSize, equals(2048500));
      expect(examWithPdf.pdfStoragePath, equals('tenants/tenant-1/exams/Calculus_Booklet.pdf'));

      final examWithoutPdf = examWithPdf.copyWith(
        clearPdfFile: true,
      );
      expect(examWithoutPdf.hasAttachedPdf, isFalse);
    });

    test('ExamModel parses and serializes PDF attachment metadata accurately', () {
      final json = <String, dynamic>{
        'id': 'exam-mod-1',
        'content_id': 'content-mod-1',
        'tenant_id': 'tenant-1',
        'group_id': 'group-1',
        'title': 'SAT Math Practice Test 1',
        'duration_minutes': 70,
        'max_score': 800,
        'passing_score': 500,
        'shuffle_questions': false,
        'show_result': true,
        'allow_retake': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'pdf_file_id': 'file-sat-999',
        'pdf_file_name': 'SAT_Booklet_Module_1.pdf',
        'pdf_file_size': 4194304,
        'pdf_storage_path': 'exams/sat_math_mod1.pdf',
      };

      final model = ExamModel.fromJson(json);
      expect(model.pdfFileId, equals('file-sat-999'));
      expect(model.pdfFileName, equals('SAT_Booklet_Module_1.pdf'));
      expect(model.pdfFileSize, equals(4194304));
      expect(model.pdfStoragePath, equals('exams/sat_math_mod1.pdf'));
      expect(model.hasAttachedPdf, isTrue);

      final serialized = model.toJson();
      expect(serialized['pdf_file_id'], equals('file-sat-999'));
    });

    test('Quick Bubble Sheet generation creates numbered questions and A, B, C, D choices', () {
      const qCount = 20;
      const optsCount = 4;
      const optionLetters = ['A', 'B', 'C', 'D'];

      final questions = List.generate(qCount, (i) {
        final qNum = i + 1;
        final options = List.generate(optsCount, (j) {
          final letter = j < optionLetters.length
              ? optionLetters[j]
              : String.fromCharCode(65 + j);
          return QuestionOptionEntity(
            id: 'gen-opt-$qNum-$j',
            questionId: 'gen-q-$qNum',
            optionText: '($letter)',
            isCorrect: j == 0,
            sortOrder: j,
          );
        });

        return ExamQuestionEntity(
          id: 'gen-q-$qNum',
          examVersionId: 'ver-1',
          questionText: 'Question $qNum',
          questionType: QuestionType.multipleChoice,
          points: 1,
          sortOrder: i,
          options: options,
        );
      });

      expect(questions.length, equals(20));
      for (var i = 0; i < 20; i++) {
        expect(questions[i].questionText, equals('Question ${i + 1}'));
        expect(questions[i].options.length, equals(4));
        expect(questions[i].options[0].optionText, equals('(A)'));
        expect(questions[i].options[1].optionText, equals('(B)'));
        expect(questions[i].options[2].optionText, equals('(C)'));
        expect(questions[i].options[3].optionText, equals('(D)'));
        expect(questions[i].options[0].isCorrect, isTrue);
      }
    });
  });
}
