import 'package:equatable/equatable.dart';
import '../../domain/entities/teacher_radar_alerts.dart';

abstract class TeacherDashboardState extends Equatable {
  const TeacherDashboardState();

  @override
  List<Object?> get props => [];
}

class TeacherDashboardInitial extends TeacherDashboardState {}

class TeacherDashboardLoading extends TeacherDashboardState {}

class TeacherDashboardLoaded extends TeacherDashboardState {
  final TeacherRadarAlerts alerts;

  const TeacherDashboardLoaded({required this.alerts});

  @override
  List<Object?> get props => [alerts];
}

class TeacherDashboardError extends TeacherDashboardState {
  final String message;

  const TeacherDashboardError({required this.message});

  @override
  List<Object?> get props => [message];
}
