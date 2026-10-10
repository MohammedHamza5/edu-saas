import 'package:equatable/equatable.dart';

/// Entity representing verified academic progress data for a student over a given period.
class StudentAcademicReportEntity extends Equatable {
  final String studentId;
  final String studentName;
  final String? studentPhone;
  final String? parentPhone;
  final String? groupNames;
  final int? periodDays; // null = all time, 7 = week, 14 = 2 weeks, 30 = month

  // Lectures / Videos
  final int videosWatched;
  final int videosCompleted;
  final double avgVideoPercentage;
  final int totalAssignedVideos;

  // Assignments
  final int assignmentsSubmitted;
  final int assignmentsReviewed;
  final int totalAssignedAssignments;

  // Exams
  final int examsSubmitted;
  final double avgExamPercentage;
  final String? latestExamTitle;
  final int? latestExamScore;
  final int? latestExamMaxScore;
  final double? latestExamPercentage;

  // Study Time / Engagement
  final int activeStudyMinutes;
  final DateTime? lastSeenAt;

  // Attendance
  final int totalSessions;
  final int attendedSessions;
  final int absentSessions;

  const StudentAcademicReportEntity({
    required this.studentId,
    required this.studentName,
    this.studentPhone,
    this.parentPhone,
    this.groupNames,
    this.periodDays,
    this.videosWatched = 0,
    this.videosCompleted = 0,
    this.avgVideoPercentage = 0.0,
    this.totalAssignedVideos = 0,
    this.assignmentsSubmitted = 0,
    this.assignmentsReviewed = 0,
    this.totalAssignedAssignments = 0,
    this.examsSubmitted = 0,
    this.avgExamPercentage = 0.0,
    this.latestExamTitle,
    this.latestExamScore,
    this.latestExamMaxScore,
    this.latestExamPercentage,
    this.activeStudyMinutes = 0,
    this.lastSeenAt,
    this.totalSessions = 0,
    this.attendedSessions = 0,
    this.absentSessions = 0,
  });

  @override
  List<Object?> get props => [
    studentId,
    studentName,
    studentPhone,
    parentPhone,
    groupNames,
    periodDays,
    videosWatched,
    videosCompleted,
    avgVideoPercentage,
    totalAssignedVideos,
    assignmentsSubmitted,
    assignmentsReviewed,
    totalAssignedAssignments,
    examsSubmitted,
    avgExamPercentage,
    latestExamTitle,
    latestExamScore,
    latestExamMaxScore,
    latestExamPercentage,
    activeStudyMinutes,
    lastSeenAt,
    totalSessions,
    attendedSessions,
    absentSessions,
  ];
}
