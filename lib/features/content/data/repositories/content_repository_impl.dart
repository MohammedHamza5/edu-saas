import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/content_entity.dart';
import '../../domain/entities/lesson_assignment_entity.dart';
import '../../domain/repositories/content_repository.dart';
import '../datasources/content_remote_datasource.dart';

class ContentRepositoryImpl implements ContentRepository {
  final ContentRemoteDataSource _remoteDataSource;

  ContentRepositoryImpl({
    required ContentRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<Result<List<ContentEntity>>> getGroupContent({
    required String groupId,
    ContentStatus? statusFilter,
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      final models = await _remoteDataSource.getGroupContent(
        groupId: groupId,
        statusFilter: statusFilter?.value,
        page: page,
        pageSize: pageSize,
      );
      return Success(models);
    } catch (e) {
      return FailureResult(
        ServerFailure('فشل في جلب المحتوى التعليمي للمجموعة: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Result<ContentEntity>> createContent({
    String? groupId,
    required String title,
    String? description,
    required ContentType type,
    required ContentStatus status,
    int? sortOrder,
    String? fileName,
    String? storagePath,
    String? mimeType,
    int? fileSize,
    List<int>? fileBytes,
    String? associatedExamId,
    String? prerequisiteExamId,
  }) async {
    try {
      final model = await _remoteDataSource.createContent(
        groupId: groupId,
        title: title,
        description: description,
        type: type.value,
        status: status.value,
        sortOrder: sortOrder,
        fileName: fileName,
        storagePath: storagePath,
        mimeType: mimeType,
        fileSize: fileSize,
        fileBytes: fileBytes,
        associatedExamId: associatedExamId,
        prerequisiteExamId: prerequisiteExamId,
      );
      return Success(model);
    } catch (e) {
      return FailureResult(
        ServerFailure('فشل في إنشاء المحتوى التعليمي: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Result<ContentEntity>> updateContent({
    required String contentId,
    String? title,
    String? description,
    ContentType? type,
    ContentStatus? status,
    int? sortOrder,
    String? fileName,
    String? storagePath,
    String? mimeType,
    int? fileSize,
    List<int>? fileBytes,
    String? associatedExamId,
    String? prerequisiteExamId,
  }) async {
    try {
      final model = await _remoteDataSource.updateContent(
        contentId: contentId,
        title: title,
        description: description,
        type: type?.value,
        status: status?.value,
        sortOrder: sortOrder,
        fileName: fileName,
        storagePath: storagePath,
        mimeType: mimeType,
        fileSize: fileSize,
        fileBytes: fileBytes,
        associatedExamId: associatedExamId,
        prerequisiteExamId: prerequisiteExamId,
      );
      return Success(model);
    } catch (e) {
      return FailureResult(
        ServerFailure('فشل في تعديل بيانات المحتوى: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Result<void>> updateContentStatus({
    required String contentId,
    required ContentStatus status,
  }) async {
    try {
      await _remoteDataSource.updateContentStatus(
        contentId: contentId,
        status: status.value,
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(
        ServerFailure('فشل في تحديث حالة المحتوى: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Result<void>> reorderContentItems({
    required List<String> contentIdsInOrder,
    String? groupId,
  }) async {
    try {
      await _remoteDataSource.reorderContentItems(
        contentIdsInOrder: contentIdsInOrder,
        groupId: groupId,
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(
        ServerFailure('فشل في حفظ ترتيب المحتوى: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Result<void>> deleteContent(String contentId) async {
    try {
      await _remoteDataSource.deleteContent(contentId);
      return const Success(null);
    } catch (e) {
      return FailureResult(
        ServerFailure('فشل في حذف عنصر المحتوى: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Result<String>> getSignedFileUrl({
    required String storagePath,
    int expiresInSeconds = 3600,
  }) async {
    try {
      final url = await _remoteDataSource.getSignedFileUrl(
        storagePath: storagePath,
        expiresInSeconds: expiresInSeconds,
      );
      return Success(url);
    } catch (e) {
      return FailureResult(
        ServerFailure('فشل في إنشاء الرابط الآمن للملف: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Result<List<ContentEntity>>> getCentralVideoBank({
    int page = 0,
    int pageSize = 100,
  }) async {
    try {
      final models = await _remoteDataSource.getCentralVideoBank(
        page: page,
        pageSize: pageSize,
      );
      return Success(models);
    } catch (e) {
      return FailureResult(
        ServerFailure('فشل في جلب بنك المحاضرات: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Result<void>> assignContentToGroups({
    required String contentId,
    required List<String> groupIds,
    List<Map<String, dynamic>>? groupConfigs,
  }) async {
    try {
      await _remoteDataSource.assignContentToGroups(
        contentId: contentId,
        groupIds: groupIds,
        groupConfigs: groupConfigs,
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(
        ServerFailure('فشل في ربط المحتوى بالمجموعات: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Result<void>> linkLessonExam({
    required String contentId,
    required String examId,
  }) async {
    try {
      await _remoteDataSource.linkLessonExam(
        contentId: contentId,
        examId: examId,
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(
        ServerFailure('فشل في ربط الاختبار بالدرس: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Result<List<LessonAssignmentEntity>>> getGroupCourseProgress({
    required String groupId,
    String? studentId,
  }) async {
    try {
      final data = await _remoteDataSource.getGroupCourseProgress(
        groupId: groupId,
        studentId: studentId,
      );
      
      final lessons = data.map((Map<String, dynamic> e) => LessonAssignmentEntity.fromJson(e)).toList();
      return Success(lessons);
    } catch (e) {
      return FailureResult(
        ServerFailure('فشل في جلب تقدم الدورة', details: e.toString()),
      );
    }
  }

  @override
  Future<Result<void>> manualUnlockLesson({
    required String studentId,
    required String groupId,
    required String contentId,
    String? reason,
  }) async {
    try {
      await _remoteDataSource.manualUnlockLesson(
        studentId: studentId,
        groupId: groupId,
        contentId: contentId,
        reason: reason,
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(
        ServerFailure('فشل في إلغاء قفل الدرس', details: e.toString()),
      );
    }
  }
}
