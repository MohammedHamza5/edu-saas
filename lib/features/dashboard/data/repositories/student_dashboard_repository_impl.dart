import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/student_dashboard_stats.dart';
import '../../domain/repositories/student_dashboard_repository.dart';
import '../datasources/student_dashboard_remote_datasource.dart';

class StudentDashboardRepositoryImpl implements StudentDashboardRepository {
  final StudentDashboardRemoteDataSource remoteDataSource;

  StudentDashboardStats? _cachedStats;
  String? _cachedStudentId;
  DateTime? _cachedAt;
  static const Duration _cacheTtl = Duration(seconds: 90);

  StudentDashboardRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Result<StudentDashboardStats>> getStudentDashboardStats(
    String studentId, {
    bool forceRefresh = false,
  }) async {
    try {
      final now = DateTime.now();

      // Return instantly from in-memory cache if valid and not forcing refresh
      if (!forceRefresh &&
          _cachedStats != null &&
          _cachedStudentId == studentId &&
          _cachedAt != null &&
          now.difference(_cachedAt!) < _cacheTtl) {
        return Result.success(_cachedStats!);
      }

      final stats = await remoteDataSource.getStudentDashboardStats(studentId);
      _cachedStats = stats;
      _cachedStudentId = studentId;
      _cachedAt = now;
      return Result.success(stats);
    } on ServerException catch (e) {
      // Graceful degradation: return cached data if available
      if (_cachedStats != null && _cachedStudentId == studentId) {
        return Result.success(_cachedStats!);
      }
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      if (_cachedStats != null && _cachedStudentId == studentId) {
        return Result.success(_cachedStats!);
      }
      return Result.failure(ServerFailure('Unexpected error: $e'));
    }
  }
}
