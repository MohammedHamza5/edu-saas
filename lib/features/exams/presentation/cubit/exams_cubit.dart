import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/exam_entity.dart';
import '../../domain/repositories/exams_repository.dart';
import 'exams_state.dart';

class ExamsCubit extends Cubit<ExamsState> {
  final ExamsRepository _repository;
  Timer? _countdownTimer;

  ExamsCubit({required ExamsRepository repository})
      : _repository = repository,
        super(const ExamsInitial());

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    return super.close();
  }

  // ── Teacher Flow ─────────────────────────────────────────────────────────

  /// Loads all exams for a specific group (Teacher flow)
  Future<void> loadGroupExams(String groupId) async {
    emit(const ExamsLoading());

    final result = await _repository.getGroupExams(groupId);

    result.when(
      onSuccess: (exams) {
        emit(TeacherExamsLoaded(
          groupId: groupId,
          exams: exams,
        ));
      },
      onFailure: (failure) {
        emit(ExamsError(failure.message));
      },
    );
  }

  /// Selects an exam to view its versions and student attempts (Teacher flow)
  Future<void> selectExamForTeacher(ExamEntity exam) async {
    final currentState = state;
    if (currentState is! TeacherExamsLoaded) return;

    emit(currentState.copyWith(
      selectedExam: exam,
      isLoadingAttempts: true,
    ));

    final result = await _repository.getExamAttempts(exam.id);

    result.when(
      onSuccess: (attempts) {
        emit(currentState.copyWith(
          selectedExam: exam,
          attempts: attempts,
          isLoadingAttempts: false,
        ));
      },
      onFailure: (failure) {
        emit(currentState.copyWith(
          selectedExam: exam,
          isLoadingAttempts: false,
          message: failure.message,
        ));
      },
    );
  }

  /// Creates a new exam with initial questions and version (Teacher flow)
  Future<bool> createExam({
    required String groupId,
    required String title,
    int durationMinutes = 60,
    int maxScore = 100,
    int? passingScore,
    bool shuffleQuestions = false,
    bool showResult = true,
    bool allowRetake = false,
    DateTime? startAt,
    DateTime? endAt,
    required List<ExamQuestionEntity> initialQuestions,
  }) async {
    final currentState = state;
    if (currentState is TeacherExamsLoaded) {
      emit(currentState.copyWith(isCreating: true));
    } else {
      emit(const ExamsLoading());
    }

    final result = await _repository.createExam(
      groupId: groupId,
      title: title,
      durationMinutes: durationMinutes,
      maxScore: maxScore,
      passingScore: passingScore,
      shuffleQuestions: shuffleQuestions,
      showResult: showResult,
      allowRetake: allowRetake,
      startAt: startAt,
      endAt: endAt,
      initialQuestions: initialQuestions,
    );

    return result.when(
      onSuccess: (created) {
        loadGroupExams(groupId);
        return true;
      },
      onFailure: (failure) {
        if (currentState is TeacherExamsLoaded) {
          emit(currentState.copyWith(
            isCreating: false,
            message: failure.message,
          ));
        } else {
          emit(ExamsError(failure.message));
        }
        return false;
      },
    );
  }

  /// Creates a new draft version for an existing exam (Teacher flow)
  Future<bool> createNewVersion(String examId) async {
    final currentState = state;
    if (currentState is! TeacherExamsLoaded) return false;

    final result = await _repository.createNewExamVersion(examId);

    return result.when(
      onSuccess: (_) {
        if (currentState.groupId != null) {
          loadGroupExams(currentState.groupId!);
        }
        return true;
      },
      onFailure: (failure) {
        emit(currentState.copyWith(message: failure.message));
        return false;
      },
    );
  }

  /// Freezes and publishes an exam version (Teacher flow)
  Future<bool> publishVersion(String versionId, String examId) async {
    final currentState = state;
    if (currentState is! TeacherExamsLoaded) return false;

    final result = await _repository.publishExamVersion(versionId);

    return result.when(
      onSuccess: (_) {
        if (currentState.groupId != null) {
          loadGroupExams(currentState.groupId!);
        }
        return true;
      },
      onFailure: (failure) {
        emit(currentState.copyWith(message: failure.message));
        return false;
      },
    );
  }

  // ── Student Flow ─────────────────────────────────────────────────────────

  /// Loads all exams available for the currently logged-in student (Student flow)
  Future<void> loadStudentExams() async {
    emit(const ExamsLoading());

    final result = await _repository.getStudentExams();

    result.when(
      onSuccess: (exams) {
        if (exams.isEmpty) {
          emit(const ExamsEmpty(message: 'لا توجد امتحانات متاحة حالياً'));
        } else {
          emit(StudentExamsLoaded(exams: exams));
        }
      },
      onFailure: (failure) {
        emit(ExamsError(failure.message));
      },
    );
  }

  /// Starts or resumes an exam attempt for the student (Student taking environment)
  Future<bool> startExamTaking(ExamEntity exam) async {
    emit(const ExamsLoading());

    // 1. Fetch full details to ensure we have questions
    final detailsRes = await _repository.getExamDetails(exam.id);
    final fullExam = detailsRes.when(
      onSuccess: (e) => e,
      onFailure: (_) => exam,
    );

    // 2. Start attempt via RPC
    final attemptRes = await _repository.startExam(exam.id);

    return attemptRes.when(
      onSuccess: (attempt) {
        final questions = fullExam.activeVersion?.questions ?? <ExamQuestionEntity>[];

        // Calculate remaining seconds
        final elapsedSeconds =
            DateTime.now().difference(attempt.startedAt).inSeconds;
        final totalSeconds = fullExam.durationMinutes * 60;
        final remaining = totalSeconds - elapsedSeconds;

        emit(ExamTakingState(
          exam: fullExam,
          attempt: attempt,
          questions: questions,
          remainingSeconds: remaining > 0 ? remaining : 0,
        ));

        _startTimer();
        return true;
      },
      onFailure: (failure) {
        emit(ExamsError(failure.message));
        return false;
      },
    );
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final currentState = state;
      if (currentState is! ExamTakingState) {
        timer.cancel();
        return;
      }

      if (currentState.remainingSeconds <= 1) {
        timer.cancel();
        emit(currentState.copyWith(
          remainingSeconds: 0,
          isExpired: true,
        ));
        submitExam();
      } else {
        emit(currentState.copyWith(
          remainingSeconds: currentState.remainingSeconds - 1,
        ));
      }
    });
  }

  /// Selects an answer option for the current question
  void selectAnswer(String questionId, String optionId) {
    final currentState = state;
    if (currentState is! ExamTakingState) return;

    final updatedAnswers = Map<String, String>.from(currentState.answers);
    updatedAnswers[questionId] = optionId;

    emit(currentState.copyWith(answers: updatedAnswers));
  }

  /// Navigates to a specific question index
  void goToQuestion(int index) {
    final currentState = state;
    if (currentState is! ExamTakingState) return;
    if (index >= 0 && index < currentState.questions.length) {
      emit(currentState.copyWith(currentQuestionIndex: index));
    }
  }

  /// Submits the exam answers atomically to the server
  Future<bool> submitExam() async {
    final currentState = state;
    if (currentState is! ExamTakingState) return false;

    _countdownTimer?.cancel();
    emit(currentState.copyWith(isSubmitting: true));

    final result = await _repository.submitExam(
      attemptId: currentState.attempt.id,
      answers: currentState.answers,
    );

    return result.when(
      onSuccess: (submitResult) {
        emit(currentState.copyWith(
          isSubmitting: false,
          submitSuccess: true,
          submitResult: submitResult,
        ));
        return true;
      },
      onFailure: (failure) {
        emit(currentState.copyWith(
          isSubmitting: false,
          errorMessage: failure.message,
        ));
        return false;
      },
    );
  }
}
