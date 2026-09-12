import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/student_dashboard_stats.dart';
import '../../domain/repositories/student_dashboard_repository.dart';
import '../datasources/student_dashboard_remote_datasource.dart';

class StudentDashboardRepositoryImpl implements StudentDashboardRepository {
  final StudentDashboardRemoteDataSource remoteDataSource;

  StudentDashboardRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Result<StudentDashboardStats>> getStudentDashboardStats(String studentId) async {
    try {
      final stats = await remoteDataSource.getStudentDashboardStats(studentId);
      return Result.success(stats);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(ServerFailure('Unexpected error: $e'));
    }
  }
}
