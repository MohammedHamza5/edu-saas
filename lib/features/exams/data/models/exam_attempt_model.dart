import '../../domain/entities/exam_entity.dart';
import 'exam_question_model.dart';

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
    super.submissionReason,
    super.score,
    super.percentage,
    super.remainingSeconds,
    super.answeredQuestionsCount,
    super.answers,
    super.questions,
  });

  factory ExamAttemptModel.fromJson(Map<String, dynamic> json) {
    String? studentName;
    if (json['users'] is Map) {
      studentName =
          (json['users'] as Map)['full_name']?.toString();
    } else if (json['student_name'] != null) {
      studentName = json['student_name']?.toString();
    }

    final rawAnswers = json['answers'] ?? json['exam_answers'];
    final answersList =
        (rawAnswers as List<dynamic>?)
            ?.whereType<Map<dynamic, dynamic>>()
            .map((a) {
              final aMap = Map<String, dynamic>.from(a);
              return ExamAnswerEntity(
                id: aMap['id']?.toString() ?? '',
                attemptId: aMap['attempt_id']?.toString() ?? '',
                questionId: aMap['question_id']?.toString() ?? '',
                selectedOptionId: aMap['selected_option_id']?.toString(),
                isCorrect: aMap['is_correct'] as bool?,
                pointsEarned: (aMap['points_earned'] as num?)?.toDouble(),
                answeredAt: aMap['answered_at'] != null
                    ? DateTime.tryParse(aMap['answered_at'].toString())?.toUtc() ?? DateTime.now().toUtc()
                    : DateTime.now().toUtc(),
              );
            }).toList() ??
        <ExamAnswerEntity>[];

    final rawQuestions = json['questions'] as List<dynamic>?;
    final questionsList =
        rawQuestions
            ?.whereType<Map<dynamic, dynamic>>()
            .where((q) => q['id'] != null)
            .map((q) {
              return ExamQuestionModel.fromJson(
                Map<String, dynamic>.from(q),
              );
            }).toList() ??
        <ExamQuestionEntity>[];

    int? answeredQuestionsCount;
    if (json['answered_questions_count'] != null) {
      answeredQuestionsCount =
          (json['answered_questions_count'] as num).toInt();
    } else if (answersList.isNotEmpty) {
      answeredQuestionsCount =
          answersList.where((a) => a.selectedOptionId != null).length;
    }

    return ExamAttemptModel(
      id: json['id']?.toString() ?? '',
      examId: json['exam_id']?.toString() ?? '',
      examVersionId: json['exam_version_id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      studentName: studentName,
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'].toString())?.toUtc() ?? DateTime.now().toUtc()
          : DateTime.now().toUtc(),
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'].toString())?.toUtc()
          : null,
      status: AttemptStatus.fromString(
        json['status'] as String? ?? 'in_progress',
      ),
      submissionReason: ExamSubmissionReason.fromString(
        json['submission_reason'] as String?,
      ),
      score: (json['score'] as num?)?.toInt(),
      percentage: (json['percentage'] as num?)?.toDouble(),
      remainingSeconds: (json['remaining_seconds'] as num?)?.toInt(),
      answeredQuestionsCount: answeredQuestionsCount,
      answers: answersList,
      questions: questionsList,
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
      'submission_reason': submissionReason.value,
      if (score != null) 'score': score,
      if (percentage != null) 'percentage': percentage,
    };
  }
}
