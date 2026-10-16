import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/utils/cache_manager.dart';
import 'package:edu_saas/features/content/domain/entities/attached_lesson_exam_entity.dart';
import 'package:edu_saas/features/content/domain/entities/chapter_entity.dart';
import 'package:edu_saas/features/content/domain/entities/content_entity.dart';
import 'package:edu_saas/features/content/domain/entities/lesson_assignment_entity.dart';
import 'package:edu_saas/features/content/domain/repositories/content_repository.dart';
import 'package:edu_saas/features/content/presentation/cubit/course_progress_cubit.dart';
import 'package:edu_saas/features/content/presentation/cubit/course_progress_state.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// SIMULATED GATED LEARNING BACKEND ENGINE
// ---------------------------------------------------------------------------
class _SimulatedCurriculumBackend {
  final String groupId = 'grp-sat-masters';
  final String tenantId = 'tenant-academic-1';

  // Chapters
  final List<ChapterEntity> chapters = [
    const ChapterEntity(
      id: 'ch-01',
      title: 'Chapter 1: Advanced SAT Algebra & Quadratics',
      sortOrder: 1,
      isPublished: true,
    ),
  ];

  // Base syllabus lessons for this group: contentId -> LessonAssignmentEntity
  final Map<String, LessonAssignmentEntity> syllabusLessons = {};

  // Student-specific progress overrides: "studentId:contentId" -> LessonAssignmentEntity
  final Map<String, LessonAssignmentEntity> studentLessonStates = {};

  // Student exam attempt records: "studentId:examId" -> attempts history
  final Map<String, List<Map<String, dynamic>>> studentExamScores = {};

  // Manual unlock overrides granted by teacher: "studentId:contentId" -> reason
  final Map<String, String> manualUnlockOverrides = {};

  // Audit trail
  final List<Map<String, dynamic>> auditLog = [];

  _SimulatedCurriculumBackend() {
    _initSyllabus();
  }

  void _initSyllabus() {
    // Lesson 1: Quadratics Masterclass (Unlocked by default as first lesson)
    syllabusLessons['les-01'] = const LessonAssignmentEntity(
      contentGroupId: 'cg-01',
      contentId: 'les-01',
      groupId: 'grp-sat-masters',
      title: 'Lesson 1: Quadratic Equations Masterclass',
      sortOrder: 1,
      chapterId: 'ch-01',
      chapterTitle: 'Chapter 1: Advanced SAT Algebra & Quadratics',
      access: LessonAccess.unlocked,
      progress: LessonProgress.notStarted,
      unlockSource: UnlockSource.firstLesson,
      effectivePassingScore: 80,
      lessonExamId: 'exam-quad-gate',
      lessonExamTitle: 'Quadratic Gatekeeper Quiz',
      attachedExams: [
        AttachedLessonExamEntity(
          examId: 'exam-quad-gate',
          examTitle: 'Quadratic Gatekeeper Quiz',
          isRequired: true,
          passingScore: 80,
          questionsCount: 10,
        ),
      ],
      videoDurationSeconds: 1800,
    );

    // Lesson 2: Complex Numbers & Polynomials (Gated: Requires passing exam-quad-gate >= 80%)
    syllabusLessons['les-02'] = const LessonAssignmentEntity(
      contentGroupId: 'cg-02',
      contentId: 'les-02',
      groupId: 'grp-sat-masters',
      title: 'Lesson 2: Complex Numbers & Polynomial Division',
      sortOrder: 2,
      chapterId: 'ch-01',
      chapterTitle: 'Chapter 1: Advanced SAT Algebra & Quadratics',
      access: LessonAccess.locked, // Gated!
      progress: LessonProgress.notStarted,
      prerequisiteExamId: 'exam-quad-gate',
      effectivePassingScore: 80,
      videoDurationSeconds: 2400,
      pdfFileId: 'pdf-complex-notes',
      pdfFileName: 'Complex_Numbers_Official_Worksheet.pdf',
    );

    // Lesson 3: Chapter 1 Capstone Milestone
    syllabusLessons['les-03'] = const LessonAssignmentEntity(
      contentGroupId: 'cg-03',
      contentId: 'les-03',
      groupId: 'grp-sat-masters',
      title: 'Lesson 3: Chapter 1 Comprehensive Milestone Exam',
      sortOrder: 3,
      chapterId: 'ch-01',
      chapterTitle: 'Chapter 1: Advanced SAT Algebra & Quadratics',
      access: LessonAccess.locked, // Gated!
      progress: LessonProgress.notStarted,
      effectivePassingScore: 75,
      lessonExamId: 'exam-ch1-milestone',
      lessonExamTitle: 'Chapter 1 Final Exam',
    );
  }

