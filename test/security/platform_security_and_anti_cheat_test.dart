import 'package:edu_saas/core/errors/failures.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/utils/cache_manager.dart';
import 'package:edu_saas/features/auth/domain/entities/user_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_folder_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_parent_dispatch_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/mistake_entities.dart';
import 'package:edu_saas/features/exams/domain/repositories/exams_repository.dart';
import 'package:edu_saas/features/students/domain/entities/student_360_entity.dart';
import 'package:edu_saas/features/students/domain/entities/student_academic_report_entity.dart';
import 'package:edu_saas/features/students/domain/entities/student_entity.dart';
import 'package:edu_saas/features/students/domain/repositories/students_repository.dart';
import 'package:edu_saas/features/videos/domain/entities/video_entity.dart';
import 'package:edu_saas/features/videos/domain/entities/video_progress_entity.dart';
import 'package:edu_saas/features/videos/domain/repositories/videos_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// SIMULATED SECURE SERVER-SIDE BACKEND WITH ATOMIC ANTI-CHEAT ENGINES
// ---------------------------------------------------------------------------
class _SimulatedSecurityBackend {
  // Current authenticated user session context (Zero client trust: §0.1)
  UserEntity currentSession;

  // Canonical Video Bank & Watch Progress Storage
  final Map<String, VideoEntity> videos = {};
  final Map<String, VideoProgressEntity> videoProgressRecords = {}; // key: "studentId:videoId"

  // Canonical Exam Bank, Questions & Versions
  final Map<String, ExamEntity> exams = {};
  final Map<String, ExamVersionEntity> examVersions = {};
  final Map<String, List<Map<String, dynamic>>> canonicalQuestionKeys = {}; // Secret answer keys!
  final Map<String, ExamAttemptEntity> attempts = {};

  // Student Profiles
  final Map<String, StudentEntity> students = {};

  // Security Audit Log (Immutable append-only: §5.4 & §12.5)
  final List<Map<String, dynamic>> securityAuditLog = [];

  _SimulatedSecurityBackend({required this.currentSession});

  void logSecurityEvent(String eventType, String targetResource, Map<String, dynamic> details) {
    securityAuditLog.add({
      'event': eventType,
      'actor_id': currentSession.id,
      'actor_role': currentSession.role.name,
      'target': targetResource,
      'timestamp': DateTime.now().toIso8601String(),
      'details': details,
    });
  }
}

// ---------------------------------------------------------------------------
// SECURE VIDEOS REPOSITORY (With Server-Side Telemetry & Anti-Skip Engine)
// ---------------------------------------------------------------------------
class _SecureVideosRepo implements VideosRepository {
  final _SimulatedSecurityBackend backend;
  _SecureVideosRepo(this.backend);

  @override
  Future<Result<VideoProgressEntity>> updateVideoProgress({
    required String videoId,
    required String studentId,
    required int progressSeconds,
    required int durationSeconds,
    int furthestPositionSeconds = 0,
    int actualWatchSeconds = 0,
    bool isSkipped = false,
    List<int>? newSegment,
  }) async {
    // 1. Identity Check: Student can only update their own progress (§5.2)
    if (backend.currentSession.id != studentId && backend.currentSession.role != UserRole.teacher) {
      backend.logSecurityEvent('video.unauthorized_progress_update', videoId, {
        'attempted_student_id': studentId,
      });
      return const FailureResult(ServerFailure('Unauthorized to modify peer video progress', code: 'NOT_AUTHORIZED'));
    }

    // 2. Anti-Cheat Engine (§11.3 & §16):
    // Minimum 80% genuine watch coverage required for completion badge.
    // If student skipped or actual watch time is far below duration, reject completion.
    final key = '$studentId:$videoId';
    final existing = backend.videoProgressRecords[key];
    final accumulatedWatchSeconds = (existing?.actualWatchSeconds ?? 0) + actualWatchSeconds;
    final effectiveRatio = durationSeconds > 0 ? (accumulatedWatchSeconds / durationSeconds) : 0.0;

    final isTrulyCompleted = !isSkipped && effectiveRatio >= 0.80;

    if (isSkipped && progressSeconds >= durationSeconds - 10) {
      backend.logSecurityEvent('video.fast_forward_tamper_detected', videoId, {
        'progress_seconds': progressSeconds,
        'duration_seconds': durationSeconds,
        'actual_watch_seconds': accumulatedWatchSeconds,
        'effective_ratio': effectiveRatio,
      });
    }

    final updated = VideoProgressEntity(
      id: 'vp-${DateTime.now().millisecondsSinceEpoch}',
      videoId: videoId,
      studentId: studentId,
      progressSeconds: progressSeconds,
      durationSeconds: durationSeconds,
      percentage: (progressSeconds / durationSeconds * 100).clamp(0.0, 100.0),
      completed: isTrulyCompleted,
      lastWatchedAt: DateTime.now(),
      actualWatchSeconds: accumulatedWatchSeconds,
      furthestPositionSeconds: furthestPositionSeconds > (existing?.furthestPositionSeconds ?? 0)
          ? furthestPositionSeconds
          : (existing?.furthestPositionSeconds ?? 0),
      isSkipped: isSkipped || (existing?.isSkipped ?? false),
    );

    backend.videoProgressRecords[key] = updated;
    return Success(updated);
  }

