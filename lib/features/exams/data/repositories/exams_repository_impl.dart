import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/network/retry_helper.dart';
import '../../domain/entities/exam_entity.dart';
import '../../domain/entities/exam_parent_dispatch_entity.dart';
import '../../domain/entities/mistake_entities.dart';
import '../../domain/entities/exam_folder_entity.dart';
import '../../domain/repositories/exam_draft_storage.dart';
import '../../domain/repositories/exams_repository.dart';
import '../../domain/services/exam_image_uploader.dart';
import '../datasources/exam_draft_local_datasource.dart';
import '../datasources/exams_remote_datasource.dart';
import '../models/exam_question_model.dart';
import '../services/exam_image_upload_service.dart';

class ExamsRepositoryImpl implements ExamsRepository {
  final ExamsRemoteDataSource _remoteDataSource;
  final ExamImageUploader _imageUploadService;
  final ExamDraftStorage _draftStorage;

  ExamsRepositoryImpl({
    ExamsRemoteDataSource? remoteDataSource,
    ExamImageUploader? imageUploadService,
    ExamDraftStorage? draftStorage,
  })  : _remoteDataSource = remoteDataSource ?? ExamsRemoteDataSourceImpl(),
        _imageUploadService = imageUploadService ?? ExamImageUploadService(),
        _draftStorage = draftStorage ?? const ExamDraftLocalDataSource();

