import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/exam_entity.dart';
import '../../domain/entities/exam_folder_entity.dart';
import '../../domain/entities/scratchpad_entity.dart';

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
  final bool hasMoreAttempts;
  final bool isLoadingMoreAttempts;
  final bool isCreating;
  final bool actionSuccess;
  final bool hasMore;
  final bool isLoadingMore;
  final String? message;
  final List<ExamFolderEntity> folders;
  final String? selectedFolderId;

  const TeacherExamsLoaded({
    this.groupId,
    required this.exams,
    this.selectedExam,
    this.attempts = const [],
    this.selectedAttempt,
    this.isLoadingAttempts = false,
    this.hasMoreAttempts = true,
    this.isLoadingMoreAttempts = false,
    this.isCreating = false,
    this.actionSuccess = false,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.message,
    this.folders = const [],
    this.selectedFolderId,
  });

  List<ExamEntity> get filteredExams {
    if (selectedFolderId == null) {
      return exams;
    }
    if (selectedFolderId == 'uncategorized') {
      return exams.where((e) => e.folderId == null || e.folderId!.isEmpty).toList();
    }
    return exams.where((e) => e.folderId == selectedFolderId).toList();
  }

  TeacherExamsLoaded copyWith({
    String? groupId,
    List<ExamEntity>? exams,
    ExamEntity? selectedExam,
    List<ExamAttemptEntity>? attempts,
    ExamAttemptEntity? selectedAttempt,
    bool? isLoadingAttempts,
    bool? hasMoreAttempts,
    bool? isLoadingMoreAttempts,
    bool? isCreating,
    bool? actionSuccess,
    bool? hasMore,
    bool? isLoadingMore,
    String? message,
    List<ExamFolderEntity>? folders,
    String? selectedFolderId,
    bool clearSelectedFolder = false,
  }) {
    return TeacherExamsLoaded(
      groupId: groupId ?? this.groupId,
      exams: exams ?? this.exams,
      selectedExam: selectedExam ?? this.selectedExam,
      attempts: attempts ?? this.attempts,
      selectedAttempt: selectedAttempt ?? this.selectedAttempt,
      isLoadingAttempts: isLoadingAttempts ?? this.isLoadingAttempts,
      hasMoreAttempts: hasMoreAttempts ?? this.hasMoreAttempts,
      isLoadingMoreAttempts:
          isLoadingMoreAttempts ?? this.isLoadingMoreAttempts,
      isCreating: isCreating ?? this.isCreating,
      actionSuccess: actionSuccess ?? this.actionSuccess,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      message: message,
      folders: folders ?? this.folders,
      selectedFolderId: clearSelectedFolder
          ? null
          : (selectedFolderId ?? this.selectedFolderId),
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
    hasMoreAttempts,
    isLoadingMoreAttempts,
    isCreating,
    actionSuccess,
    hasMore,
    isLoadingMore,
    message,
    folders,
    selectedFolderId,
  ];
}

final class StudentExamsLoaded extends ExamsState {
  final List<ExamEntity> exams;
  final ExamEntity? selectedExam;
  final bool hasMore;
  final bool isLoadingMore;
  final String? message;
  final List<ExamFolderEntity> folders;
  final String? selectedFolderId;

  const StudentExamsLoaded({
    required this.exams,
    this.selectedExam,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.message,
    this.folders = const [],
    this.selectedFolderId,
  });

  List<ExamEntity> get filteredExams {
    if (selectedFolderId == null) {
      return exams;
    }
    if (selectedFolderId == 'uncategorized') {
      return exams.where((e) => e.folderId == null || e.folderId!.isEmpty).toList();
    }
    return exams.where((e) => e.folderId == selectedFolderId).toList();
  }

  StudentExamsLoaded copyWith({
    List<ExamEntity>? exams,
    ExamEntity? selectedExam,
    bool? hasMore,
    bool? isLoadingMore,
    String? message,
    List<ExamFolderEntity>? folders,
    String? selectedFolderId,
    bool clearSelectedFolder = false,
  }) {
    return StudentExamsLoaded(
      exams: exams ?? this.exams,
      selectedExam: selectedExam ?? this.selectedExam,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      message: message,
      folders: folders ?? this.folders,
      selectedFolderId: clearSelectedFolder
          ? null
          : (selectedFolderId ?? this.selectedFolderId),
    );
  }

