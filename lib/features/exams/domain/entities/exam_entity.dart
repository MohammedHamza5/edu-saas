import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

enum QuestionType {
  multipleChoice,
  trueFalse;

  static QuestionType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'true_false':
        return QuestionType.trueFalse;
      case 'multiple_choice':
      default:
        return QuestionType.multipleChoice;
    }
  }

  String get value {
    switch (this) {
      case QuestionType.multipleChoice:
        return 'multiple_choice';
      case QuestionType.trueFalse:
        return 'true_false';
    }
  }

  String get labelAr {
    switch (this) {
      case QuestionType.multipleChoice:
        return 'اختيار من متعدد';
      case QuestionType.trueFalse:
        return 'صواب أو خطأ';
    }
  }
}

enum ExamStatus {
  draft,
  published,
  archived;

  static ExamStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'published':
        return ExamStatus.published;
      case 'archived':
        return ExamStatus.archived;
      case 'draft':
      default:
        return ExamStatus.draft;
    }
  }

  String get value => name;

  String get labelAr {
    switch (this) {
      case ExamStatus.draft:
        return 'مسودة';
      case ExamStatus.published:
        return 'منشور (مجمد)';
      case ExamStatus.archived:
        return 'مؤرشف';
    }
  }

  Color get color {
    switch (this) {
      case ExamStatus.draft:
        return AppColors.warning;
      case ExamStatus.published:
        return AppColors.success;
      case ExamStatus.archived:
        return AppColors.textMuted;
    }
  }
}

enum AttemptStatus {
  inProgress,
  submitted,
  expired;

  static AttemptStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'submitted':
        return AttemptStatus.submitted;
      case 'expired':
        return AttemptStatus.expired;
      case 'in_progress':
      default:
        return AttemptStatus.inProgress;
    }
  }

  String get value {
    switch (this) {
      case AttemptStatus.inProgress:
        return 'in_progress';
      case AttemptStatus.submitted:
        return 'submitted';
      case AttemptStatus.expired:
        return 'expired';
    }
  }

  String get labelAr {
    switch (this) {
      case AttemptStatus.inProgress:
        return 'قيد الأداء';
      case AttemptStatus.submitted:
        return 'تم التسليم';
      case AttemptStatus.expired:
        return 'انتهى الوقت';
    }
  }

  Color get color {
    switch (this) {
      case AttemptStatus.inProgress:
        return AppColors.primary;
      case AttemptStatus.submitted:
        return AppColors.success;
      case AttemptStatus.expired:
        return AppColors.error;
    }
  }
}

class QuestionOptionEntity extends Equatable {
  final String id;
  final String questionId;
  final String optionText;
  final int sortOrder;
  final bool? isCorrect; // Hidden from student responses

  const QuestionOptionEntity({
    required this.id,
    required this.questionId,
    required this.optionText,
    this.sortOrder = 0,
    this.isCorrect,
  });

  QuestionOptionEntity copyWith({
    String? id,
    String? questionId,
    String? optionText,
    int? sortOrder,
    bool? isCorrect,
  }) {
    return QuestionOptionEntity(
      id: id ?? this.id,
      questionId: questionId ?? this.questionId,
      optionText: optionText ?? this.optionText,
      sortOrder: sortOrder ?? this.sortOrder,
      isCorrect: isCorrect ?? this.isCorrect,
    );
  }

  @override
  List<Object?> get props => [id, questionId, optionText, sortOrder, isCorrect];
}

class ExamQuestionEntity extends Equatable {
  final String id;
  final String examVersionId;
  final String questionText;
  final QuestionType questionType;
  final int points;
  final int sortOrder;
  final List<QuestionOptionEntity> options;

  const ExamQuestionEntity({
    required this.id,
    required this.examVersionId,
    required this.questionText,
    this.questionType = QuestionType.multipleChoice,
    this.points = 1,
    this.sortOrder = 0,
    this.options = const [],
  });

  ExamQuestionEntity copyWith({
    String? id,
    String? examVersionId,
    String? questionText,
    QuestionType? questionType,
    int? points,
    int? sortOrder,
    List<QuestionOptionEntity>? options,
  }) {
    return ExamQuestionEntity(
      id: id ?? this.id,
      examVersionId: examVersionId ?? this.examVersionId,
      questionText: questionText ?? this.questionText,
      questionType: questionType ?? this.questionType,
      points: points ?? this.points,
      sortOrder: sortOrder ?? this.sortOrder,
      options: options ?? this.options,
    );
  }

  @override
  List<Object?> get props => [
        id,
        examVersionId,
        questionText,
        questionType,
        points,
        sortOrder,
        options,
      ];
}

class ExamVersionEntity extends Equatable {
  final String id;
  final String examId;
  final int versionNumber;
  final ExamStatus status;
  final DateTime createdAt;
  final DateTime? publishedAt;
  final List<ExamQuestionEntity> questions;

  const ExamVersionEntity({
    required this.id,
    required this.examId,
    this.versionNumber = 1,
    this.status = ExamStatus.draft,
    required this.createdAt,
    this.publishedAt,
    this.questions = const [],
  });

  bool get isPublished => status == ExamStatus.published;
  bool get isDraft => status == ExamStatus.draft;

  int get totalPoints => questions.fold(0, (sum, q) => sum + q.points);

  ExamVersionEntity copyWith({
    String? id,
    String? examId,
    int? versionNumber,
    ExamStatus? status,
    DateTime? createdAt,
    DateTime? publishedAt,
    List<ExamQuestionEntity>? questions,
  }) {
    return ExamVersionEntity(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      versionNumber: versionNumber ?? this.versionNumber,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      publishedAt: publishedAt ?? this.publishedAt,
      questions: questions ?? this.questions,
    );
  }

