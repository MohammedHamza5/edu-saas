import 'package:equatable/equatable.dart';

class TeacherRadarAlerts extends Equatable {
  final List<RadarAlertItem> lowScores;
  final List<RadarAlertItem> unwatchedVideos;
  final List<RadarAlertItem> overdueAssignments;

  const TeacherRadarAlerts({
    this.lowScores = const [],
    this.unwatchedVideos = const [],
    this.overdueAssignments = const [],
  });

  @override
  List<Object?> get props => [lowScores, unwatchedVideos, overdueAssignments];
}

class RadarAlertItem extends Equatable {
  final String studentId;
  final String name;
  final String group;
  final String detail;

  const RadarAlertItem({
    required this.studentId,
    required this.name,
    required this.group,
    required this.detail,
  });

  factory RadarAlertItem.fromJson(Map<String, dynamic> json) {
    return RadarAlertItem(
      studentId: json['student_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      group: json['group'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [studentId, name, group, detail];
}