  /// Calculates real-time student lesson status based on exam achievements and manual overrides
  List<LessonAssignmentEntity> getStudentCourseProgress(String studentId) {
    final results = <LessonAssignmentEntity>[];

    // Evaluate Lesson 1:
    var l1 = studentLessonStates['$studentId:les-01'] ?? syllabusLessons['les-01']!;
    final l1Exams = studentExamScores['$studentId:exam-quad-gate'] ?? [];
    if (l1Exams.isNotEmpty) {
      final bestScore = l1Exams.map((e) => (e['score'] as num).toDouble()).reduce((a, b) => a > b ? a : b);
      final isPassed = bestScore >= 80.0;

      l1 = LessonAssignmentEntity(
        contentGroupId: l1.contentGroupId,
        contentId: l1.contentId,
        groupId: l1.groupId,
        title: l1.title,
        sortOrder: l1.sortOrder,
        chapterId: l1.chapterId,
        chapterTitle: l1.chapterTitle,
        access: LessonAccess.unlocked,
        progress: isPassed ? LessonProgress.completed : LessonProgress.quizFailed,
        unlockSource: l1.unlockSource,
        effectivePassingScore: l1.effectivePassingScore,
        lessonExamId: l1.lessonExamId,
        lessonExamTitle: l1.lessonExamTitle,
        videoCompleted: true,
        examBestScore: bestScore,
        examPassed: isPassed,
        attachedExams: [
          AttachedLessonExamEntity(
            examId: 'exam-quad-gate',
            examTitle: 'Quadratic Gatekeeper Quiz',
            isRequired: true,
            passingScore: 80,
            questionsCount: 10,
            bestScore: bestScore,
            isPassed: isPassed,
            attemptCount: l1Exams.length,
          ),
        ],
      );
    }
    results.add(l1);

    // Evaluate Lesson 2 (Prerequisite: l1 exam passed OR manual override):
    final isL1Passed = l1.examPassed;
    final isL2ManuallyUnlocked = manualUnlockOverrides.containsKey('$studentId:les-02');
    final isL2Unlocked = isL1Passed || isL2ManuallyUnlocked;

    var l2 = syllabusLessons['les-02']!;
    l2 = LessonAssignmentEntity(
      contentGroupId: l2.contentGroupId,
      contentId: l2.contentId,
      groupId: l2.groupId,
      title: l2.title,
      sortOrder: l2.sortOrder,
      chapterId: l2.chapterId,
      chapterTitle: l2.chapterTitle,
      access: isL2Unlocked ? LessonAccess.unlocked : LessonAccess.locked,
      progress: isL2Unlocked ? LessonProgress.inProgress : LessonProgress.notStarted,
      unlockSource: isL2ManuallyUnlocked
          ? UnlockSource.manualOverride
          : (isL1Passed ? UnlockSource.prerequisiteCompletion : null),
      prerequisiteExamId: l2.prerequisiteExamId,
      effectivePassingScore: l2.effectivePassingScore,
      pdfFileId: l2.pdfFileId,
      pdfFileName: l2.pdfFileName,
      isManuallyUnlocked: isL2ManuallyUnlocked,
    );
    results.add(l2);

    // Evaluate Lesson 3:
    final isL3ManuallyUnlocked = manualUnlockOverrides.containsKey('$studentId:les-03');
    var l3 = syllabusLessons['les-03']!;
    l3 = LessonAssignmentEntity(
      contentGroupId: l3.contentGroupId,
      contentId: l3.contentId,
      groupId: l3.groupId,
      title: l3.title,
      sortOrder: l3.sortOrder,
      chapterId: l3.chapterId,
      chapterTitle: l3.chapterTitle,
      access: isL3ManuallyUnlocked ? LessonAccess.unlocked : LessonAccess.locked,
      progress: LessonProgress.notStarted,
      unlockSource: isL3ManuallyUnlocked ? UnlockSource.manualOverride : null,
      effectivePassingScore: l3.effectivePassingScore,
      lessonExamId: l3.lessonExamId,
      lessonExamTitle: l3.lessonExamTitle,
      isManuallyUnlocked: isL3ManuallyUnlocked,
    );
    results.add(l3);

    return results;
  }

