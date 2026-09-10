import 'package:equatable/equatable.dart';
import '../../domain/entities/exam_entity.dart';

sealed class ExamsState extends Equatable {
  const ExamsState();

  @override
  List<Object?> get props => [];
}

final class ExamsInitial extends ExamsState {
  const ExamsInitial();
}

final class ExamsLoading extends ExamsState {
  const ExamsLoading();
}

final class ExamsEmpty extends ExamsState {
  final String message;
  const ExamsEmpty({this.message = 'لا توجد امتحانات حالياً'});

  @override
  List<Object?> get props => [message];
}

final class TeacherExamsLoaded extends ExamsState {
  final String? groupId;
  final List<ExamEntity> exams;
  final ExamEntity? selectedExam;
  final List<ExamAttemptEntity> attempts;
  final ExamAttemptEntity? selectedAttempt;
  final bool isLoadingAttempts;
  final bool isCreating;
  final bool actionSuccess;
  final String? message;

  const TeacherExamsLoaded({
    this.groupId,
    required this.exams,
    this.selectedExam,
    this.attempts = const [],
    this.selectedAttempt,
    this.isLoadingAttempts = false,
    this.isCreating = false,
    this.actionSuccess = false,
    this.message,
  });

  TeacherExamsLoaded copyWith({
    String? groupId,
    List<ExamEntity>? exams,
    ExamEntity? selectedExam,
    List<ExamAttemptEntity>? attempts,
    ExamAttemptEntity? selectedAttempt,
    bool? isLoadingAttempts,
    bool? isCreating,
    bool? actionSuccess,
    String? message,
  }) {
    return TeacherExamsLoaded(
      groupId: groupId ?? this.groupId,
      exams: exams ?? this.exams,
      selectedExam: selectedExam ?? this.selectedExam,
      attempts: attempts ?? this.attempts,
      selectedAttempt: selectedAttempt ?? this.selectedAttempt,
      isLoadingAttempts: isLoadingAttempts ?? this.isLoadingAttempts,
      isCreating: isCreating ?? this.isCreating,
      actionSuccess: actionSuccess ?? this.actionSuccess,
      message: message,
    );
  }

  @override
  List<Object?> get props => [
        groupId,
        exams,
        selectedExam,
        attempts,
        selectedAttempt,
        isLoadingAttempts,
        isCreating,
        actionSuccess,
        message,
      ];
}

final class StudentExamsLoaded extends ExamsState {
  final List<ExamEntity> exams;
  final ExamEntity? selectedExam;
  final String? message;

  const StudentExamsLoaded({
    required this.exams,
    this.selectedExam,
    this.message,
  });

  StudentExamsLoaded copyWith({
    List<ExamEntity>? exams,
    ExamEntity? selectedExam,
    String? message,
  }) {
    return StudentExamsLoaded(
      exams: exams ?? this.exams,
      selectedExam: selectedExam ?? this.selectedExam,
      message: message,
    );
  }

  @override
  List<Object?> get props => [exams, selectedExam, message];
}

final class ExamTakingState extends ExamsState {
  final ExamEntity exam;
  final ExamAttemptEntity attempt;
  final List<ExamQuestionEntity> questions;
  final int currentQuestionIndex;
  final Map<String, String> answers; // questionId -> selectedOptionId
  final int remainingSeconds;
  final bool isSubmitting;
  final bool isExpired;
  final bool submitSuccess;
  final ExamAttemptEntity? submitResult;
  final String? errorMessage;

  const ExamTakingState({
    required this.exam,
    required this.attempt,
    required this.questions,
    this.currentQuestionIndex = 0,
    this.answers = const {},
    this.remainingSeconds = 0,
    this.isSubmitting = false,
    this.isExpired = false,
    this.submitSuccess = false,
    this.submitResult,
    this.errorMessage,
  });

  ExamQuestionEntity get currentQuestion => questions[currentQuestionIndex];
  bool get hasNext => currentQuestionIndex < questions.length - 1;
  bool get hasPrevious => currentQuestionIndex > 0;
  int get answeredCount => answers.length;
  int get totalQuestions => questions.length;

  ExamTakingState copyWith({
    ExamEntity? exam,
    ExamAttemptEntity? attempt,
    List<ExamQuestionEntity>? questions,
    int? currentQuestionIndex,
    Map<String, String>? answers,
    int? remainingSeconds,
    bool? isSubmitting,
    bool? isExpired,
    bool? submitSuccess,
    ExamAttemptEntity? submitResult,
    String? errorMessage,
  }) {
    return ExamTakingState(
      exam: exam ?? this.exam,
      attempt: attempt ?? this.attempt,
      questions: questions ?? this.questions,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      answers: answers ?? this.answers,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isExpired: isExpired ?? this.isExpired,
      submitSuccess: submitSuccess ?? this.submitSuccess,
      submitResult: submitResult ?? this.submitResult,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        exam,
        attempt,
        questions,
        currentQuestionIndex,
        answers,
        remainingSeconds,
        isSubmitting,
        isExpired,
        submitSuccess,
        submitResult,
        errorMessage,
      ];
}

final class ExamsError extends ExamsState {
  final String message;
  const ExamsError(this.message);

  @override
  List<Object?> get props => [message];
}
