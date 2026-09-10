import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/exam_entity.dart';
import '../../domain/repositories/exams_repository.dart';
import '../datasources/exams_remote_datasource.dart';
import '../models/exam_question_model.dart';

class ExamsRepositoryImpl implements ExamsRepository {
  final ExamsRemoteDataSource _remoteDataSource;

  ExamsRepositoryImpl({ExamsRemoteDataSource? remoteDataSource})
      : _remoteDataSource =
            remoteDataSource ?? ExamsRemoteDataSourceImpl();

  @override
  Future<Result<List<ExamEntity>>> getGroupExams(String groupId) async {
    try {
      final exams = await _remoteDataSource.getGroupExams(groupId);
      return Success(exams);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<ExamEntity>>> getStudentExams() async {
    try {
      final exams = await _remoteDataSource.getStudentExams();
      return Success(exams);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<ExamEntity>> getExamDetails(String examId) async {
    try {
      final exam = await _remoteDataSource.getExamDetails(examId);
      return Success(exam);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<ExamEntity>> createExam({
    required String groupId,
    required String title,
    int durationMinutes = 60,
    int maxScore = 100,
    int? passingScore,
    bool shuffleQuestions = false,
    bool showResult = true,
    bool allowRetake = false,
    DateTime? startAt,
    DateTime? endAt,
    required List<ExamQuestionEntity> initialQuestions,
  }) async {
    try {
      final questionsModels = initialQuestions.map((q) {
        return ExamQuestionModel(
          id: q.id,
          examVersionId: q.examVersionId,
          questionText: q.questionText,
          questionType: q.questionType,
          points: q.points,
          sortOrder: q.sortOrder,
          options: q.options,
        );
      }).toList();

      final created = await _remoteDataSource.createExam(
        groupId: groupId,
        title: title,
        durationMinutes: durationMinutes,
        maxScore: maxScore,
        passingScore: passingScore,
        shuffleQuestions: shuffleQuestions,
        showResult: showResult,
        allowRetake: allowRetake,
        startAt: startAt,
        endAt: endAt,
        initialQuestions: questionsModels,
      );
      return Success(created);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<ExamVersionEntity>> publishExamVersion(String versionId) async {
    try {
      final version = await _remoteDataSource.publishExamVersion(versionId);
      return Success(version);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<ExamVersionEntity>> createNewExamVersion(String examId) async {
    try {
      final version = await _remoteDataSource.createNewExamVersion(examId);
      return Success(version);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<ExamAttemptEntity>> startExam(String examId) async {
    try {
      final attempt = await _remoteDataSource.startExam(examId);
      return Success(attempt);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<ExamAttemptEntity>> submitExam({
    required String attemptId,
    required Map<String, String> answers,
  }) async {
    try {
      final attempt = await _remoteDataSource.submitExam(
        attemptId: attemptId,
        answers: answers,
      );
      return Success(attempt);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<ExamAttemptEntity>>> getExamAttempts(String examId) async {
    try {
      final attempts = await _remoteDataSource.getExamAttempts(examId);
      return Success(attempts);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<ExamAttemptEntity>> getAttemptDetails(String attemptId) async {
    try {
      final attempt = await _remoteDataSource.getAttemptDetails(attemptId);
      return Success(attempt);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }
}
