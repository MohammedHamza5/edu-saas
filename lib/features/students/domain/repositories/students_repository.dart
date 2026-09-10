import '../../../../core/errors/result.dart';
import '../entities/student_360_entity.dart';
import '../entities/student_entity.dart';

/// Contract: Teacher can read/manage all students in their tenant.
/// approve-student action MUST go through Edge Function — never direct DB update from Flutter.
abstract interface class StudentsRepository {
  /// Paginated list of all students in the tenant.
  /// [status]: null = all | 'pending' | 'active' | 'rejected' | 'suspended'
  /// [searchQuery]: filters on full_name / email (DB-side)
  Future<Result<List<StudentEntity>>> getStudents({
    String? status,
    String? searchQuery,
    int page = 0,
    int pageSize = 25,
  });

  /// Pending students only — shortcut for T-03 screen.
  Future<Result<List<StudentEntity>>> getPendingStudents();

  /// Approve / Reject / Suspend / Activate a student via `approve-student` Edge Function.
  /// [action]: 'approve' | 'reject' | 'suspend' | 'activate'
  Future<Result<StudentEntity>> changeStudentStatus({
    required String studentId,
    required String action,
  });

  /// Student 360° aggregated data for T-04 screen.
  Future<Result<Student360Entity>> getStudent360(String studentId);

  /// Single student details.
  Future<Result<StudentEntity>> getStudent(String studentId);

  /// Assign / remove a student from a group.
  /// [add]: true = add, false = remove.
  Future<Result<void>> assignStudentToGroup({
    required String studentId,
    required String groupId,
    required bool add,
  });

  /// Groups the student is NOT yet a member of (for T-05 picker).
  Future<Result<List<StudentGroupInfo>>> getAvailableGroupsForStudent(
    String studentId,
  );
}
