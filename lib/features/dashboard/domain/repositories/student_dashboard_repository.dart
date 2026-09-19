import '../../../../core/errors/result.dart';
import '../entities/student_dashboard_stats.dart';

abstract class StudentDashboardRepository {
  Future<Result<StudentDashboardStats>> getStudentDashboardStats(
    String studentId, {
    bool forceRefresh = false,
  });
}
