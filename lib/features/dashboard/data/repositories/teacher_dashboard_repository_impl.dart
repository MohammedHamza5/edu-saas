import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/teacher_radar_alerts.dart';
import '../../domain/repositories/teacher_dashboard_repository.dart';
import '../datasources/teacher_dashboard_remote_datasource.dart';

class TeacherDashboardRepositoryImpl implements TeacherDashboardRepository {
  final TeacherDashboardRemoteDataSource remoteDataSource;

  TeacherDashboardRepositoryImpl(this.remoteDataSource);

  @override
  Future<Result<TeacherRadarAlerts>> getTeacherRadarAlerts(String teacherId) async {
    try {
      final alerts = await remoteDataSource.getTeacherRadarAlerts(teacherId);
      return Result.success(alerts);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(ServerFailure('Unexpected error: $e'));
    }
  }
}
