import '../../../../core/errors/result.dart';
import '../entities/assignment_entity.dart';

abstract class AssignmentsRepository {
  /// Fetches all assignments belonging to a specific group (for teachers).
  Future<Result<List<AssignmentEntity>>> getGroupAssignments(
    String groupId, {
    int page = 0,
    int pageSize = 15,
  });

  /// Fetches all assignments available to the currently logged-in student across all their groups,
  /// including the student's submission status for each assignment.
  Future<Result<List<AssignmentEntity>>> getStudentAssignments({
    int page = 0,
    int pageSize = 15,
  });

  /// Fetches detailed information for a specific assignment.
  Future<Result<AssignmentEntity>> getAssignmentDetails(String assignmentId);

  /// Fetches all student submissions for a specific assignment (for teachers).
  Future<Result<List<AssignmentSubmissionEntity>>> getSubmissions(String assignmentId);

  /// Fetches the current logged-in student's submission for an assignment, if any.
  Future<Result<AssignmentSubmissionEntity?>> getMySubmission(String assignmentId);

  /// Creates a new assignment for a group (creates content record + assignments record).
  Future<Result<AssignmentEntity>> createAssignment({
    required String groupId,
    required String title,
    String? instructions,
    DateTime? dueAt,
    bool allowLateSubmission = false,
    int maxScore = 100,
  });

  /// Submits an assignment with uploaded files.
  Future<Result<AssignmentSubmissionEntity>> submitAssignment({
    required String assignmentId,
    required List<({String fileName, List<int> bytes, String mimeType})> files,
  });

  /// Grades a student submission (score + feedback).
  Future<Result<AssignmentSubmissionEntity>> gradeSubmission({
    required String submissionId,
    required int score,
    String? feedback,
  });

  /// Generates a temporary signed URL to view/download a private submission file.
  Future<Result<String>> getSubmissionFileSignedUrl(
    String storagePath, {
    int expiresInSeconds = 3600,
  });
}
