import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/cache_manager.dart';
import '../../domain/entities/exam_entity.dart';
import '../../domain/repositories/exams_repository.dart';
import 'exams_state.dart';

class ExamsCubit extends Cubit<ExamsState> {
  final ExamsRepository _repository;
  Timer? _countdownTimer;

  static const int _pageSize = 15;
  int _teacherPage = 0;
  int _studentPage = 0;

  ExamsCubit({required ExamsRepository repository})
      : _repository = repository,
        super(const ExamsInitial());

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    return super.close();
  }

  // ── Teacher Flow ─────────────────────────────────────────────────────────

  /// Loads all exams for a specific group (Teacher flow) with instant SWR cache
  Future<void> loadGroupExams(String groupId, {bool forceRefresh = false}) async {
    if (state is ExamTakingState) return;

    _teacherPage = 0;
    final cacheKey = 'teacher_exams_$groupId';
    if (forceRefresh) {
      AppCache.exams.invalidate(cacheKey);
    }

    // ── Stale-While-Revalidate: Instant display from memory cache ──────────
    final cached = AppCache.exams.getStale(cacheKey);
    if (cached is List<ExamEntity>) {
      emit(TeacherExamsLoaded(
        groupId: groupId,
        exams: cached,
        hasMore: cached.length >= _pageSize,
      ));
      if (!forceRefresh && AppCache.exams.has(cacheKey)) return; // Fresh cache, skip network
    } else {
      emit(const ExamsLoading());
    }

    final result = await _repository.getGroupExams(
      groupId,
      page: 0,
      pageSize: _pageSize,
    );

    result.when(
      onSuccess: (exams) {
        AppCache.exams.put(cacheKey, exams);
        emit(TeacherExamsLoaded(
          groupId: groupId,
          exams: exams,
          hasMore: exams.length == _pageSize,
          isLoadingMore: false,
        ));
      },
      onFailure: (failure) {
        if (state is! TeacherExamsLoaded) {
          emit(ExamsError(failure.message));
        }
      },
    );
  }

  /// Loads next page of teacher exams on scroll (Infinite Scroll)
  Future<void> loadMoreTeacherExams() async {
    final currentState = state;
    if (currentState is! TeacherExamsLoaded) return;
    if (!currentState.hasMore || currentState.isLoadingMore || currentState.groupId == null) return;

    emit(currentState.copyWith(isLoadingMore: true));
    final nextPage = _teacherPage + 1;

    final result = await _repository.getGroupExams(
      currentState.groupId!,
      page: nextPage,
      pageSize: _pageSize,
    );

    if (isClosed) return;

    result.when(
      onSuccess: (newExams) {
        _teacherPage = nextPage;
        final allExams = [...currentState.exams, ...newExams];
        AppCache.exams.put('teacher_exams_${currentState.groupId}', allExams);
        emit(currentState.copyWith(
          exams: allExams,
          hasMore: newExams.length == _pageSize,
          isLoadingMore: false,
        ));
      },
      onFailure: (failure) {
        emit(currentState.copyWith(isLoadingMore: false));
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
  Future<ExamEntity?> createExam({
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
        AppCache.exams.invalidate('teacher_exams_$groupId');
        loadGroupExams(groupId, forceRefresh: true);
        return created;
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
        return null;
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
          AppCache.exams.invalidate('teacher_exams_${currentState.groupId}');
          loadGroupExams(currentState.groupId!, forceRefresh: true);
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
          AppCache.exams.invalidate('teacher_exams_${currentState.groupId}');
          loadGroupExams(currentState.groupId!, forceRefresh: true);
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

  /// Loads all exams available for the currently logged-in student (Student flow) with instant SWR cache
  Future<void> loadStudentExams({bool forceRefresh = false}) async {
    // Critical Guard: Never overwrite or interrupt an active exam taking session!
    if (state is ExamTakingState) {
      AppLogger.w('ExamsCubit', 'Ignored loadStudentExams while exam is actively in progress');
      return;
    }

    _studentPage = 0;
    const cacheKey = 'student_exams_all';
    if (forceRefresh) {
      AppCache.exams.invalidate(cacheKey);
    }

    // ── Stale-While-Revalidate: Instant display from memory cache ──────────
    final cached = AppCache.exams.getStale(cacheKey);
    if (cached is List<ExamEntity>) {
      if (cached.isEmpty) {
        emit(const ExamsEmpty(message: 'لا توجد امتحانات متاحة حالياً'));
      } else {
        emit(StudentExamsLoaded(
          exams: cached,
          hasMore: cached.length >= _pageSize,
        ));
      }
      if (!forceRefresh && AppCache.exams.has(cacheKey)) return; // Fresh cache, skip network
    } else {
      emit(const ExamsLoading());
    }

    final result = await _repository.getStudentExams(
      page: 0,
      pageSize: _pageSize,
    );

    result.when(
      onSuccess: (exams) {
        // Double check state hasn't transitioned to ExamTakingState while waiting for network
        if (state is ExamTakingState) return;

        AppCache.exams.put(cacheKey, exams);
        if (exams.isEmpty) {
          emit(const ExamsEmpty(message: 'لا توجد امتحانات متاحة حالياً'));
        } else {
          emit(StudentExamsLoaded(
            exams: exams,
            hasMore: exams.length == _pageSize,
            isLoadingMore: false,
          ));
        }
      },
      onFailure: (failure) {
        if (state is! StudentExamsLoaded && state is! ExamTakingState) {
          emit(ExamsError(failure.message));
        }
      },
    );
  }

  /// Loads next page of student exams on scroll (Infinite Scroll)
  Future<void> loadMoreStudentExams() async {
    final currentState = state;
    if (currentState is! StudentExamsLoaded) return;
    if (!currentState.hasMore || currentState.isLoadingMore) return;

    emit(currentState.copyWith(isLoadingMore: true));
    final nextPage = _studentPage + 1;

    final result = await _repository.getStudentExams(
      page: nextPage,
      pageSize: _pageSize,
    );

    if (isClosed) return;

    result.when(
      onSuccess: (newExams) {
        _studentPage = nextPage;
        final allExams = [...currentState.exams, ...newExams];
        AppCache.exams.put('student_exams_all', allExams);
        emit(currentState.copyWith(
          exams: allExams,
          hasMore: newExams.length == _pageSize,
          isLoadingMore: false,
        ));
      },
      onFailure: (failure) {
        emit(currentState.copyWith(isLoadingMore: false));
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
        final questions = attempt.questions.isNotEmpty
            ? attempt.questions
            : (fullExam.activeVersion?.questions ?? <ExamQuestionEntity>[]);

        if (questions.isEmpty) {
          emit(const ExamsError('لا توجد أسئلة منشورة في هذا الامتحان بعد'));
          return false;
        }

        // Calculate remaining seconds
        final elapsedSeconds =
            DateTime.now().difference(attempt.startedAt).inSeconds;
        final totalSeconds = fullExam.durationMinutes * 60;
        final remaining = totalSeconds - elapsedSeconds;

        if (remaining <= 0) {
          emit(const ExamsError('انتهت المدة الزمنية المحددة لهذا الامتحان'));
          return false;
        }

        emit(ExamTakingState(
          exam: fullExam,
          attempt: attempt,
          questions: questions,
          remainingSeconds: remaining,
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
