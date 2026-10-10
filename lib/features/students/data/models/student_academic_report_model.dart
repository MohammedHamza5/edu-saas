import '../../domain/entities/student_academic_report_entity.dart';

class StudentAcademicReportModel extends StudentAcademicReportEntity {
  const StudentAcademicReportModel({
    required super.studentId,
    required super.studentName,
    super.studentPhone,
    super.parentPhone,
    super.groupNames,
    super.periodDays,
    super.videosWatched = 0,
    super.videosCompleted = 0,
    super.avgVideoPercentage = 0.0,
    super.totalAssignedVideos = 0,
    super.assignmentsSubmitted = 0,
    super.assignmentsReviewed = 0,
    super.totalAssignedAssignments = 0,
    super.examsSubmitted = 0,
    super.avgExamPercentage = 0.0,
    super.latestExamTitle,
    super.latestExamScore,
    super.latestExamMaxScore,
    super.latestExamPercentage,
    super.activeStudyMinutes = 0,
    super.lastSeenAt,
    super.totalSessions = 0,
    super.attendedSessions = 0,
    super.absentSessions = 0,
  });

  factory StudentAcademicReportModel.fromJson(
    Map<String, dynamic> json, {
    String? fallbackStudentId,
    String? fallbackStudentName,
  }) {
    final studentMap = json['student'] as Map<String, dynamic>? ?? {};
    final videosMap = json['videos'] as Map<String, dynamic>? ?? {};
    final assignmentsMap = json['assignments'] as Map<String, dynamic>? ?? {};
    final examsMap = json['exams'] as Map<String, dynamic>? ?? {};
    final latestExamMap = examsMap['latest_exam'] as Map<String, dynamic>?;
    final engagementMap = json['engagement'] as Map<String, dynamic>? ?? {};
    final attendanceMap = json['attendance'] as Map<String, dynamic>? ?? {};

    final studentId = studentMap['id']?.toString() ?? fallbackStudentId ?? '';
    final studentName =
        studentMap['full_name']?.toString() ?? fallbackStudentName ?? '';

    DateTime? lastSeenAt;
    if (engagementMap['last_seen_at'] != null) {
      lastSeenAt = DateTime.tryParse(engagementMap['last_seen_at'].toString());
    }

    return StudentAcademicReportModel(
      studentId: studentId,
      studentName: studentName,
      studentPhone: studentMap['phone']?.toString(),
      parentPhone: studentMap['parent_phone']?.toString(),
      groupNames: studentMap['group_names']?.toString(),
      periodDays: json['period_days'] as int?,
      videosWatched: (videosMap['watched'] as num?)?.toInt() ?? 0,
      videosCompleted: (videosMap['completed'] as num?)?.toInt() ?? 0,
      avgVideoPercentage:
          (videosMap['avg_percentage'] as num?)?.toDouble() ?? 0.0,
      totalAssignedVideos: (videosMap['total_assigned'] as num?)?.toInt() ?? 0,
      assignmentsSubmitted:
          (assignmentsMap['submitted'] as num?)?.toInt() ?? 0,
      assignmentsReviewed: (assignmentsMap['reviewed'] as num?)?.toInt() ?? 0,
      totalAssignedAssignments:
          (assignmentsMap['total_assigned'] as num?)?.toInt() ?? 0,
      examsSubmitted: (examsMap['submitted'] as num?)?.toInt() ?? 0,
      avgExamPercentage:
          (examsMap['avg_percentage'] as num?)?.toDouble() ?? 0.0,
      latestExamTitle: latestExamMap?['title']?.toString(),
      latestExamScore: (latestExamMap?['score'] as num?)?.toInt(),
      latestExamMaxScore: (latestExamMap?['max_score'] as num?)?.toInt(),
      latestExamPercentage:
          (latestExamMap?['percentage'] as num?)?.toDouble(),
      activeStudyMinutes:
          (engagementMap['active_minutes'] as num?)?.toInt() ?? 0,
      lastSeenAt: lastSeenAt,
      totalSessions: (attendanceMap['total_sessions'] as num?)?.toInt() ?? 0,
      attendedSessions: (attendanceMap['attended'] as num?)?.toInt() ?? 0,
      absentSessions: (attendanceMap['absent'] as num?)?.toInt() ?? 0,
    );
  }
}
