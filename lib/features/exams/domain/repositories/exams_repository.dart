import '../../../../core/errors/result.dart';
import '../entities/exam_entity.dart';
import '../entities/exam_parent_dispatch_entity.dart';
import '../entities/mistake_entities.dart';


abstract class ExamsRepository {
  /// Fetches all exams belonging to a specific group (Teacher view).
  Future<Result<List<ExamEntity>>> getGroupExams(
    String groupId, {
    int page = 0,
    int pageSize = 15,
  });

  /// Fetches all active and published exams available to the currently logged-in student.
  Future<Result<List<ExamEntity>>> getStudentExams({
    int page = 0,
    int pageSize = 15,
  });

  /// Fetches complete details of an exam including its active versions and questions.
  Future<Result<ExamEntity>> getExamDetails(String examId);

  /// Creates a new exam with its content record, exam settings, initial draft version, and questions.
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
    required List<ExamQuestionEntity> initialQuestions,
  });

  /// Updates an existing exam's title and academic settings.
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
  });

  /// Updates a draft exam's metadata and atomic questions.
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
    bool? isPublished,
    required List<ExamQuestionEntity> questions,
  });

  /// Freezes an exam version as an immutable snapshot and publishes the exam.
  Future<Result<ExamVersionEntity>> publishExamVersion(String versionId);

  /// Reverts a published exam and its version back to draft, hiding it from students.
  Future<Result<void>> unpublishExamVersion({
    required String examId,
    required String versionId,
  });

  /// Clones existing questions into a new draft version for edits after publish.
  Future<Result<ExamVersionEntity>> createNewExamVersion(String examId);

  /// Starts or resumes an exam attempt server-side (enforces one active attempt, sets started_at).
  Future<Result<ExamAttemptEntity>> startExam(String examId);

  /// Submits student answers atomically in a single server-side transaction (evaluates score server-side).
  Future<Result<ExamAttemptEntity>> submitExam({
    required String attemptId,
    required Map<String, String> answers,
  });

  /// Fetches all student attempts and scores for an exam (Teacher view).
  Future<Result<List<ExamAttemptEntity>>> getExamAttempts(String examId);

  /// Fetches full attempt details including student answers and points earned.
  Future<Result<ExamAttemptEntity>> getAttemptDetails(String attemptId);

  /// Fetches summary metrics of student mistakes (total, unresolved, resolved, sources breakdown).
  Future<Result<MistakeSummaryEntity>> getStudentMistakesSummary(String studentId);

  /// Fetches mistake questions for review or practice session.
  Future<Result<List<MistakeQuestionEntity>>> getStudentMistakesQuestions(
    String studentId, {
    String? examId,
    bool onlyUnresolved = true,
  });

  /// Submits student answers for a mistakes practice session and returns feedback.
  Future<Result<MistakePracticeResultEntity>> submitMistakesPractice(
    List<Map<String, String>> answers,
  );

  /// Fetches group lessons for linking exams.
  Future<Result<List<Map<String, dynamic>>>> getGroupLessons(String groupId);

  /// Links an exam to a group lesson as its gatekeeper quiz.
  Future<Result<void>> linkExamToLesson({
    required String examId,
    required String lessonId,
    required String groupId,
  });

  /// Unlinks an exam from any lessons in the group, optionally turning it into a general exam.
  Future<Result<void>> unlinkExamFromLesson({
    required String examId,
    required String groupId,
    bool makeGeneralExam = false,
  });

  /// Converts an exam between lecture quiz and general exam.
  Future<Result<void>> convertExamType({
    required String examId,
    required String contentId,
    required bool toLectureExam,
    required String groupId,
  });

  /// Deletes or archives an exam with cascade cleanup.
  Future<Result<bool>> deleteExam({
    required String examId,
    bool force = false,
  });

  /// Fetches complete exam results roster with student attempts and parent phone contacts for WhatsApp dispatch.
  Future<Result<ExamParentDispatchRosterEntity>> getExamParentDispatchRoster(String examId);

  /// Updates a student's parent phone number (Teacher role).
  Future<Result<bool>> updateStudentParentPhone({
    required String studentId,
    required String parentPhone,
  });
}