  @override
  Future<Result<List<ExamEntity>>> getGroupExams(
    String groupId, {
    int page = 0,
    int pageSize = 15,
  }) async {
    try {
      final exams = await retryTransient(
        () => _remoteDataSource.getGroupExams(
          groupId,
          page: page,
          pageSize: pageSize,
        ),
      );
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
  Future<Result<List<ExamEntity>>> getStudentExams({
    int page = 0,
    int pageSize = 15,
  }) async {
    try {
      final exams = await retryTransient(
        () => _remoteDataSource.getStudentExams(
          page: page,
          pageSize: pageSize,
        ),
      );
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
      final exam = await retryTransient(
        () => _remoteDataSource.getExamDetails(examId),
      );
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
    String? groupId,
    required String title,
    int durationMinutes = 60,
    int maxScore = 100,
    int? passingScore,
    bool shuffleQuestions = false,
    bool showResult = true,
    bool allowRetake = false,
    DateTime? startAt,
    DateTime? endAt,
    bool isPublished = false,
    String? pdfFileId,
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
          imageUrl: q.imageUrl,
          imageMeta: q.imageMeta,
          contextId: q.contextId,
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
        isPublished: isPublished,
        pdfFileId: pdfFileId,
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
  Future<Result<ExamEntity>> updateExam({
    required String examId,
    required String title,
    int? durationMinutes,
    int? maxScore,
    int? passingScore,
    bool? shuffleQuestions,
    bool? showResult,
    bool? allowRetake,
    DateTime? startAt,
    DateTime? endAt,
    bool? isPublished,
    String? pdfFileId,
    bool clearPdfFile = false,
  }) async {
    try {
      final updated = await _remoteDataSource.updateExam(
        examId: examId,
        title: title,
        durationMinutes: durationMinutes,
        maxScore: maxScore,
        passingScore: passingScore,
        shuffleQuestions: shuffleQuestions,
        showResult: showResult,
        allowRetake: allowRetake,
        startAt: startAt,
        endAt: endAt,
        isPublished: isPublished,
        pdfFileId: pdfFileId,
        clearPdfFile: clearPdfFile,
      );
      return Success(updated);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<ExamEntity>> updateDraftExamQuestions({
    required String examId,
    required String title,
    int? durationMinutes,
    int? maxScore,
    int? passingScore,
    bool? shuffleQuestions,
    bool? showResult,
    bool? allowRetake,
    DateTime? startAt,
    DateTime? endAt,
    bool? isPublished,
    String? pdfFileId,
    bool clearPdfFile = false,
    required List<ExamQuestionEntity> questions,
  }) async {
    try {
      final questionsModels = questions.map((q) {
        return ExamQuestionModel(
          id: q.id,
          examVersionId: q.examVersionId,
          questionText: q.questionText,
          questionType: q.questionType,
          points: q.points,
          sortOrder: q.sortOrder,
          options: q.options,
          imageUrl: q.imageUrl,
          imageMeta: q.imageMeta,
          contextId: q.contextId,
        );
      }).toList();

      final updated = await _remoteDataSource.updateDraftExamQuestions(
        examId: examId,
        title: title,
        durationMinutes: durationMinutes,
        maxScore: maxScore,
        passingScore: passingScore,
        shuffleQuestions: shuffleQuestions,
        showResult: showResult,
        allowRetake: allowRetake,
        startAt: startAt,
        endAt: endAt,
        isPublished: isPublished,
        pdfFileId: pdfFileId,
        clearPdfFile: clearPdfFile,
        questions: questionsModels,
      );
      return Success(updated);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<String>> getSignedPdfUrl(
    String storagePath, {
    String? storageProvider,
  }) async {
    try {
      final url = await _remoteDataSource.getSignedPdfUrl(
        storagePath,
        storageProvider: storageProvider,
      );
      return Success(url);
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
  Future<Result<void>> unpublishExamVersion({
    required String examId,
    required String versionId,
  }) async {
    try {
      await _remoteDataSource.unpublishExamVersion(
        examId: examId,
        versionId: versionId,
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
    ExamSubmissionReason reason = ExamSubmissionReason.studentSubmitted,
  }) async {
    try {
      final attempt = await _remoteDataSource.submitExam(
        attemptId: attemptId,
        answers: answers,
        reason: reason,
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
  Future<Result<void>> syncExamAnswers({
    required String attemptId,
    required Map<String, String> answers,
  }) async {
    try {
      await _remoteDataSource.syncExamAnswers(
        attemptId: attemptId,
        answers: answers,
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
  Future<Result<List<ExamAttemptEntity>>> getExamAttempts(
    String examId, {
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      final attempts = await _remoteDataSource.getExamAttempts(
        examId,
        page: page,
        pageSize: pageSize,
      );
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

  @override
  Future<Result<MistakeSummaryEntity>> getStudentMistakesSummary(String studentId) async {
    try {
      final summary = await _remoteDataSource.getStudentMistakesSummary(studentId);
      return Success(summary);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<MistakeQuestionEntity>>> getStudentMistakesQuestions(
    String studentId, {
    String? examId,
    bool onlyUnresolved = true,
  }) async {
    try {
      final questions = await _remoteDataSource.getStudentMistakesQuestions(
        studentId,
        examId: examId,
        onlyUnresolved: onlyUnresolved,
      );
      return Success(questions);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<MistakePracticeResultEntity>> submitMistakesPractice(
    List<Map<String, String>> answers,
  ) async {
    try {
      final result = await _remoteDataSource.submitMistakesPractice(answers);
      return Success(result);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<bool>> updateMistakeReflection({
    required String mistakeId,
    required String? reflectionReason,
  }) async {
    try {
      await _remoteDataSource.updateMistakeReflection(
        mistakeId: mistakeId,
        reflectionReason: reflectionReason,
      );
      return const Success(true);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getGroupLessons(String groupId) async {
    try {
      final lessons = await _remoteDataSource.getGroupLessons(groupId);
      return Success(lessons);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> linkExamToLesson({
    required String examId,
    required String lessonId,
    required String groupId,
  }) async {
    try {
      await _remoteDataSource.linkExamToLesson(
        examId: examId,
        lessonId: lessonId,
        groupId: groupId,
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
  Future<Result<void>> unlinkExamFromLesson({
    required String examId,
    required String groupId,
    bool makeGeneralExam = false,
  }) async {
    try {
      await _remoteDataSource.unlinkExamFromLesson(
        examId: examId,
        groupId: groupId,
        makeGeneralExam: makeGeneralExam,
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
  Future<Result<void>> convertExamType({
    required String examId,
    required String contentId,
    required bool toLectureExam,
    required String groupId,
  }) async {
    try {
      await _remoteDataSource.convertExamType(
        examId: examId,
        contentId: contentId,
        toLectureExam: toLectureExam,
        groupId: groupId,
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
  Future<Result<bool>> deleteExam({
    required String examId,
    bool force = false,
  }) async {
    try {
      final res = await _remoteDataSource.deleteExam(
        examId: examId,
        force: force,
      );
      final success = res['success'] == true;
      return Success(success);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<ExamParentDispatchRosterEntity>> getExamParentDispatchRoster(
    String examId,
  ) async {
    try {
      final roster = await _remoteDataSource.getExamParentDispatchRoster(examId);
      return Success(roster);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<bool>> updateStudentParentPhone({
    required String studentId,
    required String parentPhone,
  }) async {
    try {
      final success = await _remoteDataSource.updateStudentParentPhone(
        studentId: studentId,
        parentPhone: parentPhone,
      );
      return Success(success);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<ExamFolderEntity>>> getExamFolders({String? groupId}) async {
    try {
      final folders = await _remoteDataSource.getExamFolders(groupId: groupId);
      return Success(folders);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<ExamFolderEntity>> createExamFolder({
    required String name,
    String? groupId,
    String? color,
    String? icon,
    String? description,
  }) async {
    try {
      final folder = await _remoteDataSource.createExamFolder(
        name: name,
        groupId: groupId,
        color: color,
        icon: icon,
        description: description,
      );
      return Success(folder);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<ExamFolderEntity>> updateExamFolder({
    required String folderId,
    required String name,
    String? color,
    String? icon,
    String? description,
  }) async {
    try {
      final folder = await _remoteDataSource.updateExamFolder(
        folderId: folderId,
        name: name,
        color: color,
        icon: icon,
        description: description,
      );
      return Success(folder);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<bool>> deleteExamFolder(String folderId) async {
    try {
      final success = await _remoteDataSource.deleteExamFolder(folderId);
      return Success(success);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<bool>> moveExamToFolder({
    required String examId,
    String? folderId,
  }) async {
    try {
      final success = await _remoteDataSource.moveExamToFolder(
        examId: examId,
        folderId: folderId,
      );
      return Success(success);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<String> uploadExamImage({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/png',
  }) {
    return _imageUploadService.uploadExamImage(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  @override
  Future<void> saveExamDraft({
    required String draftKey,
    required Map<String, dynamic> data,
  }) {
    return _draftStorage.saveDraft(draftKey: draftKey, data: data);
  }

  @override
  Future<Map<String, dynamic>?> getExamDraft(String draftKey) {
    return _draftStorage.getDraft(draftKey);
  }

  @override
  Future<void> clearExamDraft(String draftKey) {
    return _draftStorage.clearDraft(draftKey);
  }
}