  @override
  Future<Result<VideoProgressEntity?>> getVideoProgress({
    required String videoId,
    required String studentId,
  }) async {
    if (backend.currentSession.id != studentId && backend.currentSession.role != UserRole.teacher) {
      return const FailureResult(ServerFailure('Unauthorized access', code: 'NOT_AUTHORIZED'));
    }
    return Success(backend.videoProgressRecords['$studentId:$videoId']);
  }

  @override
  Future<Result<VideoEntity>> getVideoById(String videoId) async => throw UnimplementedError();
  @override
  Future<Result<List<VideoEntity>>> getVideosForGroup(String groupId) async => const Success([]);
  @override
  Future<Result<String>> getPlaybackUrl(String videoId) async => const Success('https://tokenized-stream.m3u8');
  @override
  Future<Result<VideoEntity>> linkYouTubeVideo({required String contentId, required String youtubeUrl, String? title}) async => throw UnimplementedError();
  @override
  Future<Result<VideoEntity>> attachMaterialToVideo({
    required String videoId,
    required String contentId,
    required String fileName,
    required List<int> fileBytes,
  }) async => throw UnimplementedError();
  @override
  Future<Result<Map<String, dynamic>?>> getLessonContext({
    required String contentId,
    required String groupId,
  }) async => const Success(null);
  @override
  Future<Result<VideoEntity>> createAndUploadVideo({required String contentId, required String title, required List<int> videoBytes, required String fileName, void Function(int sentBytes, int totalBytes)? onProgress}) async => throw UnimplementedError();
  @override
  Future<Result<void>> deleteVideo(String videoId) async => throw UnimplementedError();
  @override
  Future<Result<String>> getSignedFileUrl(String storagePath) async => throw UnimplementedError();
}

// ---------------------------------------------------------------------------
// SECURE EXAMS REPOSITORY (With Atomic Server-Side Grading & Immutability)
// ---------------------------------------------------------------------------
class _SecureExamsRepo implements ExamsRepository {
  final _SimulatedSecurityBackend backend;
  _SecureExamsRepo(this.backend);

  @override
  Future<Result<ExamEntity>> getExamDetails(String examId) async {
    final exam = backend.exams[examId];
    if (exam == null) {
      return const FailureResult(ServerFailure('Exam not found', code: 'NOT_FOUND'));
    }

    // Zero-Knowledge Draft Isolation (§5.2 & §12.5):
    // Students can NEVER discover draft exams, even with valid UUID
    if (backend.currentSession.isStudent && exam.isDraft) {
      backend.logSecurityEvent('exam.draft_snooping_blocked', examId, {
        'status': 'draft',
      });
      return const FailureResult(ServerFailure('Exam not found', code: 'NOT_FOUND'));
    }

    return Success(exam);
  }

