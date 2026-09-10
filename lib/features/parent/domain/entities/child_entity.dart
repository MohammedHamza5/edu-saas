import 'package:equatable/equatable.dart';
import '../../../attendance/domain/entities/attendance_entity.dart';

/// Represents a student linked to a parent through `parent_students`
class ChildEntity extends Equatable {
  final String id; // users.id (student)
  final String parentStudentId; // parent_students.id
  final String fullName;
  final String email;
  final String? phone;
  final String? relationship; // e.g. 'Father', 'Mother', 'Guardian'
  final String? avatarUrl;
  final String status; // 'active', 'pending', 'suspended'

  const ChildEntity({
    required this.id,
    required this.parentStudentId,
    required this.fullName,
    required this.email,
    this.phone,
    this.relationship,
    this.avatarUrl,
    required this.status,
  });

  @override
  List<Object?> get props => [
    id,
    parentStudentId,
    fullName,
    email,
    phone,
    relationship,
    avatarUrl,
    status,
  ];
}

/// Represents a graded exam result for a child (Read-Only)
class ParentExamResult extends Equatable {
  final String examId;
  final String examTitle;
  final double score;
  final double maxScore;
  final double percentage;
  final DateTime submittedAt;

  const ParentExamResult({
    required this.examId,
    required this.examTitle,
    required this.score,
    required this.maxScore,
    required this.percentage,
    required this.submittedAt,
  });

  @override
  List<Object?> get props => [
    examId,
    examTitle,
    score,
    maxScore,
    percentage,
    submittedAt,
  ];
}

/// Consolidated academic overview for a child (P-01 / P-03)
class ChildAcademicSummary extends Equatable {
  final String studentId;
  final double attendancePercentage;
  final int totalClasses;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int excusedCount;
  final int examsCount;
  final double examsAverageScore;
  final List<AttendanceEntity> recentAttendance;
  final List<ParentExamResult> recentExams;
  final List<String> enrolledGroups;

  const ChildAcademicSummary({
    required this.studentId,
    required this.attendancePercentage,
    required this.totalClasses,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.excusedCount,
    required this.examsCount,
    required this.examsAverageScore,
    required this.recentAttendance,
    required this.recentExams,
    required this.enrolledGroups,
  });

  @override
  List<Object?> get props => [
    studentId,
    attendancePercentage,
    totalClasses,
    presentCount,
    absentCount,
    lateCount,
    excusedCount,
    examsCount,
    examsAverageScore,
    recentAttendance,
    recentExams,
    enrolledGroups,
  ];
}
