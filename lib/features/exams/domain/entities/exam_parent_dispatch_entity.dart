import 'package:equatable/equatable.dart';

class ExamDispatchMetaEntity extends Equatable {
  final String id;
  final String title;
  final int maxScore;
  final int? passingScore;
  final int durationMinutes;
  final String? primaryGroupName;
  final DateTime? createdAt;

  const ExamDispatchMetaEntity({
    required this.id,
    required this.title,
    required this.maxScore,
    this.passingScore,
    this.durationMinutes = 0,
    this.primaryGroupName,
    this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        maxScore,
        passingScore,
        durationMinutes,
        primaryGroupName,
        createdAt,
      ];
}

class ExamDispatchStatsEntity extends Equatable {
  final int totalAssignedStudents;
  final int submittedCount;
  final int inProgressCount;
  final int notStartedCount;
  final int passedCount;
  final int failedCount;
  final double averageScore;
  final double averagePercentage;
  final int highestScore;
  final int lowestScore;

  const ExamDispatchStatsEntity({
    this.totalAssignedStudents = 0,
    this.submittedCount = 0,
    this.inProgressCount = 0,
    this.notStartedCount = 0,
    this.passedCount = 0,
    this.failedCount = 0,
    this.averageScore = 0.0,
    this.averagePercentage = 0.0,
    this.highestScore = 0,
    this.lowestScore = 0,
  });

  double get submissionRate =>
      totalAssignedStudents > 0 ? (submittedCount / totalAssignedStudents) * 100 : 0.0;

  double get passRate =>
      submittedCount > 0 ? (passedCount / submittedCount) * 100 : 0.0;

  @override
  List<Object?> get props => [
        totalAssignedStudents,
        submittedCount,
        inProgressCount,
        notStartedCount,
        passedCount,
        failedCount,
        averageScore,
        averagePercentage,
        highestScore,
        lowestScore,
      ];
}

class ExamDispatchStudentEntity extends Equatable {
  final String studentId;
  final String studentName;
  final String? studentPhone;
  final String? parentPhone;
  final String? avatarUrl;
  final String groupName;
  final String status; // 'submitted', 'in_progress', 'not_started'
  final int attemptsCount;
  final int? bestScore;
  final double? bestPercentage;
  final DateTime? latestSubmittedAt;
  final String? latestAttemptId;
  final bool isPassed;

  const ExamDispatchStudentEntity({
    required this.studentId,
    required this.studentName,
    this.studentPhone,
    this.parentPhone,
    this.avatarUrl,
    required this.groupName,
    required this.status,
    this.attemptsCount = 0,
    this.bestScore,
    this.bestPercentage,
    this.latestSubmittedAt,
    this.latestAttemptId,
    this.isPassed = false,
  });

  bool get hasParentPhone =>
      parentPhone != null && parentPhone!.trim().isNotEmpty;

  bool get hasStudentPhone =>
      studentPhone != null && studentPhone!.trim().isNotEmpty;

  bool get isSubmitted => status == 'submitted';
  bool get isInProgress => status == 'in_progress';
  bool get isNotStarted => status == 'not_started';

  ExamDispatchStudentEntity copyWith({
    String? studentId,
    String? studentName,
    String? studentPhone,
    String? parentPhone,
    String? avatarUrl,
    String? groupName,
    String? status,
    int? attemptsCount,
    int? bestScore,
    double? bestPercentage,
    DateTime? latestSubmittedAt,
    String? latestAttemptId,
    bool? isPassed,
  }) {
    return ExamDispatchStudentEntity(
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentPhone: studentPhone ?? this.studentPhone,
      parentPhone: parentPhone ?? this.parentPhone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      groupName: groupName ?? this.groupName,
      status: status ?? this.status,
      attemptsCount: attemptsCount ?? this.attemptsCount,
      bestScore: bestScore ?? this.bestScore,
      bestPercentage: bestPercentage ?? this.bestPercentage,
      latestSubmittedAt: latestSubmittedAt ?? this.latestSubmittedAt,
      latestAttemptId: latestAttemptId ?? this.latestAttemptId,
      isPassed: isPassed ?? this.isPassed,
    );
  }

  @override
  List<Object?> get props => [
        studentId,
        studentName,
        studentPhone,
        parentPhone,
        avatarUrl,
        groupName,
        status,
        attemptsCount,
        bestScore,
        bestPercentage,
        latestSubmittedAt,
        latestAttemptId,
        isPassed,
      ];
}

class ExamParentDispatchRosterEntity extends Equatable {
  final ExamDispatchMetaEntity exam;
  final ExamDispatchStatsEntity stats;
  final List<ExamDispatchStudentEntity> students;

  const ExamParentDispatchRosterEntity({
    required this.exam,
    required this.stats,
    required this.students,
  });

  @override
  List<Object?> get props => [exam, stats, students];
}