  @override
  Future<Result<ExamAttemptEntity>> startExam(String examId) async {
    final exam = backend.exams[examId];
    if (exam == null || (backend.currentSession.isStudent && exam.isDraft)) {
      return const FailureResult(ServerFailure('Exam unavailable', code: 'NOT_FOUND'));
    }

    final attemptId = 'att-${DateTime.now().millisecondsSinceEpoch}';
    final attempt = ExamAttemptEntity(
      id: attemptId,
      examId: examId,
      examVersionId: exam.activeVersion?.id ?? 'v1',
      studentId: backend.currentSession.id,
      startedAt: DateTime.now(),
      status: AttemptStatus.inProgress,
      answers: const [],
    );
    backend.attempts[attemptId] = attempt;
    return Success(attempt);
  }

  @override
  Future<Result<ExamAttemptEntity>> submitExam({
    required String attemptId,
    required Map<String, String> answers,
    ExamSubmissionReason reason = ExamSubmissionReason.studentSubmitted,
  }) async {
    final attempt = backend.attempts[attemptId];
    if (attempt == null) {
      return const FailureResult(ServerFailure('Attempt not found', code: 'NOT_FOUND'));
    }

    // Server-Side Atomic Grading (§0.1, §0.5, §11.3):
    // Disregard all client scoring hints. Grade solely from canonical server-side keys.
    final exam = backend.exams[attempt.examId]!;
    final secretKeys = backend.canonicalQuestionKeys[attempt.examId] ?? [];

    int correctCount = 0;
    int totalQuestions = secretKeys.length;
    double pointsPerQuestion = totalQuestions > 0 ? (exam.maxScore / totalQuestions) : 0;

    for (final key in secretKeys) {
      final qId = key['question_id'];
      final correctOptId = key['correct_option_id'];
      if (answers[qId] == correctOptId) {
        correctCount++;
      }
    }

    final calculatedScore = (correctCount * pointsPerQuestion).round();
    final calculatedPercentage = totalQuestions > 0 ? (correctCount / totalQuestions * 100.0) : 0.0;

    final finalizedAttempt = ExamAttemptEntity(
      id: attemptId,
      examId: attempt.examId,
      examVersionId: attempt.examVersionId,
      studentId: attempt.studentId,
      startedAt: attempt.startedAt,
      submittedAt: DateTime.now(),
      status: AttemptStatus.submitted,
      score: calculatedScore,
      percentage: calculatedPercentage,
      answers: answers.entries
          .map<ExamAnswerEntity>((e) => ExamAnswerEntity(
                id: 'ans-${e.key}',
                attemptId: attemptId,
                questionId: e.key,
                selectedOptionId: e.value,
                answeredAt: DateTime.now(),
              ))
          .toList(),
    );

    backend.attempts[attemptId] = finalizedAttempt;
    return Success(finalizedAttempt);
  }

  @override
  Future<Result<ExamVersionEntity>> publishExamVersion(String versionId) async {
    if (!backend.currentSession.isTeacher) {
      backend.logSecurityEvent('privilege_escalation.publish_exam_blocked', versionId, {});
      return const FailureResult(ServerFailure('Teachers only', code: 'NOT_AUTHORIZED'));
    }
    final v = backend.examVersions[versionId];
    if (v == null) return const FailureResult(ServerFailure('Version not found', code: 'NOT_FOUND'));
    return Success(v);
  }

  @override
  Future<Result<bool>> deleteExam({required String examId, bool force = false}) async {
    if (!backend.currentSession.isTeacher) {
      backend.logSecurityEvent('privilege_escalation.delete_exam_blocked', examId, {});
      return const FailureResult(ServerFailure('Forbidden', code: 'NOT_AUTHORIZED'));
    }
    return const Success(true);
  }

  @override
  Future<Result<MistakeSummaryEntity>> getStudentMistakesSummary(String studentId) async {
    if (backend.currentSession.isStudent && backend.currentSession.id != studentId) {
      backend.logSecurityEvent('privacy.peer_mistakes_snoop_blocked', studentId, {});
      return const FailureResult(ServerFailure('Access denied to other students mistakes', code: 'NOT_AUTHORIZED'));
    }
    return const Success(MistakeSummaryEntity(
      totalMistakes: 5,
      unresolvedCount: 2,
      resolvedCount: 3,
      sources: [],
    ));
  }

