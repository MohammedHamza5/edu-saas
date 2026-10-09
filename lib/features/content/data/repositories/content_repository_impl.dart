import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/content_entity.dart';
import '../../domain/entities/lesson_assignment_entity.dart';
import '../../domain/repositories/content_repository.dart';
import '../datasources/content_remote_datasource.dart';

class ContentRepositoryImpl implements ContentRepository {
  final ContentRemoteDataSource _remoteDataSource;

  ContentRepositoryImpl({required ContentRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

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
  Future<Result<void>> assignBatchContentToGroup({
    required String groupId,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      await _remoteDataSource.assignBatchContentToGroup(
        groupId: groupId,
        items: items,
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(
        ServerFailure('فشل في ربط المحتوى بالمجموعة: ${e.toString()}'),
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

      final lessons = data
          .map((Map<String, dynamic> e) => LessonAssignmentEntity.fromJson(e))
          .toList();
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

  @override
  Future<Result<void>> toggleLessonVisibility({
    required String contentId,
    required String groupId,
    required bool isPublished,
  }) async {
    try {
      await _remoteDataSource.toggleLessonVisibility(
        contentId: contentId,
        groupId: groupId,
        isPublished: isPublished,
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(
        ServerFailure('فشل في تحديث حالة ظهور المحاضرة', details: e.toString()),
      );
    }
  }

  @override
  Future<Result<void>> toggleAllLessonsVisibility({
    required String groupId,
    required bool isPublished,
  }) async {
    try {
      await _remoteDataSource.toggleAllLessonsVisibility(
        groupId: groupId,
        isPublished: isPublished,
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(
        ServerFailure(
          'فشل في تحديث حالة ظهور جميع المحاضرات',
          details: e.toString(),
        ),
      );
    }
  }

  @override
  Future<Result<String>> uploadAndCreateFileRecord({
    required String tenantId,
    required String contentId,
    required String fileName,
    required String mimeType,
    required List<int> fileBytes,
    required String storagePath,
  }) async {
    try {
      final fileId = await _remoteDataSource.uploadAndCreateFileRecord(
        tenantId: tenantId,
        contentId: contentId,
        fileName: fileName,
        mimeType: mimeType,
        fileBytes: fileBytes,
        storagePath: storagePath,
      );
      return Success(fileId);
    } catch (e) {
      return FailureResult(ServerFailure('فشل في رفع الملف', details: e.toString()));
    }
  }

  @override
  Future<Result<List<ChapterEntity>>> getGroupChapters(String groupId) async {
    try {
      final chapters = await _remoteDataSource.getGroupChapters(groupId);
      return Success(chapters);
    } catch (e) {
      return FailureResult(
        ServerFailure('فشل في جلب فصول المجموعة', details: e.toString()),
      );
    }
  }

  @override
  Future<Result<ChapterEntity>> createChapter({
    required String groupId,
    required String title,
    bool isPublished = true,
  }) async {
    try {
      final chapter = await _remoteDataSource.createChapter(
        groupId: groupId,
        title: title,
        isPublished: isPublished,
      );
      return Success(chapter);
    } catch (e) {
      return FailureResult(
        ServerFailure('فشل في إنشاء الفصل', details: e.toString()),
      );
    }
  }

  @override
  Future<Result<void>> toggleChapterVisibility({
    required String chapterId,
    required bool isPublished,
  }) async {
    try {
      await _remoteDataSource.toggleChapterVisibility(
        chapterId: chapterId,
        isPublished: isPublished,
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(
        ServerFailure('فشل في تعديل حالة ظهور الفصل', details: e.toString()),
      );
    }
  }

  @override
  Future<Result<void>> updateChapter({
    required String chapterId,
    required String title,
  }) async {
    try {
      await _remoteDataSource.updateChapter(
        chapterId: chapterId,
        title: title,
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(
        ServerFailure('فشل في تحديث الفصل', details: e.toString()),
      );
    }
  }

  @override
  Future<Result<void>> deleteChapter(String chapterId) async {
    try {
      await _remoteDataSource.deleteChapter(chapterId);
      return const Success(null);
    } catch (e) {
      return FailureResult(
        ServerFailure('فشل في حذف الفصل', details: e.toString()),
      );
    }
  }

  @override
  Future<Result<void>> setLessonChapter({
    required String contentId,
    required String groupId,
    String? chapterId,
  }) async {
    try {
      await _remoteDataSource.setLessonChapter(
        contentId: contentId,
        groupId: groupId,
        chapterId: chapterId,
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(
        ServerFailure('فشل في تعيين فصل المحاضرة', details: e.toString()),
      );
    }
  }

  @override
  Future<Result<void>> reorderChapterLessons({
    required String groupId,
    required List<String> contentIdsInOrder,
  }) async {
    try {
      await _remoteDataSource.reorderChapterLessons(
        groupId: groupId,
        contentIdsInOrder: contentIdsInOrder,
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(
        ServerFailure('فشل في إعادة ترتيب محاضرات الفصل', details: e.toString()),
      );
    }
  }

  @override
  Future<Result<void>> reorderCourseChapters({
    required String groupId,
    required List<String> chapterIdsInOrder,
  }) async {
    try {
      await _remoteDataSource.reorderCourseChapters(
        groupId: groupId,
        chapterIdsInOrder: chapterIdsInOrder,
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(
        ServerFailure('فشل في إعادة ترتيب الفصول', details: e.toString()),
      );
    }
  }

  @override
  Future<Result<void>> removeLessonFromGroup({
    required String contentId,
    required String groupId,
  }) async {
    try {
      await _remoteDataSource.removeLessonFromGroup(
        contentId: contentId,
        groupId: groupId,
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(
        ServerFailure('فشل في إزالة المحاضرة من المجموعة', details: e.toString()),
      );
    }
  }
}
