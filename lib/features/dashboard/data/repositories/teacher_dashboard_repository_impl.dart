import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/teacher_radar_alerts.dart';
import '../../domain/repositories/teacher_dashboard_repository.dart';
import '../datasources/teacher_dashboard_remote_datasource.dart';

class TeacherDashboardRepositoryImpl implements TeacherDashboardRepository {
  final TeacherDashboardRemoteDataSource remoteDataSource;

  TeacherRadarAlerts? _cachedAlerts;
  String? _cachedTeacherId;
  DateTime? _cachedAt;
  static const Duration _cacheTtl = Duration(seconds: 90);

  TeacherDashboardRepositoryImpl(this.remoteDataSource);

  @override
  Future<Result<TeacherRadarAlerts>> getTeacherRadarAlerts(
    String teacherId, {
    bool forceRefresh = false,
  }) async {
    try {
      final now = DateTime.now();

      // Return immediately from in-memory cache if fresh
      if (!forceRefresh &&
          _cachedAlerts != null &&
          _cachedTeacherId == teacherId &&
          _cachedAt != null &&
          now.difference(_cachedAt!) < _cacheTtl) {
        return Result.success(_cachedAlerts!);
      }

      final alerts = await remoteDataSource.getTeacherRadarAlerts(teacherId);
      _cachedAlerts = alerts;
      _cachedTeacherId = teacherId;
      _cachedAt = now;
      return Result.success(alerts);
    } on ServerException catch (e) {
      if (_cachedAlerts != null && _cachedTeacherId == teacherId) {
        return Result.success(_cachedAlerts!);
      }
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      if (_cachedAlerts != null && _cachedTeacherId == teacherId) {
        return Result.success(_cachedAlerts!);
      }
      return Result.failure(ServerFailure('Unexpected error: $e'));
    }
  }
}