  // Interface stubs
  @override
  Future<Result<List<ExamEntity>>> getStudentExams({int page = 0, int pageSize = 15}) async => const Success([]);
  @override
  Future<Result<List<ExamEntity>>> getGroupExams(String groupId, {int page = 0, int pageSize = 15}) async => const Success([]);
  @override
  Future<Result<ExamEntity>> createExam({String? groupId, required String title, int durationMinutes = 60, int maxScore = 100, int? passingScore, bool shuffleQuestions = false, bool showResult = true, bool allowRetake = false, DateTime? startAt, DateTime? endAt, bool isPublished = false, String? pdfFileId, required List<ExamQuestionEntity> initialQuestions}) async => throw UnimplementedError();
  @override
  Future<Result<ExamEntity>> updateExam({required String examId, required String title, int? durationMinutes, int? maxScore, int? passingScore, bool? shuffleQuestions, bool? showResult, bool? allowRetake, DateTime? startAt, DateTime? endAt, bool? isPublished, String? pdfFileId, bool clearPdfFile = false}) async => throw UnimplementedError();
  @override
  Future<Result<ExamEntity>> updateDraftExamQuestions({required String examId, required String title, int? durationMinutes, int? maxScore, int? passingScore, bool? shuffleQuestions, bool? showResult, bool? allowRetake, DateTime? startAt, DateTime? endAt, bool? isPublished, String? pdfFileId, bool clearPdfFile = false, required List<ExamQuestionEntity> questions}) async => throw UnimplementedError();
  @override
  Future<Result<String>> getSignedPdfUrl(String storagePath) async => const Success('https://signed.pdf');
  @override
  Future<Result<void>> unpublishExamVersion({required String examId, required String versionId}) async => const Success(null);
  @override
  Future<Result<ExamVersionEntity>> createNewExamVersion(String examId) async => throw UnimplementedError();
  @override
  Future<Result<void>> syncExamAnswers({required String attemptId, required Map<String, String> answers}) async => const Success(null);
  @override
  Future<Result<List<ExamAttemptEntity>>> getExamAttempts(String examId, {int page = 0, int pageSize = 20}) async => const Success([]);
  @override
  Future<Result<ExamAttemptEntity>> getAttemptDetails(String attemptId) async => throw UnimplementedError();
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
  @override
  Future<Result<void>> convertExamType({
    required String examId,
    required String contentId,
    required bool toLectureExam,
    required String groupId,
  }) async => const Success(null);
}

// ---------------------------------------------------------------------------
// SECURE STUDENTS REPOSITORY (Role Escalation Barrier)
// ---------------------------------------------------------------------------
class _SecureStudentsRepo implements StudentsRepository {
  final _SimulatedSecurityBackend backend;
  _SecureStudentsRepo(this.backend);

  @override
  Future<Result<StudentEntity>> changeStudentStatus({
    required String studentId,
    required String action,
  }) async {
    // Privilege Check: Students can NEVER approve/reject admissions!
    if (!backend.currentSession.isTeacher) {
      backend.logSecurityEvent('privilege_escalation.self_admissions_approval_attempt', studentId, {
        'action': action,
      });
      return const FailureResult(ServerFailure('Administrative privilege required', code: 'NOT_AUTHORIZED'));
    }

    final std = backend.students[studentId];
    if (std == null) return const FailureResult(ServerFailure('Student not found', code: 'NOT_FOUND'));
    final updated = StudentEntity(
      id: std.id,
      tenantId: std.tenantId,
      fullName: std.fullName,
      email: std.email,
      status: action == 'approve' ? 'active' : 'rejected',
      createdAt: std.createdAt,
    );
    backend.students[studentId] = updated;
    return Success(updated);
  }

