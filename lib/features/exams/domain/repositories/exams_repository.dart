import '../../../../core/errors/result.dart';
import '../entities/exam_entity.dart';

abstract class ExamsRepository {
  /// Fetches all exams belonging to a specific group (Teacher view).
  Future<Result<List<ExamEntity>>> getGroupExams(String groupId);

  /// Fetches all active and published exams available to the currently logged-in student.
  Future<Result<List<ExamEntity>>> getStudentExams();

  /// Fetches complete details of an exam including its active versions and questions.
  Future<Result<ExamEntity>> getExamDetails(String examId);

  /// Creates a new exam with its content record, exam settings, initial draft version, and questions.
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
  });

  /// Freezes an exam version as an immutable snapshot and publishes the exam.
  Future<Result<ExamVersionEntity>> publishExamVersion(String versionId);

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
}
