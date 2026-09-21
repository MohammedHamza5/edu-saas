import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/result.dart';
import '../../domain/repositories/content_repository.dart';
import 'course_progress_state.dart';

class CourseProgressCubit extends Cubit<CourseProgressState> {
  final ContentRepository _repository;

  CourseProgressCubit({
    required ContentRepository repository,
  })  : _repository = repository,
        super(const CourseProgressInitial());

  Future<void> loadCourseProgress(String groupId, {String? studentId, bool isTeacher = false}) async {
    if (state is CourseProgressLoaded) {
      emit((state as CourseProgressLoaded).copyWith(isRefreshing: true));
    } else {
      emit(const CourseProgressLoading());
    }

    final result = await _repository.getGroupCourseProgress(
      groupId: groupId,
      studentId: studentId,
    );

    switch (result) {
      case Success(:final data):
        emit(CourseProgressLoaded(lessons: data));
      case FailureResult(:final failure):
        emit(CourseProgressError(failure.message));
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
}