  @override
  List<Object?> get props => [
    exams,
    selectedExam,
    hasMore,
    isLoadingMore,
    message,
    folders,
    selectedFolderId,
  ];
}

final class ExamTakingState extends ExamsState {
  final ExamEntity exam;
  final ExamAttemptEntity attempt;
  final List<ExamQuestionEntity> questions;
  final int currentQuestionIndex;
  final Map<String, String> answers; // questionId -> selectedOptionId
  final Map<String, int> questionTimes; // questionId -> elapsed seconds
  final Set<String> flaggedGuesses; // questionIds flagged as guess/uncertain
  final Map<String, Set<String>> eliminatedOptions; // questionId -> set of eliminated optionIds
  final Map<String, List<DrawingStroke>> questionScratchpads; // questionId -> list of drawn strokes
  final bool isScratchpadOpen;
  final bool isScratchpadGridBackground;
  final DrawingTool activeDrawingTool;
  final Color activeDrawingColor;
  final int remainingSeconds;
  final bool isUntimed;
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
    this.questionTimes = const {},
    this.flaggedGuesses = const {},
    this.eliminatedOptions = const {},
    this.questionScratchpads = const {},
    this.isScratchpadOpen = false,
    this.isScratchpadGridBackground = false,
    this.activeDrawingTool = DrawingTool.pen,
    this.activeDrawingColor = const Color(0xFF1E293B),
    this.remainingSeconds = 0,
    this.isUntimed = false,
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
  bool get isCurrentQuestionFlaggedAsGuess =>
      questions.isNotEmpty &&
      currentQuestionIndex < questions.length &&
      flaggedGuesses.contains(currentQuestion.id);

  bool isOptionEliminated(String questionId, String optionId) =>
      eliminatedOptions[questionId]?.contains(optionId) ?? false;

  bool isQuestionFlagged(String questionId) =>
      flaggedGuesses.contains(questionId);

  List<DrawingStroke> get currentQuestionStrokes =>
      (questions.isNotEmpty && currentQuestionIndex < questions.length)
          ? (questionScratchpads[currentQuestion.id] ?? const [])
          : const [];

  ExamTakingState copyWith({
    ExamEntity? exam,
    ExamAttemptEntity? attempt,
    List<ExamQuestionEntity>? questions,
    int? currentQuestionIndex,
    Map<String, String>? answers,
    Map<String, int>? questionTimes,
    Set<String>? flaggedGuesses,
    Map<String, Set<String>>? eliminatedOptions,
    Map<String, List<DrawingStroke>>? questionScratchpads,
    bool? isScratchpadOpen,
    bool? isScratchpadGridBackground,
    DrawingTool? activeDrawingTool,
    Color? activeDrawingColor,
    int? remainingSeconds,
    bool? isUntimed,
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
      questionTimes: questionTimes ?? this.questionTimes,
      flaggedGuesses: flaggedGuesses ?? this.flaggedGuesses,
      eliminatedOptions: eliminatedOptions ?? this.eliminatedOptions,
      questionScratchpads: questionScratchpads ?? this.questionScratchpads,
      isScratchpadOpen: isScratchpadOpen ?? this.isScratchpadOpen,
      isScratchpadGridBackground:
          isScratchpadGridBackground ?? this.isScratchpadGridBackground,
      activeDrawingTool: activeDrawingTool ?? this.activeDrawingTool,
      activeDrawingColor: activeDrawingColor ?? this.activeDrawingColor,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isUntimed: isUntimed ?? this.isUntimed,
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
    questionTimes,
    flaggedGuesses,
    eliminatedOptions,
    questionScratchpads,
    isScratchpadOpen,
    isScratchpadGridBackground,
    activeDrawingTool,
    activeDrawingColor,
    remainingSeconds,
    isUntimed,
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
