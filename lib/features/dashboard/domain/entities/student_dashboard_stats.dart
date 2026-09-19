import 'package:equatable/equatable.dart';

class ContinueLearningItem extends Equatable {
  final String videoId;
  final String contentId;
  final String title;
  final String groupName;
  final int progressSeconds;
  final int durationSeconds;
  final double percentage;

  const ContinueLearningItem({
    required this.videoId,
    required this.contentId,
    required this.title,
    required this.groupName,
    required this.progressSeconds,
    required this.durationSeconds,
    required this.percentage,
  });

  @override
  List<Object?> get props => [
        videoId,
        contentId,
        title,
        groupName,
        progressSeconds,
        durationSeconds,
        percentage,
      ];
}

class UrgentTaskItem extends Equatable {
  final String id;
  final String title;
  final String groupName;
  final String taskType; // 'assignment' or 'exam'
  final DateTime? dueAt;
  final String status;
  final int? maxScore;

  const UrgentTaskItem({
    required this.id,
    required this.title,
    required this.groupName,
    required this.taskType,
    this.dueAt,
    required this.status,
    this.maxScore,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        groupName,
        taskType,
        dueAt,
        status,
        maxScore,
      ];
}

class StudentDashboardStats extends Equatable {
  final double attendancePercentage;
  final double examAverage;
  final int assignmentsSubmitted;
  final double videoCompletionPercentage;
  final String activeGroupName;
  final String activeGroupLevel;
  final ContinueLearningItem? continueLearningItem;
  final List<UrgentTaskItem> urgentTasks;

  const StudentDashboardStats({
    required this.attendancePercentage,
    required this.examAverage,
    required this.assignmentsSubmitted,
    required this.videoCompletionPercentage,
    required this.activeGroupName,
    required this.activeGroupLevel,
    this.continueLearningItem,
    this.urgentTasks = const [],
  });

  factory StudentDashboardStats.empty() {
    return const StudentDashboardStats(
      attendancePercentage: 0,
      examAverage: 0,
      assignmentsSubmitted: 0,
      videoCompletionPercentage: 0,
      activeGroupName: 'No Active Group',
      activeGroupLevel: 'N/A',
      continueLearningItem: null,
      urgentTasks: [],
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
        continueLearningItem,
        urgentTasks,
      ];
}