  @override
  Future<Result<void>> deleteStudent(String studentId) async {
    if (!backend.currentSession.isTeacher) {
      return const FailureResult(ServerFailure('Forbidden', code: 'NOT_AUTHORIZED'));
    }
    return const Success(null);
  }

  @override
  Future<Result<List<StudentEntity>>> getStudents({String? status, String? searchQuery, int page = 0, int pageSize = 25}) async =>
      backend.currentSession.isTeacher
          ? Success(backend.students.values.toList())
          : const FailureResult(ServerFailure('Forbidden', code: 'NOT_AUTHORIZED'));

  @override
  Future<Result<List<StudentEntity>>> getPendingStudents({int page = 0, int pageSize = 20}) async =>
      backend.currentSession.isTeacher ? const Success([]) : const FailureResult(ServerFailure('Forbidden', code: 'NOT_AUTHORIZED'));

  @override
  Future<Result<Student360Entity>> getStudent360(String studentId) async => throw UnimplementedError();
  @override
  Future<Result<StudentAcademicReportEntity>> getStudentAcademicReport(String studentId, {int? days}) async => throw UnimplementedError();
  @override
  Future<Result<StudentEntity>> getStudent(String studentId) async => throw UnimplementedError();
  @override
  Future<Result<void>> assignStudentToGroup({required String studentId, required String groupId, required bool add}) async =>
      backend.currentSession.isTeacher ? const Success(null) : const FailureResult(ServerFailure('Forbidden', code: 'NOT_AUTHORIZED'));
  @override
  Future<Result<List<StudentGroupInfo>>> getAvailableGroupsForStudent(String studentId) async => const Success([]);
}