  void recordExamScore(String studentId, String examId, double score) {
    studentExamScores.putIfAbsent('$studentId:$examId', () => []).add({
      'score': score,
      'timestamp': DateTime.now().toIso8601String(),
    });
    auditLog.add({
      'event': 'student.exam_submitted',
      'student_id': studentId,
      'exam_id': examId,
      'score': score,
    });
  }

  void grantManualUnlock(String studentId, String contentId, String reason) {
    manualUnlockOverrides['$studentId:$contentId'] = reason;
    auditLog.add({
      'event': 'teacher.manual_unlock_granted',
      'student_id': studentId,
      'content_id': contentId,
      'reason': reason,
    });
  }
}

// ---------------------------------------------------------------------------
// SIMULATED CONTENT REPOSITORY FOR GATED LEARNING
// ---------------------------------------------------------------------------
class _SimulatedContentRepo implements ContentRepository {
  final _SimulatedCurriculumBackend backend;
  _SimulatedContentRepo(this.backend);

  @override
  Future<Result<List<LessonAssignmentEntity>>> getGroupCourseProgress({
    required String groupId,
    String? studentId,
  }) async {
    final effectiveStudentId = studentId ?? 'student-anon';
    final progress = backend.getStudentCourseProgress(effectiveStudentId);
    return Success(progress);
  }

  @override
  Future<Result<List<ChapterEntity>>> getGroupChapters(String groupId) async {
    return Success(backend.chapters);
  }

  @override
  Future<Result<void>> manualUnlockLesson({
    required String studentId,
    required String groupId,
    required String contentId,
    String? reason,
  }) async {
    backend.grantManualUnlock(studentId, contentId, reason ?? 'Teacher discretion');
    return const Success(null);
  }

  @override
  Future<Result<String>> getSignedFileUrl({required String storagePath, int expiresInSeconds = 3600}) async {
    return Success('https://cdn.satprep.academy/signed/$storagePath');
  }

  // Interface stubs
  @override
  Future<Result<List<ContentEntity>>> getGroupContent({required String groupId, ContentStatus? statusFilter, int page = 0, int pageSize = 20}) async => const Success([]);
  @override
  Future<Result<ContentEntity>> createContent({String? groupId, required String title, String? description, required ContentType type, required ContentStatus status, int? sortOrder, String? fileName, String? storagePath, String? mimeType, int? fileSize, List<int>? fileBytes, String? associatedExamId, String? prerequisiteExamId}) async => throw UnimplementedError();
  @override
  Future<Result<ContentEntity>> updateContent({required String contentId, String? title, String? description, ContentType? type, ContentStatus? status, int? sortOrder, String? fileName, String? storagePath, String? mimeType, int? fileSize, List<int>? fileBytes, String? associatedExamId, String? prerequisiteExamId}) async => throw UnimplementedError();
  @override
  Future<Result<void>> updateContentStatus({required String contentId, required ContentStatus status}) async => const Success(null);
  @override
  Future<Result<void>> reorderContentItems({required List<String> contentIdsInOrder, String? groupId}) async => const Success(null);
  @override
  Future<Result<void>> deleteContent(String contentId) async => const Success(null);
  @override
  Future<Result<List<ContentEntity>>> getCentralVideoBank({int page = 0, int pageSize = 100}) async => const Success([]);
  @override
  Future<Result<void>> assignContentToGroups({required String contentId, required List<String> groupIds, List<Map<String, dynamic>>? groupConfigs}) async => const Success(null);
  @override
  Future<Result<String>> resolveOrCreateLectureContent({required String videoId, required String groupId, required String title, String? tenantId}) async => throw UnimplementedError();
  @override
  Future<Result<void>> assignBatchContentToGroup({required String groupId, required List<Map<String, dynamic>> items}) async => const Success(null);
  @override
  Future<Result<void>> linkLessonExam({required String contentId, required String examId}) async => const Success(null);
  @override
  Future<Result<void>> toggleLessonVisibility({required String contentId, required String groupId, required bool isPublished}) async => const Success(null);
  @override
  Future<Result<void>> toggleAllLessonsVisibility({required String groupId, required bool isPublished}) async => const Success(null);
  @override
  Future<Result<String>> uploadAndCreateFileRecord({required String tenantId, required String contentId, required String fileName, required String mimeType, required List<int> fileBytes, required String storagePath}) async => const Success('file-sim-id');
  @override
  Future<Result<ChapterEntity>> createChapter({required String groupId, required String title, bool isPublished = true}) async => throw UnimplementedError();
  @override
  Future<Result<void>> toggleChapterVisibility({required String chapterId, required bool isPublished}) async => const Success(null);
  @override
  Future<Result<void>> updateChapter({required String chapterId, required String title}) async => const Success(null);
  @override
  Future<Result<void>> deleteChapter(String chapterId) async => const Success(null);
  @override
  Future<Result<void>> setLessonChapter({required String contentId, required String groupId, String? chapterId}) async => const Success(null);
  @override
  Future<Result<void>> reorderChapterLessons({required String groupId, required List<String> contentIdsInOrder}) async => const Success(null);
  @override
  Future<Result<void>> reorderCourseChapters({required String groupId, required List<String> chapterIdsInOrder}) async => const Success(null);
  @override
  Future<Result<void>> removeLessonFromGroup({required String contentId, required String groupId}) async => const Success(null);
}

