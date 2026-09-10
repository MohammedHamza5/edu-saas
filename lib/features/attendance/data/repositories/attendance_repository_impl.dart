import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/attendance_entity.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../datasources/attendance_remote_datasource.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  final AttendanceRemoteDataSource _remoteDataSource;

  AttendanceRepositoryImpl({AttendanceRemoteDataSource? remoteDataSource})
    : _remoteDataSource = remoteDataSource ?? AttendanceRemoteDataSourceImpl();

  @override
  Future<Result<List<StudentAttendanceItem>>> getGroupStudentsWithAttendance({
    required String groupId,
    required DateTime date,
  }) async {
    try {
      final items = await _remoteDataSource.getGroupStudentsWithAttendance(
        groupId: groupId,
        date: date,
      );
      return Success(items);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> saveGroupAttendance({
    required String groupId,
    required DateTime date,
    required List<StudentAttendanceItem> items,
  }) async {
    try {
      await _remoteDataSource.saveGroupAttendance(
        groupId: groupId,
        date: date,
        items: items,
      );
      return const Success(null);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<AttendanceEntity>>> getStudentAttendanceHistory({
    required String studentId,
    String? groupId,
  }) async {
    try {
      final history = await _remoteDataSource.getStudentAttendanceHistory(
        studentId: studentId,
        groupId: groupId,
      );
      return Success(history);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<AttendanceStats>> getStudentAttendanceStats({
    required String studentId,
    String? groupId,
  }) async {
    try {
      final stats = await _remoteDataSource.getStudentAttendanceStats(
        studentId: studentId,
        groupId: groupId,
      );
      return Success(stats);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }
}
