import '../../domain/entities/exam_parent_dispatch_entity.dart';

class ExamDispatchMetaModel extends ExamDispatchMetaEntity {
  const ExamDispatchMetaModel({
    required super.id,
    required super.title,
    required super.maxScore,
    super.passingScore,
    super.durationMinutes,
    super.primaryGroupName,
    super.createdAt,
  });

  factory ExamDispatchMetaModel.fromJson(Map<String, dynamic> json) {
    return ExamDispatchMetaModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      maxScore: (json['max_score'] as num?)?.toInt() ?? 100,
      passingScore: (json['passing_score'] as num?)?.toInt(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      primaryGroupName: json['primary_group_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

class ExamDispatchStatsModel extends ExamDispatchStatsEntity {
  const ExamDispatchStatsModel({
    super.totalAssignedStudents,
    super.submittedCount,
    super.inProgressCount,
    super.notStartedCount,
    super.passedCount,
    super.failedCount,
    super.averageScore,
    super.averagePercentage,
    super.highestScore,
    super.lowestScore,
  });

  factory ExamDispatchStatsModel.fromJson(Map<String, dynamic> json) {
    return ExamDispatchStatsModel(
      totalAssignedStudents:
          (json['total_assigned_students'] as num?)?.toInt() ?? 0,
      submittedCount: (json['submitted_count'] as num?)?.toInt() ?? 0,
      inProgressCount: (json['in_progress_count'] as num?)?.toInt() ?? 0,
      notStartedCount: (json['not_started_count'] as num?)?.toInt() ?? 0,
      passedCount: (json['passed_count'] as num?)?.toInt() ?? 0,
      failedCount: (json['failed_count'] as num?)?.toInt() ?? 0,
      averageScore: (json['average_score'] as num?)?.toDouble() ?? 0.0,
      averagePercentage: (json['average_percentage'] as num?)?.toDouble() ?? 0.0,
      highestScore: (json['highest_score'] as num?)?.toInt() ?? 0,
      lowestScore: (json['lowest_score'] as num?)?.toInt() ?? 0,
    );
  }
}

class ExamDispatchAttemptModel extends ExamDispatchAttemptEntity {
  const ExamDispatchAttemptModel({
    required super.id,
    required super.attemptNumber,
    super.score,
    required super.maxScore,
    super.percentage,
    required super.status,
    super.submissionReason,
    required super.startedAt,
    super.submittedAt,
    super.isPassed,
  });

  factory ExamDispatchAttemptModel.fromJson(Map<String, dynamic> json) {
    return ExamDispatchAttemptModel(
      id: json['id'] as String? ?? '',
      attemptNumber: (json['attempt_number'] as num?)?.toInt() ?? 1,
      score: (json['score'] as num?)?.toInt(),
      maxScore: (json['max_score'] as num?)?.toInt() ?? 100,
      percentage: (json['percentage'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'submitted',
      submissionReason: json['submission_reason'] as String? ?? 'student_submitted',
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'].toString())
          : null,
      isPassed: json['is_passed'] as bool? ?? false,
    );
  }
}

class ExamDispatchStudentModel extends ExamDispatchStudentEntity {
  const ExamDispatchStudentModel({
    required super.studentId,
    required super.studentName,
    super.studentPhone,
    super.parentPhone,
    super.avatarUrl,
    required super.groupName,
    required super.status,
    super.attemptsCount,
    super.bestScore,
    super.bestPercentage,
    super.latestSubmittedAt,
    super.latestAttemptId,
    super.isPassed,
    super.attempts,
  });

  factory ExamDispatchStudentModel.fromJson(Map<String, dynamic> json) {
    final attemptsJson = json['attempts'] as List<dynamic>? ?? [];
    final attemptsList = attemptsJson
        .map((a) => ExamDispatchAttemptModel.fromJson(a as Map<String, dynamic>))
        .toList();

    return ExamDispatchStudentModel(
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      studentPhone: json['student_phone'] as String?,
      parentPhone: json['parent_phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      groupName: json['group_name'] as String? ?? 'عام',
      status: json['status'] as String? ?? 'not_started',
      attemptsCount: (json['attempts_count'] as num?)?.toInt() ?? attemptsList.length,
      bestScore: (json['best_score'] as num?)?.toInt(),
      bestPercentage: (json['best_percentage'] as num?)?.toDouble(),
      latestSubmittedAt: json['latest_submitted_at'] != null
          ? DateTime.tryParse(json['latest_submitted_at'].toString())
          : null,
      latestAttemptId: json['latest_attempt_id'] as String?,
      isPassed: json['is_passed'] as bool? ?? false,
      attempts: attemptsList,
    );
  }
}

class ExamParentDispatchRosterModel extends ExamParentDispatchRosterEntity {
  const ExamParentDispatchRosterModel({
    required super.exam,
    required super.stats,
    required super.students,
  });

  factory ExamParentDispatchRosterModel.fromJson(Map<String, dynamic> json) {
    final examMap = json['exam'] as Map<String, dynamic>? ?? {};
    final statsMap = json['stats'] as Map<String, dynamic>? ?? {};
    final studentsList = (json['students'] as List<dynamic>? ?? [])
        .map((s) => ExamDispatchStudentModel.fromJson(s as Map<String, dynamic>))
        .toList();

    return ExamParentDispatchRosterModel(
      exam: ExamDispatchMetaModel.fromJson(examMap),
      stats: ExamDispatchStatsModel.fromJson(statsMap),
      students: studentsList,
    );
  }
}
