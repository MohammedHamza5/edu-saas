import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/assignment_entity.dart';
import '../../domain/repositories/assignments_repository.dart';
import '../datasources/assignments_remote_datasource.dart';

class AssignmentsRepositoryImpl implements AssignmentsRepository {
  final AssignmentsRemoteDataSource _remoteDataSource;

  AssignmentsRepositoryImpl({AssignmentsRemoteDataSource? remoteDataSource})
      : _remoteDataSource =
            remoteDataSource ?? AssignmentsRemoteDataSourceImpl();

  @override
  Future<Result<List<AssignmentEntity>>> getGroupAssignments(
    String groupId, {
    int page = 0,
    int pageSize = 15,
  }) async {
    try {
      final assignments = await _remoteDataSource.getGroupAssignments(
        groupId,
        page: page,
        pageSize: pageSize,
      );
      return Success(assignments);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<AssignmentEntity>>> getStudentAssignments({
    int page = 0,
    int pageSize = 15,
  }) async {
    try {
      final assignments = await _remoteDataSource.getStudentAssignments(
        page: page,
        pageSize: pageSize,
      );
      return Success(assignments);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<AssignmentEntity>> getAssignmentDetails(String assignmentId) async {
    try {
      final assignment = await _remoteDataSource.getAssignmentDetails(assignmentId);
      return Success(assignment);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<AssignmentSubmissionEntity>>> getSubmissions(String assignmentId) async {
    try {
      final submissions = await _remoteDataSource.getSubmissions(assignmentId);
      return Success(submissions);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<AssignmentSubmissionEntity?>> getMySubmission(String assignmentId) async {
    try {
      final submission = await _remoteDataSource.getMySubmission(assignmentId);
      return Success(submission);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<AssignmentEntity>> createAssignment({
    required String groupId,
    required String title,
    String? instructions,
    DateTime? dueAt,
    bool allowLateSubmission = false,
    int maxScore = 100,
  }) async {
    try {
      final assignment = await _remoteDataSource.createAssignment(
        groupId: groupId,
        title: title,
        instructions: instructions,
        dueAt: dueAt,
        allowLateSubmission: allowLateSubmission,
        maxScore: maxScore,
      );
      return Success(assignment);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<AssignmentSubmissionEntity>> submitAssignment({
    required String assignmentId,
    required List<({String fileName, List<int> bytes, String mimeType})> files,
  }) async {
    try {
      final submission = await _remoteDataSource.submitAssignment(
        assignmentId: assignmentId,
        files: files,
      );
      return Success(submission);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<AssignmentSubmissionEntity>> gradeSubmission({
    required String submissionId,
    required int score,
    String? feedback,
  }) async {
    try {
      final submission = await _remoteDataSource.gradeSubmission(
        submissionId: submissionId,
        score: score,
        feedback: feedback,
      );
      return Success(submission);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<String>> getSubmissionFileSignedUrl(
    String storagePath, {
    int expiresInSeconds = 3600,
  }) async {
    try {
      final url = await _remoteDataSource.getSubmissionFileSignedUrl(
        storagePath,
        expiresInSeconds: expiresInSeconds,
      );
      return Success(url);
    } on StorageException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }
}
