import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/student_dashboard_repository.dart';
import 'student_dashboard_state.dart';

class StudentDashboardCubit extends Cubit<StudentDashboardState> {
  final StudentDashboardRepository _repository;

  StudentDashboardCubit({required StudentDashboardRepository repository})
      : _repository = repository,
        super(StudentDashboardInitial());

  Future<void> loadDashboardStats(String studentId) async {
    emit(StudentDashboardLoading());

    final result = await _repository.getStudentDashboardStats(studentId);

    result.when(
      onSuccess: (stats) => emit(StudentDashboardLoaded(stats: stats)),
      onFailure: (failure) => emit(StudentDashboardError(message: failure.message)),
    );
  }
}
