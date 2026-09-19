import '../../../../core/errors/result.dart';
import '../entities/teacher_radar_alerts.dart';

abstract class TeacherDashboardRepository {
  Future<Result<TeacherRadarAlerts>> getTeacherRadarAlerts(
    String teacherId, {
    bool forceRefresh = false,
  });
}
