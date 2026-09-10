import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/child_entity.dart';
import '../../domain/repositories/parent_repository.dart';
import '../datasources/parent_remote_datasource.dart';

class ParentRepositoryImpl implements ParentRepository {
  final ParentRemoteDataSource _remoteDataSource;

  ParentRepositoryImpl({required ParentRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  @override
  Future<Result<List<ChildEntity>>> getLinkedChildren() async {
    try {
      final children = await _remoteDataSource.getLinkedChildren();
      return Success(children);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message));
    } catch (e) {
      return FailureResult(
        ServerFailure('Failed to fetch linked children: $e'),
      );
    }
  }

  @override
  Future<Result<ChildAcademicSummary>> getChildAcademicSummary(
    String studentId,
  ) async {
    try {
      final summary = await _remoteDataSource.getChildAcademicSummary(
        studentId,
      );
      return Success(summary);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message));
    } catch (e) {
      return FailureResult(
        ServerFailure('Failed to fetch academic summary: $e'),
      );
    }
  }
}
