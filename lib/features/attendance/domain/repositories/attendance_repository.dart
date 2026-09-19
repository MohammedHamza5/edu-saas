import '../../../../core/errors/result.dart';
import '../entities/attendance_entity.dart';

abstract interface class AttendanceRepository {
  /// Fetches all active students in a group combined with any existing attendance record for the date
  Future<Result<List<StudentAttendanceItem>>> getGroupStudentsWithAttendance({
    required String groupId,
    required DateTime date,
  });

  /// Saves or updates attendance for the entire group on the specified date atomically (upsert)
  Future<Result<void>> saveGroupAttendance({
    required String groupId,
    required DateTime date,
    required List<StudentAttendanceItem> items,
  });

  /// Fetches a student's attendance history, optionally filtered by group and paginated
  Future<Result<List<AttendanceEntity>>> getStudentAttendanceHistory({
    required String studentId,
    String? groupId,
    int? page,
    int? pageSize,
  });

  /// Calculates attendance statistics (present, absent, late, excused, percentage)
  Future<Result<AttendanceStats>> getStudentAttendanceStats({
    required String studentId,
    String? groupId,
  });
}
