import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/teacher_dashboard_repository.dart';
import 'teacher_dashboard_state.dart';

class TeacherDashboardCubit extends Cubit<TeacherDashboardState> {
  final TeacherDashboardRepository repository;

  TeacherDashboardCubit({required this.repository}) : super(TeacherDashboardInitial());

  Future<void> loadRadarAlerts(
    String teacherId, {
    bool forceRefresh = false,
  }) async {
    // Only emit loading spinner on initial load to prevent layout flicker
    if (state is! TeacherDashboardLoaded) {
      emit(TeacherDashboardLoading());
    }

    final result = await repository.getTeacherRadarAlerts(
      teacherId,
      forceRefresh: forceRefresh,
    );

    if (isClosed) return;

    result.when(
      onSuccess: (alerts) => emit(TeacherDashboardLoaded(alerts: alerts)),
      onFailure: (failure) {
        if (state is! TeacherDashboardLoaded) {
          emit(TeacherDashboardError(message: failure.message));
        }
      },
    );
  }
}