// ---------------------------------------------------------------------------
// TEST SUITE: Gated Sequential Learning & Curriculum Progression
// ---------------------------------------------------------------------------
void main() {
  late _SimulatedCurriculumBackend backend;
  late _SimulatedContentRepo repo;
  late CourseProgressCubit cubit;

  const studentOmarId = 'std-omar-sat-01';
  const studentZiadId = 'std-ziad-sat-02';

  setUp(() {
    AppCache.clearAll();
    backend = _SimulatedCurriculumBackend();
    repo = _SimulatedContentRepo(backend);
    cubit = CourseProgressCubit(repository: repo);
  });

  tearDown(() {
    cubit.close();
    AppCache.clearAll();
  });

  group('🔒 [Simulation: Gated Sequential Learning & Gatekeeper Progression]', () {
    test('SCENARIO 1: Cold Start Gating — Lesson 1 unlocked as root; subsequent lessons strictly locked', () async {
      await cubit.loadCourseProgress(backend.groupId, studentId: studentOmarId);

      expect(cubit.state, isA<CourseProgressLoaded>());
      final state = cubit.state as CourseProgressLoaded;
      expect(state.lessons.length, equals(3));

      // Lesson 1 must be unlocked
      final lesson1 = state.lessons.firstWhere((l) => l.contentId == 'les-01');
      expect(lesson1.access, equals(LessonAccess.unlocked));
      expect(lesson1.unlockSource, equals(UnlockSource.firstLesson));
      expect(lesson1.attachedExams.first.isRequired, isTrue);

      // Lesson 2 must be locked behind exam-quad-gate
      final lesson2 = state.lessons.firstWhere((l) => l.contentId == 'les-02');
      expect(lesson2.access, equals(LessonAccess.locked), reason: 'Gated lesson must remain locked');
      expect(lesson2.prerequisiteExamId, equals('exam-quad-gate'));
      expect(lesson2.effectivePassingScore, equals(80));

      // Lesson 3 must also be locked
      final lesson3 = state.lessons.firstWhere((l) => l.contentId == 'les-03');
      expect(lesson3.access, equals(LessonAccess.locked));
    });

    test('SCENARIO 2: Gatekeeper Failure — Score < 80% marks quizFailed and blocks forward progression', () async {
      // 1. Student takes gatekeeper quiz but scores 65% (passing threshold is 80%)
      backend.recordExamScore(studentOmarId, 'exam-quad-gate', 65.0);

      // 2. Course progress re-evaluates
      await cubit.loadCourseProgress(backend.groupId, studentId: studentOmarId, forceRefresh: true);

      final state = cubit.state as CourseProgressLoaded;
      final lesson1 = state.lessons.firstWhere((l) => l.contentId == 'les-01');
      final lesson2 = state.lessons.firstWhere((l) => l.contentId == 'les-02');

      // Lesson 1 must register quizFailed
      expect(lesson1.progress, equals(LessonProgress.quizFailed));
      expect(lesson1.examPassed, isFalse);
      expect(lesson1.examBestScore, equals(65.0));

      // CRITICAL INVARIANT: Lesson 2 MUST REMAIN STRICTLY LOCKED!
      expect(lesson2.access, equals(LessonAccess.locked), reason: 'Unpassed gatekeeper quiz cannot unlock subsequent lessons');
      expect(lesson2.unlockSource, isNull);
    });

    test('SCENARIO 3: Gatekeeper Mastery — Retake score >= 80% triggers instant automated gateway unlock', () async {
      // 1. Initial failed attempt (65%)
      backend.recordExamScore(studentOmarId, 'exam-quad-gate', 65.0);

      // 2. Student studies remedial mistakes, retakes quiz and scores 88% (> 80%)
      backend.recordExamScore(studentOmarId, 'exam-quad-gate', 88.0);

      // 3. Reload course progress
      await cubit.loadCourseProgress(backend.groupId, studentId: studentOmarId, forceRefresh: true);

      final state = cubit.state as CourseProgressLoaded;
      final lesson1 = state.lessons.firstWhere((l) => l.contentId == 'les-01');
      final lesson2 = state.lessons.firstWhere((l) => l.contentId == 'les-02');

      // Lesson 1 marks completed
      expect(lesson1.progress, equals(LessonProgress.completed));
      expect(lesson1.examPassed, isTrue);
      expect(lesson1.examBestScore, equals(88.0));

      // Lesson 2 AUTOMATICALLY UNLOCKS!
      expect(lesson2.access, equals(LessonAccess.unlocked), reason: 'Passing gatekeeper unlocks next lesson');
      expect(lesson2.unlockSource, equals(UnlockSource.prerequisiteCompletion));

      // Attached materials (PDF workbook) become immediately accessible
      expect(lesson2.hasPdf, isTrue);
      final pdfUrlResult = await repo.getSignedFileUrl(storagePath: lesson2.pdfFileName!);
      expect(pdfUrlResult.isSuccess, isTrue);
      expect(pdfUrlResult.dataOrNull, contains('Complex_Numbers_Official_Worksheet.pdf'));

      // Lesson 3 remains locked until Lesson 2's requirements are met
      final lesson3 = state.lessons.firstWhere((l) => l.contentId == 'les-03');
      expect(lesson3.access, equals(LessonAccess.locked));
    });

    test('SCENARIO 4: Teacher Manual Bypass Override — Emergency unlock with audit trail', () async {
      // Transfer student needs immediate access to Lesson 3 without taking prerequisite exams
      await repo.manualUnlockLesson(
        studentId: studentOmarId,
        groupId: backend.groupId,
        contentId: 'les-03',
        reason: 'AP Calculus transfer credits accredited by administration',
      );

      await cubit.loadCourseProgress(backend.groupId, studentId: studentOmarId, forceRefresh: true);
      final state = cubit.state as CourseProgressLoaded;

      final lesson3 = state.lessons.firstWhere((l) => l.contentId == 'les-03');
      expect(lesson3.access, equals(LessonAccess.unlocked));
      expect(lesson3.isManuallyUnlocked, isTrue);
      expect(lesson3.unlockSource, equals(UnlockSource.manualOverride));

      // Verify administrative audit trail
      final overrideLog = backend.auditLog.firstWhere((l) => l['event'] == 'teacher.manual_unlock_granted');
      expect(overrideLog['student_id'], equals(studentOmarId));
      expect(overrideLog['content_id'], equals('les-03'));
      expect(overrideLog['reason'], contains('AP Calculus transfer credits'));
    });

    test('SCENARIO 5: Multi-Student Progression Isolation — Zero cross-student gating leak', () async {
      // Omar passes Lesson 1 gatekeeper with 95%
      backend.recordExamScore(studentOmarId, 'exam-quad-gate', 95.0);

      // Ziad has NEVER taken the gatekeeper quiz (0%)
      // Query Omar's progress:
      await cubit.loadCourseProgress(backend.groupId, studentId: studentOmarId, forceRefresh: true);
      var state = cubit.state as CourseProgressLoaded;
      var omarLesson2 = state.lessons.firstWhere((l) => l.contentId == 'les-02');
      expect(omarLesson2.access, equals(LessonAccess.unlocked), reason: "Omar's lesson 2 is unlocked");

      // Query Ziad's progress:
      await cubit.loadCourseProgress(backend.groupId, studentId: studentZiadId, forceRefresh: true);
      state = cubit.state as CourseProgressLoaded;
      var ziadLesson2 = state.lessons.firstWhere((l) => l.contentId == 'les-02');
      expect(ziadLesson2.access, equals(LessonAccess.locked), reason: "Ziad's lesson 2 MUST remain locked");
      expect(ziadLesson2.unlockSource, isNull);
    });
  });
}