  @override
  List<Object?> get props => [
        id,
        examId,
        versionNumber,
        status,
        createdAt,
        publishedAt,
        questions,
      ];
}

class ExamAnswerEntity extends Equatable {
  final String id;
  final String attemptId;
  final String questionId;
  final String? selectedOptionId;
  final bool? isCorrect;
  final double? pointsEarned;
  final DateTime answeredAt;

  const ExamAnswerEntity({
    required this.id,
    required this.attemptId,
    required this.questionId,
    this.selectedOptionId,
    this.isCorrect,
    this.pointsEarned,
    required this.answeredAt,
  });

  @override
  List<Object?> get props => [
        id,
        attemptId,
        questionId,
        selectedOptionId,
        isCorrect,
        pointsEarned,
        answeredAt,
      ];
}

class ExamAttemptEntity extends Equatable {
  final String id;
  final String examId;
  final String examVersionId;
  final String studentId;
  final String? studentName;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final AttemptStatus status;
  final int? score;
  final double? percentage;
  final List<ExamAnswerEntity> answers;

  const ExamAttemptEntity({
    required this.id,
    required this.examId,
    required this.examVersionId,
    required this.studentId,
    this.studentName,
    required this.startedAt,
    this.submittedAt,
    this.status = AttemptStatus.inProgress,
    this.score,
    this.percentage,
    this.answers = const [],
  });

  bool get isInProgress => status == AttemptStatus.inProgress;
  bool get isSubmitted => status == AttemptStatus.submitted;
  bool get isExpired => status == AttemptStatus.expired;

  bool isPassed(int? passingScore) {
    if (passingScore == null || score == null) return true;
    return score! >= passingScore;
  }

  ExamAttemptEntity copyWith({
    String? id,
    String? examId,
    String? examVersionId,
    String? studentId,
    String? studentName,
    DateTime? startedAt,
    DateTime? submittedAt,
    AttemptStatus? status,
    int? score,
    double? percentage,
    List<ExamAnswerEntity>? answers,
  }) {
    return ExamAttemptEntity(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      examVersionId: examVersionId ?? this.examVersionId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      startedAt: startedAt ?? this.startedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      status: status ?? this.status,
      score: score ?? this.score,
      percentage: percentage ?? this.percentage,
      answers: answers ?? this.answers,
    );
  }

  @override
  List<Object?> get props => [
        id,
        examId,
        examVersionId,
        studentId,
        studentName,
        startedAt,
        submittedAt,
        status,
        score,
        percentage,
        answers,
      ];
}

class ExamEntity extends Equatable {
  final String id;
  final String contentId;
  final String tenantId;
  final String groupId;
  final String? groupName;
  final String title;
  final int durationMinutes;
  final int maxScore;
  final int? passingScore;
  final bool shuffleQuestions;
  final bool showResult;
  final bool allowRetake;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ExamVersionEntity? activeVersion;
  final int attemptsCount;
  final ExamAttemptEntity? myLatestAttempt;
  final int? myBestScore;

  const ExamEntity({
    required this.id,
    required this.contentId,
    required this.tenantId,
    required this.groupId,
    this.groupName,
    required this.title,
    this.durationMinutes = 60,
    this.maxScore = 100,
    this.passingScore,
    this.shuffleQuestions = false,
    this.showResult = true,
    this.allowRetake = false,
    this.startAt,
    this.endAt,
    required this.createdAt,
    required this.updatedAt,
    this.activeVersion,
    this.attemptsCount = 0,
    this.myLatestAttempt,
    this.myBestScore,
  });

  bool get hasAttempted => myLatestAttempt != null;
  bool get hasActiveAttempt => myLatestAttempt?.isInProgress ?? false;
  bool get canTakeExam {
    if (!hasAttempted) return true;
    if (hasActiveAttempt) return true; // Resume
    return allowRetake;
  }

  ExamEntity copyWith({
    String? id,
    String? contentId,
    String? tenantId,
    String? groupId,
    String? groupName,
    String? title,
    int? durationMinutes,
    int? maxScore,
    int? passingScore,
    bool? shuffleQuestions,
    bool? showResult,
    bool? allowRetake,
    DateTime? startAt,
    DateTime? endAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    ExamVersionEntity? activeVersion,
    int? attemptsCount,
    ExamAttemptEntity? myLatestAttempt,
    int? myBestScore,
  }) {
    return ExamEntity(
      id: id ?? this.id,
      contentId: contentId ?? this.contentId,
      tenantId: tenantId ?? this.tenantId,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      title: title ?? this.title,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      maxScore: maxScore ?? this.maxScore,
      passingScore: passingScore ?? this.passingScore,
      shuffleQuestions: shuffleQuestions ?? this.shuffleQuestions,
      showResult: showResult ?? this.showResult,
      allowRetake: allowRetake ?? this.allowRetake,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      activeVersion: activeVersion ?? this.activeVersion,
      attemptsCount: attemptsCount ?? this.attemptsCount,
      myLatestAttempt: myLatestAttempt ?? this.myLatestAttempt,
      myBestScore: myBestScore ?? this.myBestScore,
    );
  }

  @override
  List<Object?> get props => [
        id,
        contentId,
        tenantId,
        groupId,
        groupName,
        title,
        durationMinutes,
        maxScore,
        passingScore,
        shuffleQuestions,
        showResult,
        allowRetake,
        startAt,
        endAt,
        createdAt,
        updatedAt,
        activeVersion,
        attemptsCount,
        myLatestAttempt,
        myBestScore,
      ];
}
