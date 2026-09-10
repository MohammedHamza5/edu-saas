import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/content_entity.dart';
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
  }) async {
    try {
      final models = await _remoteDataSource.getGroupContent(
        groupId: groupId,
        statusFilter: statusFilter?.value,
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
    required String groupId,
    required String title,
    String? description,
    required ContentType type,
    required ContentStatus status,
    int? sortOrder,
    String? fileName,
    String? storagePath,
    String? mimeType,
    int? fileSize,
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
  }) async {
    try {
      final model = await _remoteDataSource.updateContent(
        contentId: contentId,
        title: title,
        description: description,
        type: type?.value,
        status: status?.value,
        sortOrder: sortOrder,
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
  }) async {
    try {
      await _remoteDataSource.reorderContentItems(
        contentIdsInOrder: contentIdsInOrder,
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
}
