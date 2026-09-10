import '../../domain/entities/exam_entity.dart';

class ExamAttemptModel extends ExamAttemptEntity {
  const ExamAttemptModel({
    required super.id,
    required super.examId,
    required super.examVersionId,
    required super.studentId,
    super.studentName,
    required super.startedAt,
    super.submittedAt,
    super.status,
    super.score,
    super.percentage,
    super.answers,
  });

  factory ExamAttemptModel.fromJson(Map<String, dynamic> json) {
    String? studentName;
    if (json['users'] is Map<String, dynamic>) {
      studentName = (json['users'] as Map<String, dynamic>)['full_name'] as String?;
    } else if (json['student_name'] != null) {
      studentName = json['student_name'] as String?;
    }

    final rawAnswers = json['answers'] ?? json['exam_answers'];
    final answersList = (rawAnswers as List<dynamic>?)?.map((a) {
          final aMap = a as Map<String, dynamic>;
          return ExamAnswerEntity(
            id: aMap['id'] as String? ?? '',
            attemptId: aMap['attempt_id'] as String? ?? '',
            questionId: aMap['question_id'] as String? ?? '',
            selectedOptionId: aMap['selected_option_id'] as String?,
            isCorrect: aMap['is_correct'] as bool?,
            pointsEarned: (aMap['points_earned'] as num?)?.toDouble(),
            answeredAt: aMap['answered_at'] != null
                ? DateTime.parse(aMap['answered_at'] as String)
                : DateTime.now(),
          );
        }).toList() ??
        <ExamAnswerEntity>[];

    return ExamAttemptModel(
      id: json['id'] as String,
      examId: json['exam_id'] as String,
      examVersionId: json['exam_version_id'] as String? ?? '',
      studentId: json['student_id'] as String,
      studentName: studentName,
      startedAt: DateTime.parse(json['started_at'] as String),
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : null,
      status: AttemptStatus.fromString(json['status'] as String? ?? 'in_progress'),
      score: (json['score'] as num?)?.toInt(),
      percentage: (json['percentage'] as num?)?.toDouble(),
      answers: answersList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exam_id': examId,
      'exam_version_id': examVersionId,
      'student_id': studentId,
      'started_at': startedAt.toIso8601String(),
      if (submittedAt != null) 'submitted_at': submittedAt!.toIso8601String(),
      'status': status.value,
      if (score != null) 'score': score,
      if (percentage != null) 'percentage': percentage,
    };
  }
}
