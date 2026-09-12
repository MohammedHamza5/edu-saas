import 'package:equatable/equatable.dart';
import '../../domain/entities/student_dashboard_stats.dart';

abstract class StudentDashboardState extends Equatable {
  const StudentDashboardState();

  @override
  List<Object?> get props => [];
}

class StudentDashboardInitial extends StudentDashboardState {}

class StudentDashboardLoading extends StudentDashboardState {}

class StudentDashboardLoaded extends StudentDashboardState {
  final StudentDashboardStats stats;

  const StudentDashboardLoaded({required this.stats});

  @override
  List<Object?> get props => [stats];
}

class StudentDashboardError extends StudentDashboardState {
  final String message;

  const StudentDashboardError({required this.message});

  @override
  List<Object?> get props => [message];
}
