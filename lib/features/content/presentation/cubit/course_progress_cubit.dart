import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/cache_manager.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/lesson_assignment_entity.dart';
import '../../domain/repositories/content_repository.dart';
import 'course_progress_state.dart';

class CourseProgressCubit extends Cubit<CourseProgressState> {
  final ContentRepository _repository;

  CourseProgressCubit({required ContentRepository repository})
    : _repository = repository,
      super(const CourseProgressInitial());

  Future<void> loadCourseProgress(
    String groupId, {
    String? studentId,
    bool isTeacher = false,
    bool forceRefresh = false,
  }) async {
    final cacheKey = AppCache.userKey('${groupId}_${studentId ?? ""}_progress');

    if (!forceRefresh) {
      final cached = AppCache.content.getStale(cacheKey);
      if (cached is ({List<LessonAssignmentEntity> lessons, List<ChapterEntity> chapters})) {
        emit(CourseProgressLoaded(lessons: cached.lessons, chapters: cached.chapters));
        if (AppCache.content.has(cacheKey)) {
          return; // Cache is still fresh, skip redundant network call
        }
      } else if (state is CourseProgressLoaded) {
        emit((state as CourseProgressLoaded).copyWith(isRefreshing: true));
      } else {
        emit(const CourseProgressLoading());
      }
    } else {
      if (state is CourseProgressLoaded) {
        emit((state as CourseProgressLoaded).copyWith(isRefreshing: true));
      } else {
        emit(const CourseProgressLoading());
      }
    }

    final progressFuture = _repository.getGroupCourseProgress(
      groupId: groupId,
      studentId: studentId,
    );
    final chaptersFuture = _repository.getGroupChapters(groupId);

    final results = await Future.wait([progressFuture, chaptersFuture]);
    if (isClosed) return;

    final progressResult = results[0] as Result<List<LessonAssignmentEntity>>;
    final chaptersResult = results[1] as Result<List<ChapterEntity>>;

    switch (progressResult) {
      case Success(:final data):
        final chapters = chaptersResult.dataOrNull ?? [];
        AppCache.content.put(cacheKey, (lessons: data, chapters: chapters));
        emit(CourseProgressLoaded(lessons: data, chapters: chapters));
      case FailureResult(:final failure):
        if (state is! CourseProgressLoaded) {
          emit(CourseProgressError(failure.message));
        }
    }
  }

  Future<void> manualUnlockLesson({
    required String studentId,
    required String groupId,
    required String contentId,
    String? reason,
  }) async {
    final result = await _repository.manualUnlockLesson(
      studentId: studentId,
      groupId: groupId,
      contentId: contentId,
      reason: reason,
    );

    if (result is Success) {
      // Reload the progress after a successful unlock
      await loadCourseProgress(groupId, studentId: studentId, isTeacher: true);
    } else if (result is FailureResult) {
      // We could emit a specific error state or rely on UI to handle it.
      // For now, we just emit the error state.
      emit(CourseProgressError(result.failure.message));
    }
  }

  Future<void> toggleLessonVisibility({
    required String contentId,
    required String groupId,
    required bool isPublished,
    String? studentId,
  }) async {
    final result = await _repository.toggleLessonVisibility(
      contentId: contentId,
      groupId: groupId,
      isPublished: isPublished,
    );

    if (result is Success) {
      await loadCourseProgress(groupId, studentId: studentId, isTeacher: true);
    } else if (result is FailureResult) {
      emit(CourseProgressError(result.failure.message));
    }
  }

  Future<void> toggleAllLessonsVisibility({
    required String groupId,
    required bool isPublished,
    String? studentId,
  }) async {
    final result = await _repository.toggleAllLessonsVisibility(
      groupId: groupId,
      isPublished: isPublished,
    );

    if (result is Success) {
      await loadCourseProgress(groupId, studentId: studentId, isTeacher: true);
    } else if (result is FailureResult) {
      emit(CourseProgressError(result.failure.message));
    }
  }
}
