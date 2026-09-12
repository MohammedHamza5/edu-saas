import 'package:equatable/equatable.dart';

class StudentDashboardStats extends Equatable {
  final double attendancePercentage;
  final double examAverage;
  final int assignmentsSubmitted;
  final double videoCompletionPercentage;
  final String activeGroupName;
  final String activeGroupLevel;

  const StudentDashboardStats({
    required this.attendancePercentage,
    required this.examAverage,
    required this.assignmentsSubmitted,
    required this.videoCompletionPercentage,
    required this.activeGroupName,
    required this.activeGroupLevel,
  });

  factory StudentDashboardStats.empty() {
    return const StudentDashboardStats(
      attendancePercentage: 0,
      examAverage: 0,
      assignmentsSubmitted: 0,
      videoCompletionPercentage: 0,
      activeGroupName: 'No Active Group',
      activeGroupLevel: 'N/A',
    );
  }

  @override
  List<Object?> get props => [
        attendancePercentage,
        examAverage,
        assignmentsSubmitted,
        videoCompletionPercentage,
        activeGroupName,
        activeGroupLevel,
      ];
}