// ---------------------------------------------------------------------------
// TEST SUITE: Platform Security & Anti-Cheat Invariants Simulation
// ---------------------------------------------------------------------------
void main() {
  late _SimulatedSecurityBackend backend;
  late _SecureVideosRepo videosRepo;
  late _SecureExamsRepo examsRepo;
  late _SecureStudentsRepo studentsRepo;

  // Student actor session
  const studentUser = UserEntity(
    id: 'usr-student-42',
    tenantId: 'tenant-academic-1',
    role: UserRole.student,
    status: UserStatus.active,
    fullName: 'Adversary Student',
    email: 'hacker@student.edu',
  );

  setUp(() {
    AppCache.clearAll();
    backend = _SimulatedSecurityBackend(currentSession: studentUser);
    videosRepo = _SecureVideosRepo(backend);
    examsRepo = _SecureExamsRepo(backend);
    studentsRepo = _SecureStudentsRepo(backend);

    // Seed 1: A 600-second gated curriculum video
    backend.videos['vid-calculus-01'] = VideoEntity(
      id: 'vid-calculus-01',
      contentId: 'cnt-01',
      title: 'Derivatives & Power Rule Mastery',
      duration: 600,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Seed 2: A published exam with activeVersion (Max score: 100)
    // Server holds secret canonical answer keys!
    backend.exams['exam-calc-101'] = ExamEntity(
      id: 'exam-calc-101',
      contentId: 'cnt-01',
      tenantId: 'tenant-academic-1',
      groupId: 'grp-1',
      title: 'Calculus Milestone Exam',
      durationMinutes: 45,
      maxScore: 100,
      passingScore: 60,
      activeVersion: ExamVersionEntity(
        id: 'v1',
        examId: 'exam-calc-101',
        versionNumber: 1,
        status: ExamStatus.published,
        createdAt: DateTime.now(),
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    backend.canonicalQuestionKeys['exam-calc-101'] = [
      {'question_id': 'q1', 'correct_option_id': 'opt-1-correct'},
      {'question_id': 'q2', 'correct_option_id': 'opt-2-correct'},
      {'question_id': 'q3', 'correct_option_id': 'opt-3-correct'},
      {'question_id': 'q4', 'correct_option_id': 'opt-4-correct'},
      {'question_id': 'q5', 'correct_option_id': 'opt-5-correct'},
    ];

    // Seed 3: An unreleased draft exam (activeVersion is null or draft)
    backend.exams['exam-draft-secret'] = ExamEntity(
      id: 'exam-draft-secret',
      contentId: 'cnt-02',
      tenantId: 'tenant-academic-1',
      groupId: 'grp-1',
      title: 'Confidential Midterm Exam (DRAFT)',
      durationMinutes: 60,
      maxScore: 100,
      passingScore: 60,
      activeVersion: null, // Draft!
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Seed 4: Pending admissions student
    backend.students['std-pending-99'] = StudentEntity(
      id: 'std-pending-99',
      tenantId: 'tenant-academic-1',
      fullName: 'Pending Applicant',
      email: 'pending@applicant.edu',
      status: 'pending',
      createdAt: DateTime.now(),
    );
  });

  tearDown(() {
    AppCache.clearAll();
  });

  group('🛡️ [Simulation: Platform Security & Anti-Cheat Protocols]', () {
    test('SCENARIO 1: Video Anti-Skip & Fraudulent Fast-Forwarding Telemetry (§11.3 & §16)', () async {
      // 1. Genuine student watch behavior:
      // Watches segments accumulated over 500 seconds (83.3% coverage)
      final genuineUpdate = await videosRepo.updateVideoProgress(
        videoId: 'vid-calculus-01',
        studentId: studentUser.id,
        progressSeconds: 520,
        durationSeconds: 600,
        furthestPositionSeconds: 520,
        actualWatchSeconds: 500, // Real wall-clock watch time
        isSkipped: false,
      );

      expect(genuineUpdate.isSuccess, isTrue);
      expect(genuineUpdate.dataOrNull?.completed, isTrue, reason: 'Accumulated >80% genuine watch time');
      expect(genuineUpdate.dataOrNull?.isSkipped, isFalse);

      // 2. Fraudulent student tamper attempt:
      // Student opens a new video and immediately skips the progress slider to second 595 after only 4 seconds.
      final fraudUpdate = await videosRepo.updateVideoProgress(
        videoId: 'vid-calculus-02-new',
        studentId: studentUser.id,
        progressSeconds: 595,
        durationSeconds: 600,
        furthestPositionSeconds: 595,
        actualWatchSeconds: 4, // Tamper detected: Only 4 seconds elapsed!
        isSkipped: true,
      );

      expect(fraudUpdate.isSuccess, isTrue);
      final fraudResult = fraudUpdate.dataOrNull!;
      expect(fraudResult.completed, isFalse, reason: 'Fast-forward skipping strictly denies completion badge');
      expect(fraudResult.isSkipped, isTrue);

      // 3. Verify security audit captured the fast-forward anomaly
      final tamperLogs = backend.securityAuditLog
          .where((l) => l['event'] == 'video.fast_forward_tamper_detected')
          .toList();
      expect(tamperLogs.length, equals(1));
      expect(tamperLogs.first['details']['actual_watch_seconds'], equals(4));

      // 4. Peer progress modification attack:
      // Student attempts to falsify video progress for another student
      final peerAttack = await videosRepo.updateVideoProgress(
        videoId: 'vid-calculus-01',
        studentId: 'victim-student-999',
        progressSeconds: 600,
        durationSeconds: 600,
      );
      expect(peerAttack.isFailure, isTrue);
      expect(peerAttack.failureOrNull?.code, equals('NOT_AUTHORIZED'));
    });

    test('SCENARIO 2: Client-Side Score Tampering & Atomic Server-Side Evaluation (§0.1, §0.5, §11.3)', () async {
      // 1. Student starts exam session
      final startResult = await examsRepo.startExam('exam-calc-101');
      expect(startResult.isSuccess, isTrue);
      final attemptId = startResult.dataOrNull!.id;

      // 2. Malicious client payload:
      // Attacker intercepts the network packet and injects answers:
      // Only Q1 is correct. Q2, Q3, Q4, Q5 are wrong options.
      final tamperedAnswers = {
        'q1': 'opt-1-correct', // Correct (+20 pts)
        'q2': 'opt-2-WRONG',   // Wrong
        'q3': 'opt-3-WRONG',   // Wrong
        'q4': 'opt-4-WRONG',   // Wrong
        'q5': 'opt-5-WRONG',   // Wrong
      };

      // Server grading engine evaluates the score independently:
      final submitResult = await examsRepo.submitExam(
        attemptId: attemptId,
        answers: tamperedAnswers,
        reason: ExamSubmissionReason.studentSubmitted,
      );

      expect(submitResult.isSuccess, isTrue);
      final attempt = submitResult.dataOrNull!;
      final exam = backend.exams['exam-calc-101']!;

      // 3. Critical Architectural Assertions (§0.5):
      // The verified score MUST be exactly 20 (1 out of 5), and percentage 20.0%!
      expect(attempt.score, equals(20), reason: 'Server-side scoring overrides any client assertion');
      expect(attempt.percentage, equals(20.0));
      expect(attempt.isPassed(exam.passingScore), isFalse, reason: 'Passing score was 60. 20 is failing.');
    });

    test('SCENARIO 3: Role Privilege Escalation & Direct Admin RPC Attack Rejection (§5.2, §5.4, §12.5)', () async {
      // 1. Student attempts self-approval or peer approval in admissions pipeline
      final approveAttack = await studentsRepo.changeStudentStatus(
        studentId: 'std-pending-99',
        action: 'approve',
      );
      expect(approveAttack.isFailure, isTrue);
      expect(approveAttack.failureOrNull?.code, equals('NOT_AUTHORIZED'));
      expect(backend.students['std-pending-99']!.status, equals('pending'), reason: 'State remained unchanged');

      // 2. Student attempts to publish an exam version
      final publishAttack = await examsRepo.publishExamVersion('v-exam-101');
      expect(publishAttack.isFailure, isTrue);
      expect(publishAttack.failureOrNull?.code, equals('NOT_AUTHORIZED'));

      // 3. Student attempts to delete an exam
      final deleteAttack = await examsRepo.deleteExam(examId: 'exam-calc-101');
      expect(deleteAttack.isFailure, isTrue);
      expect(deleteAttack.failureOrNull?.code, equals('NOT_AUTHORIZED'));

      // 4. Student attempts to spy on a peer student mistakes summary
      final snoopAttack = await examsRepo.getStudentMistakesSummary('peer-victim-id');
      expect(snoopAttack.isFailure, isTrue);
      expect(snoopAttack.failureOrNull?.code, equals('NOT_AUTHORIZED'));

      // 5. Verify security audit log logged all 4 escalation attempts
      expect(backend.securityAuditLog.length, greaterThanOrEqualTo(4));
    });

    test('SCENARIO 4: Zero-Knowledge Draft Isolation Under Student Token (§5.2 & §12.5)', () async {
      // 1. Teacher can query draft exam details
      backend.currentSession = const UserEntity(
        id: 'usr-teacher-1',
        tenantId: 'tenant-academic-1',
        role: UserRole.teacher,
        status: UserStatus.active,
        fullName: 'Prof. Gauss',
        email: 'gauss@math.edu',
      );
      final teacherQuery = await examsRepo.getExamDetails('exam-draft-secret');
      expect(teacherQuery.isSuccess, isTrue);

      // 2. Student session switches back
      backend.currentSession = studentUser;

      // Student attempts to query the draft exam using its exact UUID
      final studentQuery = await examsRepo.getExamDetails('exam-draft-secret');
      expect(studentQuery.isFailure, isTrue);
      expect(studentQuery.failureOrNull?.code, equals('NOT_FOUND'), reason: 'Zero-knowledge: draft appears as 404');

      // Student attempts to start an unreleased draft exam
      final startDraftAttempt = await examsRepo.startExam('exam-draft-secret');
      expect(startDraftAttempt.isFailure, isTrue);
      expect(startDraftAttempt.failureOrNull?.code, equals('NOT_FOUND'));

      // Verify audit trail logged the snooping attempt
      final draftSnoopLogs = backend.securityAuditLog
          .where((l) => l['event'] == 'exam.draft_snooping_blocked')
          .toList();
      expect(draftSnoopLogs.length, equals(1));
    });
  });
}
