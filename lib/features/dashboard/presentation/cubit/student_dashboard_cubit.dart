import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/student_dashboard_repository.dart';
import 'student_dashboard_state.dart';

class StudentDashboardCubit extends Cubit<StudentDashboardState> {
  final StudentDashboardRepository _repository;

  StudentDashboardCubit({required StudentDashboardRepository repository})
      : _repository = repository,
        super(StudentDashboardInitial());

  Future<void> loadDashboardStats(
    String studentId, {
    bool forceRefresh = false,
  }) async {
    // Only emit loading spinner on initial load to avoid jarring UI flickers on tab return
    if (state is! StudentDashboardLoaded) {
      emit(StudentDashboardLoading());
    }

    final result = await _repository.getStudentDashboardStats(
      studentId,
      forceRefresh: forceRefresh,
    );

    result.when(
      onSuccess: (stats) => emit(StudentDashboardLoaded(stats: stats)),
      onFailure: (failure) {
        if (state is! StudentDashboardLoaded) {
          emit(StudentDashboardError(message: failure.message));
        }
      },
    );
  }
}
