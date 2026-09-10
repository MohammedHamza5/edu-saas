import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/student_360_entity.dart';
import '../../domain/entities/student_entity.dart';
import '../../domain/repositories/students_repository.dart';
import '../datasources/students_remote_datasource.dart';

class StudentsRepositoryImpl implements StudentsRepository {
  final StudentsRemoteDataSource _remoteDataSource;

  StudentsRepositoryImpl({StudentsRemoteDataSource? remoteDataSource})
      : _remoteDataSource =
            remoteDataSource ?? StudentsRemoteDataSourceImpl();

  @override
  Future<Result<List<StudentEntity>>> getStudents({
    String? status,
    String? searchQuery,
    int page = 0,
    int pageSize = 25,
  }) async {
    try {
      final students = await _remoteDataSource.getStudents(
        status: status,
        searchQuery: searchQuery,
        page: page,
        pageSize: pageSize,
      );
      return Success(students);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<StudentEntity>>> getPendingStudents() async {
    try {
      final students = await _remoteDataSource.getPendingStudents();
      return Success(students);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<StudentEntity>> changeStudentStatus({
    required String studentId,
    required String action,
  }) async {
    try {
      final student = await _remoteDataSource.changeStudentStatus(
        studentId: studentId,
        action: action,
      );
      return Success(student);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Student360Entity>> getStudent360(String studentId) async {
    try {
      final stats = await _remoteDataSource.getStudent360(studentId);
      return Success(stats);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<StudentEntity>> getStudent(String studentId) async {
    try {
      final student = await _remoteDataSource.getStudent(studentId);
      return Success(student);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> assignStudentToGroup({
    required String studentId,
    required String groupId,
    required bool add,
  }) async {
    try {
      await _remoteDataSource.assignStudentToGroup(
        studentId: studentId,
        groupId: groupId,
        add: add,
      );
      return const Success(null);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<StudentGroupInfo>>> getAvailableGroupsForStudent(
    String studentId,
  ) async {
    try {
      final groups =
          await _remoteDataSource.getAvailableGroupsForStudent(studentId);
      return Success(groups);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }
}
