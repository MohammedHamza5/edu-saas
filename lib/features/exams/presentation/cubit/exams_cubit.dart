import 'dart:async';
import 'package:edu_saas/core/errors/result.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/cache_manager.dart';
import '../../data/datasources/exam_answers_local_datasource.dart';
import '../../domain/entities/exam_entity.dart';
import '../../domain/repositories/exams_repository.dart';
import '../../domain/entities/exam_folder_entity.dart';
import 'exams_state.dart';

class ExamsCubit extends Cubit<ExamsState> {
  final ExamsRepository _repository;
  final ExamAnswersLocalDataSource _answersStorage;
  Timer? _countdownTimer;
  Timer? _syncAnswersDebounce;

  static const int _pageSize = 15;
  static const int _attemptsPageSize = 20;
  int _teacherPage = 0;
  int _studentPage = 0;
  int _attemptsPage = 0;

  ExamsCubit({
    required ExamsRepository repository,
    ExamAnswersLocalDataSource answersStorage = const ExamAnswersLocalDataSource(),
  })  : _repository = repository,
        _answersStorage = answersStorage,
        super(const ExamsInitial());

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    _syncAnswersDebounce?.cancel();
    return super.close();
  }

  // ── Teacher Flow ─────────────────────────────────────────────────────────

  /// Loads all exams for a specific group (Teacher flow) with instant SWR cache
  Future<void> loadGroupExams(
    String groupId, {
    bool forceRefresh = false,
  }) async {
    if (state is ExamTakingState && !(state as ExamTakingState).submitSuccess) {
      return;
    }

    _teacherPage = 0;
    final cacheKey = AppCache.userKey('teacher_exams_$groupId');
    if (forceRefresh) {
      AppCache.exams.invalidate(cacheKey);
    }

    // ── Stale-While-Revalidate: Instant display from memory cache ──────────
    final cached = AppCache.exams.getStale(cacheKey);
    if (cached is List<ExamEntity>) {
      emit(
        TeacherExamsLoaded(
          groupId: groupId,
          exams: cached,
          hasMore: cached.length >= _pageSize,
        ),
      );
      // Stale cache displayed immediately, then continue to network fetch to guarantee fresh updates
    } else {
      emit(const ExamsLoading());
    }

    final foldersFuture = _repository.getExamFolders(groupId: groupId);
    final examsFuture = _repository.getGroupExams(
      groupId,
      page: 0,
      pageSize: _pageSize,
    );

    final results = await Future.wait([examsFuture, foldersFuture]);
    final result = results[0] as Result<List<ExamEntity>>;
    final foldersResult = results[1] as Result<List<ExamFolderEntity>>;
    final folders = foldersResult.dataOrNull ?? [];

    result.when(
      onSuccess: (exams) {
        AppCache.exams.put(cacheKey, exams);
        emit(
          TeacherExamsLoaded(
            groupId: groupId,
            exams: exams,
            folders: folders,
            selectedFolderId: (state is TeacherExamsLoaded)
                ? (state as TeacherExamsLoaded).selectedFolderId
                : null,
            hasMore: exams.length == _pageSize,
            isLoadingMore: false,
          ),
        );
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
    if (!currentState.hasMore ||
        currentState.isLoadingMore ||
        currentState.groupId == null) {
      return;
    }

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
        AppCache.exams.put(AppCache.userKey('teacher_exams_${currentState.groupId}'), allExams);
        emit(
          currentState.copyWith(
            exams: allExams,
            hasMore: newExams.length == _pageSize,
            isLoadingMore: false,
          ),
        );
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

    _attemptsPage = 0;
    emit(currentState.copyWith(selectedExam: exam, isLoadingAttempts: true));

    final result = await _repository.getExamAttempts(
      exam.id,
      page: 0,
      pageSize: _attemptsPageSize,
    );

    result.when(
      onSuccess: (attempts) {
        emit(
          currentState.copyWith(
            selectedExam: exam,
            attempts: attempts,
            hasMoreAttempts: attempts.length >= _attemptsPageSize,
            isLoadingAttempts: false,
          ),
        );
      },
      onFailure: (failure) {
        emit(
          currentState.copyWith(
            selectedExam: exam,
            isLoadingAttempts: false,
            message: failure.message,
          ),
        );
      },
    );
  }

  /// Loads the next page of student attempts for the selected exam
  Future<void> loadMoreExamAttempts() async {
    final currentState = state;
    if (currentState is! TeacherExamsLoaded) return;
    if (currentState.isLoadingMoreAttempts || !currentState.hasMoreAttempts) {
      return;
    }
    final exam = currentState.selectedExam;
    if (exam == null) return;

    emit(currentState.copyWith(isLoadingMoreAttempts: true));

    final nextPage = _attemptsPage + 1;
    final result = await _repository.getExamAttempts(
      exam.id,
      page: nextPage,
      pageSize: _attemptsPageSize,
    );

    if (isClosed) return;

    result.when(
      onSuccess: (newAttempts) {
        _attemptsPage = nextPage;
        final updated = [...currentState.attempts, ...newAttempts];
        emit(
          currentState.copyWith(
            attempts: updated,
            hasMoreAttempts: newAttempts.length >= _attemptsPageSize,
            isLoadingMoreAttempts: false,
          ),
        );
      },
      onFailure: (_) {
        emit(currentState.copyWith(isLoadingMoreAttempts: false));
      },
    );
  }

  /// Creates a new exam with initial questions and version (Teacher flow)
  Future<ExamEntity?> createExam({
    String? groupId,
    required String title,
    int durationMinutes = 60,
    int maxScore = 100,
    int? passingScore,
    bool shuffleQuestions = false,
    bool showResult = true,
    bool allowRetake = false,
    DateTime? startAt,
    DateTime? endAt,
    bool isPublished = false,
    String? pdfFileId,
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
      isPublished: isPublished,
      pdfFileId: pdfFileId,
      initialQuestions: initialQuestions,
    );

    return result.when(
      onSuccess: (created) {
        if (groupId != null) {
          AppCache.exams.invalidate(AppCache.userKey('teacher_exams_$groupId'));
          loadGroupExams(groupId, forceRefresh: true);
        }
        return created;
      },
      onFailure: (failure) {
        if (currentState is TeacherExamsLoaded) {
          emit(
            currentState.copyWith(isCreating: false, message: failure.message),
          );
        } else {
          emit(ExamsError(failure.message));
        }
        return null;
      },
    );
  }

  /// Updates an exam's title and settings (Teacher flow)
  Future<bool> updateExam({
    required String examId,
    required String title,
    int? durationMinutes,
    int? maxScore,
    int? passingScore,
    bool? shuffleQuestions,
    bool? showResult,
    bool? allowRetake,
    DateTime? startAt,
    DateTime? endAt,
    bool? isPublished,
    String? pdfFileId,
    bool clearPdfFile = false,
  }) async {
    final result = await _repository.updateExam(
      examId: examId,
      title: title,
      durationMinutes: durationMinutes,
      maxScore: maxScore,
      passingScore: passingScore,
      shuffleQuestions: shuffleQuestions,
      showResult: showResult,
      allowRetake: allowRetake,
      startAt: startAt,
      endAt: endAt,
      isPublished: isPublished,
      pdfFileId: pdfFileId,
      clearPdfFile: clearPdfFile,
    );

    return result.when(
      onSuccess: (updatedExam) {
        final currentState = state;
        if (currentState is TeacherExamsLoaded) {
          if (currentState.groupId != null) {
            AppCache.exams.invalidate(AppCache.userKey('teacher_exams_${currentState.groupId}'));
          }
          final index = currentState.exams.indexWhere(
            (e) => e.id == updatedExam.id,
          );
          final updatedList = List<ExamEntity>.from(currentState.exams);
          if (index != -1) {
            updatedList[index] = updatedExam;
          }
          emit(
            currentState.copyWith(
              exams: updatedList,
              selectedExam: currentState.selectedExam?.id == updatedExam.id
                  ? updatedExam
                  : currentState.selectedExam,
            ),
          );
        }
        return true;
      },
      onFailure: (failure) {
        final currentState = state;
        if (currentState is TeacherExamsLoaded) {
          emit(currentState.copyWith(message: failure.message));
        } else {
          emit(ExamsError(failure.message));
        }
        return false;
      },
    );
  }

  /// Updates an existing draft exam's metadata and atomic questions (Teacher flow)
  Future<ExamEntity?> updateDraftExamQuestions({
    required String examId,
    required String title,
    int? durationMinutes,
    int? maxScore,
    int? passingScore,
    bool? shuffleQuestions,
    bool? showResult,
    bool? allowRetake,
    DateTime? startAt,
    DateTime? endAt,
    bool? isPublished,
    String? pdfFileId,
    bool clearPdfFile = false,
    required List<ExamQuestionEntity> questions,
  }) async {
    final currentState = state;
    if (currentState is TeacherExamsLoaded) {
      emit(currentState.copyWith(isCreating: true));
    }

    final result = await _repository.updateDraftExamQuestions(
      examId: examId,
      title: title,
      durationMinutes: durationMinutes,
      maxScore: maxScore,
      passingScore: passingScore,
      shuffleQuestions: shuffleQuestions,
      showResult: showResult,
      allowRetake: allowRetake,
      startAt: startAt,
      endAt: endAt,
      isPublished: isPublished,
      pdfFileId: pdfFileId,
      clearPdfFile: clearPdfFile,
      questions: questions,
    );

    return result.when(
      onSuccess: (updatedExam) {
        if (currentState is TeacherExamsLoaded) {
          if (currentState.groupId != null) {
            AppCache.exams.invalidate('teacher_exams_${currentState.groupId}');
          }
          final index = currentState.exams.indexWhere(
            (e) => e.id == updatedExam.id,
          );
          final updatedList = List<ExamEntity>.from(currentState.exams);
          if (index != -1) {
            updatedList[index] = updatedExam;
          }
          emit(
            currentState.copyWith(
              isCreating: false,
              exams: updatedList,
              selectedExam: currentState.selectedExam?.id == updatedExam.id
                  ? updatedExam
                  : currentState.selectedExam,
            ),
          );
        }
        return updatedExam;
      },
      onFailure: (failure) {
        if (currentState is TeacherExamsLoaded) {
          emit(
            currentState.copyWith(isCreating: false, message: failure.message),
          );
        } else {
          emit(ExamsError(failure.message));
        }
        return null;
      },
    );
  }

  /// Obtains a secure signed URL for viewing an attached exam PDF booklet
  Future<String?> getSignedPdfUrl(String storagePath) async {
    final result = await _repository.getSignedPdfUrl(storagePath);
    switch (result) {
      case Success(:final data):
        return data;
      case FailureResult():
        return null;
    }
  }

  /// Fetches complete details of an exam including questions and options
  Future<ExamEntity?> getExamDetails(String examId) async {
    final result = await _repository.getExamDetails(examId);
    return result.when(
      onSuccess: (exam) => exam,
      onFailure: (failure) {
        AppLogger.w(
          'ExamsCubit',
          'Could not get exam details: ${failure.message}',
        );
        return null;
      },
    );
  }

  /// Deletes or archives an exam with cascade cleanup (Teacher flow)
  Future<bool> deleteExam({required String examId, bool force = false}) async {
    final currentState = state;
    if (currentState is! TeacherExamsLoaded) return false;

    final result = await _repository.deleteExam(examId: examId, force: force);

    return result.when(
      onSuccess: (success) {
        if (!success) return false;
        if (currentState.groupId != null) {
          AppCache.exams.invalidate('teacher_exams_${currentState.groupId}');
        }
        final updatedList = currentState.exams
            .where((e) => e.id != examId)
            .toList();
        emit(
          currentState.copyWith(
            exams: updatedList,
            selectedExam: currentState.selectedExam?.id == examId
                ? null
                : currentState.selectedExam,
          ),
        );
        return true;
      },
      onFailure: (failure) {
        emit(currentState.copyWith(message: failure.message));
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
      onSuccess: (newVersion) {
        if (currentState.groupId != null) {
          AppCache.exams.invalidate('teacher_exams_${currentState.groupId}');
          loadGroupExams(currentState.groupId!, forceRefresh: true);
        }

        final updatedExams = currentState.exams.map((e) {
          if (e.id == examId) {
            return e.copyWith(activeVersion: newVersion);
          }
          return e;
        }).toList();

        final updatedSelected = currentState.selectedExam?.id == examId
            ? currentState.selectedExam!.copyWith(activeVersion: newVersion)
            : currentState.selectedExam;

        emit(
          currentState.copyWith(
            exams: updatedExams,
            selectedExam: updatedSelected,
          ),
        );
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
        if (currentState.selectedExam?.id == examId &&
            currentState.selectedExam?.activeVersion != null) {
          final updatedSelected = currentState.selectedExam!.copyWith(
            activeVersion: currentState.selectedExam!.activeVersion!.copyWith(
              status: ExamStatus.published,
              publishedAt: DateTime.now(),
            ),
          );
          emit(currentState.copyWith(selectedExam: updatedSelected));
        }
        return true;
      },
      onFailure: (failure) {
        emit(currentState.copyWith(message: failure.message));
        return false;
      },
    );
  }

  /// Reverts a published exam version back to draft, hiding it from students (Teacher flow)
  Future<bool> unpublishVersion({
    required String examId,
    required String versionId,
  }) async {
    final currentState = state;
    if (currentState is! TeacherExamsLoaded) return false;

    final result = await _repository.unpublishExamVersion(
      examId: examId,
      versionId: versionId,
    );

    return result.when(
      onSuccess: (_) {
        if (currentState.groupId != null) {
          AppCache.exams.invalidate('teacher_exams_${currentState.groupId}');
          loadGroupExams(currentState.groupId!, forceRefresh: true);
        }
        if (currentState.selectedExam?.id == examId &&
            currentState.selectedExam?.activeVersion != null) {
          final updatedSelected = currentState.selectedExam!.copyWith(
            activeVersion: currentState.selectedExam!.activeVersion!.copyWith(
              status: ExamStatus.draft,
            ),
          );
          emit(currentState.copyWith(selectedExam: updatedSelected));
        }
        return true;
      },
      onFailure: (failure) {
        emit(currentState.copyWith(message: failure.message));
        return false;
      },
    );
  }

  /// Fetches lessons in the group for linking exams (Teacher flow)
  Future<List<Map<String, dynamic>>> getGroupLessons(String groupId) async {
    final result = await _repository.getGroupLessons(groupId);
    return result.when(
      onSuccess: (lessons) => lessons,
      onFailure: (_) => <Map<String, dynamic>>[],
    );
  }

  /// Links an exam to a lesson as its gatekeeper quiz (Teacher flow)
  Future<bool> linkExamToLesson({
    required String examId,
    required String lessonId,
    required String groupId,
  }) async {
    final currentState = state;
    if (currentState is! TeacherExamsLoaded) return false;

    final result = await _repository.linkExamToLesson(
      examId: examId,
      lessonId: lessonId,
      groupId: groupId,
    );

    return result.when(
      onSuccess: (_) {
        AppCache.exams.invalidate('teacher_exams_$groupId');
        loadGroupExams(groupId, forceRefresh: true);
        return true;
      },
      onFailure: (failure) {
        emit(currentState.copyWith(message: failure.message));
        return false;
      },
    );
  }

  /// Unlinks an exam from lessons in the group (Teacher flow)
  Future<bool> unlinkExamFromLesson({
    required String examId,
    required String groupId,
    bool makeGeneralExam = false,
  }) async {
    final currentState = state;
    if (currentState is! TeacherExamsLoaded) return false;

    final result = await _repository.unlinkExamFromLesson(
      examId: examId,
      groupId: groupId,
      makeGeneralExam: makeGeneralExam,
    );

    return result.when(
      onSuccess: (_) {
        AppCache.exams.invalidate('teacher_exams_$groupId');
        loadGroupExams(groupId, forceRefresh: true);
        return true;
      },
      onFailure: (failure) {
        emit(currentState.copyWith(message: failure.message));
        return false;
      },
    );
  }

  /// Converts exam type between lecture quiz and general exam (Teacher flow)
  Future<bool> convertExamType({
    required String examId,
    required String contentId,
    required bool toLectureExam,
    required String groupId,
  }) async {
    final currentState = state;
    if (currentState is! TeacherExamsLoaded) return false;

    final result = await _repository.convertExamType(
      examId: examId,
      contentId: contentId,
      toLectureExam: toLectureExam,
      groupId: groupId,
    );

    return result.when(
      onSuccess: (_) {
        AppCache.exams.invalidate('teacher_exams_$groupId');
        loadGroupExams(groupId, forceRefresh: true);
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
    // Critical Guard: Only guard if exam taking is ACTIVELY in progress (solving) and not yet submitted!
    if (state is ExamTakingState) {
      final taking = state as ExamTakingState;
      if (!taking.submitSuccess) {
        AppLogger.w(
          'ExamsCubit',
          'Ignored loadStudentExams while exam is actively in progress',
        );
        return;
      }
      _countdownTimer?.cancel();
      _countdownTimer = null;
      _syncAnswersDebounce?.cancel();
      _syncAnswersDebounce = null;
    }

    _studentPage = 0;
    final cacheKey = AppCache.userKey('student_exams');
    if (forceRefresh) {
      AppCache.exams.invalidate(cacheKey);
    }

    // ── Stale-While-Revalidate: Instant display from memory cache ──────────
    final cached = AppCache.exams.getStale(cacheKey);
    if (cached is List<ExamEntity>) {
      if (cached.isEmpty) {
        emit(const ExamsEmpty(message: 'لا توجد امتحانات متاحة حالياً'));
      } else {
        final cachedFolders = _extractFoldersFromExams(cached);
        emit(
          StudentExamsLoaded(
            exams: cached,
            folders: cachedFolders,
            hasMore: cached.length >= _pageSize,
          ),
        );
      }
      if (!forceRefresh && AppCache.exams.has(cacheKey)) {
        return; // Fresh cache within TTL, skip redundant network RPC call!
      }
      // Stale cache displayed immediately, then continue to network fetch in background to guarantee fresh updates
    } else {
      emit(const ExamsLoading());
    }

    final result = await _repository.getStudentExams(
      page: 0,
      pageSize: _pageSize,
    );

    result.when(
      onSuccess: (exams) {
        // Double check state hasn't transitioned to an active ExamTakingState while waiting for network
        if (state is ExamTakingState && !(state as ExamTakingState).submitSuccess) return;

        AppCache.exams.put(cacheKey, exams);
        if (exams.isEmpty) {
          emit(const ExamsEmpty(message: 'لا توجد امتحانات متاحة حالياً'));
        } else {
          final folders = _extractFoldersFromExams(exams);
          emit(
            StudentExamsLoaded(
              exams: exams,
              folders: folders,
              selectedFolderId: (state is StudentExamsLoaded)
                  ? (state as StudentExamsLoaded).selectedFolderId
                  : null,
              hasMore: exams.length == _pageSize,
              isLoadingMore: false,
            ),
          );
        }
      },
      onFailure: (failure) {
        if (state is! StudentExamsLoaded &&
            (state is! ExamTakingState || (state as ExamTakingState).submitSuccess)) {
          emit(ExamsError(failure.message));
        }
      },
    );
  }

  /// Extracts unique exam folders with accurate exam counts from student accessible exams
  List<ExamFolderEntity> _extractFoldersFromExams(List<ExamEntity> exams) {
    final Map<String, ExamFolderEntity> folderMap = {};
    for (final exam in exams) {
      if (exam.folderId != null && exam.folderId!.trim().isNotEmpty) {
        final fid = exam.folderId!.trim();
        if (!folderMap.containsKey(fid)) {
          folderMap[fid] = ExamFolderEntity(
            id: fid,
            tenantId: exam.tenantId,
            groupId: exam.groupId,
            name: exam.folderName ?? '',
            color: exam.folderColor ?? '#5B4FE0',
            examCount: 1,
            createdAt: exam.createdAt,
            updatedAt: exam.updatedAt,
          );
        } else {
          final existing = folderMap[fid]!;
          folderMap[fid] = existing.copyWith(
            examCount: existing.examCount + 1,
          );
        }
      }
    }
    final list = folderMap.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
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
        final folders = _extractFoldersFromExams(allExams);
        AppCache.exams.put(AppCache.userKey('student_exams'), allExams);
        emit(
          currentState.copyWith(
            exams: allExams,
            folders: folders,
            hasMore: newExams.length == _pageSize,
            isLoadingMore: false,
          ),
        );
      },
      onFailure: (failure) {
        emit(currentState.copyWith(isLoadingMore: false));
      },
    );
  }

  /// Starts or resumes an exam attempt for the student (Student taking environment)
  Future<bool> startExamTaking(
    ExamEntity exam, {
    bool isLectureExam = false,
  }) async {
    emit(const ExamsLoading());

    // 1. Fetch full details to ensure we have questions
    final detailsRes = await _repository.getExamDetails(exam.id);
    final fullExam = detailsRes
        .when(
          onSuccess: (e) => e,
          onFailure: (_) => exam,
        )
        .copyWith(
          isLectureExam:
              isLectureExam || exam.isLectureExam || exam.isLinkedToLesson,
        );

    // 2. Start attempt via RPC
    final attemptRes = await _repository.startExam(exam.id);

    switch (attemptRes) {
      case FailureResult(:final failure):
        emit(ExamsError(failure.message));
        return false;
      case Success(:final data):
        final attempt = data;
        final questions = attempt.questions.isNotEmpty
            ? attempt.questions
            : (fullExam.activeVersion?.questions ?? <ExamQuestionEntity>[]);

        if (questions.isEmpty) {
          emit(const ExamsError('لا توجد أسئلة منشورة في هذا الامتحان بعد'));
          return false;
        }

        final isUntimed =
            isLectureExam ||
            fullExam.durationMinutes <= 0 ||
            exam.durationMinutes <= 0;
        int remaining = 0;

        if (!isUntimed) {
          final totalSeconds = (fullExam.durationMinutes > 0
                  ? fullExam.durationMinutes
                  : exam.durationMinutes) *
              60;

          // 1. Prefer server-authoritative remaining seconds (immune to client clock skew)
          if (attempt.remainingSeconds != null &&
              attempt.remainingSeconds! > 0) {
            remaining = attempt.remainingSeconds!;
          } else {
            // 2. Fallback: calculate elapsed time using UTC
            final nowUtc = DateTime.now().toUtc();
            final startedUtc = attempt.startedAt.toUtc();
            final elapsedSeconds = nowUtc.difference(startedUtc).inSeconds;

            // If elapsed is negative or unreasonable on an attempt granted by the server,
            // guard against client clock skew by granting totalSeconds.
            if (elapsedSeconds < 0 || elapsedSeconds >= totalSeconds) {
              remaining = totalSeconds;
            } else {
              remaining = totalSeconds - elapsedSeconds;
            }
          }

          // Safety guard: The backend server authorized this attempt, so never block at initialization
          if (remaining <= 0) {
            remaining = totalSeconds;
          }
        }

        // 3. Restore and merge saved answers:
        //    a) Server-side synced answers from prior sessions / devices
        final mergedAnswers = <String, String>{};
        for (final ans in attempt.answers) {
          final optId = ans.selectedOptionId;
          if (optId != null && optId.isNotEmpty) {
            mergedAnswers[ans.questionId] = optId;
          }
        }
        //    b) Local storage overlay (in case student answered while offline/disconnected)
        try {
          final localAnswers = await _answersStorage.getAnswers(attempt.id);
          mergedAnswers.addAll(localAnswers);
        } catch (_) {}

        emit(
          ExamTakingState(
            exam: fullExam,
            attempt: attempt,
            questions: questions,
            answers: mergedAnswers,
            remainingSeconds: remaining,
            isUntimed: isUntimed,
          ),
        );

        if (!isUntimed) {
          _startTimer();
        }
        return true;
    }
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    final currentState = state;
    if (currentState is ExamTakingState && currentState.isUntimed) {
      return;
    }
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final currentState = state;
      if (currentState is! ExamTakingState || currentState.isUntimed) {
        timer.cancel();
        return;
      }

      if (currentState.remainingSeconds <= 1) {
        timer.cancel();
        emit(currentState.copyWith(remainingSeconds: 0, isExpired: true));
        submitExam(reason: ExamSubmissionReason.timeExpired);
      } else {
        emit(
          currentState.copyWith(
            remainingSeconds: currentState.remainingSeconds - 1,
          ),
        );
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

    // 1. Persist draft answers locally in background (instant hardware-backed recovery)
    unawaited(_answersStorage.saveAnswers(
      attemptId: currentState.attempt.id,
      answers: updatedAnswers,
    ));

    // 2. Debounced live sync to server database (server-side recovery across devices/refreshes)
    _syncAnswersDebounce?.cancel();
    _syncAnswersDebounce = Timer(const Duration(milliseconds: 1000), () {
      if (isClosed) return;
      unawaited(_repository.syncExamAnswers(
        attemptId: currentState.attempt.id,
        answers: updatedAnswers,
      ));
    });
  }

  /// Navigates to a specific question index
  void goToQuestion(int index) {
    final currentState = state;
    if (currentState is! ExamTakingState) return;

    // Immediately flush any pending answer sync before switching questions
    if (_syncAnswersDebounce?.isActive ?? false) {
      _syncAnswersDebounce?.cancel();
      unawaited(_repository.syncExamAnswers(
        attemptId: currentState.attempt.id,
        answers: currentState.answers,
      ));
    }

    if (index >= 0 && index < currentState.questions.length) {
      emit(currentState.copyWith(currentQuestionIndex: index));
    }
  }

  /// Submits the exam answers atomically to the server
  Future<bool> submitExam({
    ExamSubmissionReason reason = ExamSubmissionReason.studentSubmitted,
  }) async {
    final currentState = state;
    if (currentState is! ExamTakingState) return false;

    _countdownTimer?.cancel();
    _syncAnswersDebounce?.cancel();
    emit(currentState.copyWith(isSubmitting: true));

    final result = await _repository.submitExam(
      attemptId: currentState.attempt.id,
      answers: currentState.answers,
      reason: reason,
    );

    return result.when(
      onSuccess: (submitResult) {
        AppCache.exams.clear();
        AppCache.content.clear();
        unawaited(_answersStorage.clearAnswers(currentState.attempt.id));
        emit(
          currentState.copyWith(
            isSubmitting: false,
            submitSuccess: true,
            submitResult: submitResult,
          ),
        );
        return true;
      },
      onFailure: (failure) {
        emit(
          currentState.copyWith(
            isSubmitting: false,
            errorMessage: failure.message,
          ),
        );
        return false;
      },
    );
  }

  /// Explicitly exits exam taking flow and resets state, canceling any timers
  void exitExamTaking() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _syncAnswersDebounce?.cancel();
    _syncAnswersDebounce = null;
    if (state is ExamTakingState) {
      emit(const ExamsInitial());
    }
  }

  void selectFolder(String? folderId) {
    final currentState = state;
    if (currentState is TeacherExamsLoaded) {
      if (folderId == null) {
        emit(currentState.copyWith(clearSelectedFolder: true));
      } else {
        emit(currentState.copyWith(selectedFolderId: folderId));
      }
    } else if (currentState is StudentExamsLoaded) {
      if (folderId == null) {
        emit(currentState.copyWith(clearSelectedFolder: true));
      } else {
        emit(currentState.copyWith(selectedFolderId: folderId));
      }
    }
  }

  void selectStudentFolder(String? folderId) => selectFolder(folderId);

  Future<void> loadFolders({String? groupId}) async {
    final currentState = state;
    if (currentState is! TeacherExamsLoaded) return;
    final targetGroupId = groupId ?? currentState.groupId;
    final res = await _repository.getExamFolders(groupId: targetGroupId);
    res.when(
      onSuccess: (folders) {
        emit(currentState.copyWith(folders: folders));
      },
      onFailure: (_) {},
    );
  }

  Future<bool> createFolder({
    required String name,
    String? groupId,
    String? color,
    String? icon,
    String? description,
  }) async {
    final currentState = state;
    if (currentState is! TeacherExamsLoaded) return false;
    final targetGroupId = groupId ?? currentState.groupId;
    final res = await _repository.createExamFolder(
      name: name,
      groupId: targetGroupId,
      color: color,
      icon: icon,
      description: description,
    );
    return res.when(
      onSuccess: (newFolder) {
        final updatedFolders = [...currentState.folders, newFolder];
        emit(currentState.copyWith(folders: updatedFolders));
        return true;
      },
      onFailure: (failure) {
        emit(currentState.copyWith(message: failure.message));
        return false;
      },
    );
  }

  Future<bool> updateFolder({
    required String folderId,
    required String name,
    String? color,
    String? icon,
    String? description,
  }) async {
    final currentState = state;
    if (currentState is! TeacherExamsLoaded) return false;
    final res = await _repository.updateExamFolder(
      folderId: folderId,
      name: name,
      color: color,
      icon: icon,
      description: description,
    );
    return res.when(
      onSuccess: (updatedFolder) {
        final updatedFolders = currentState.folders
            .map((f) => f.id == folderId ? updatedFolder : f)
            .toList();
        emit(currentState.copyWith(folders: updatedFolders));
        return true;
      },
      onFailure: (failure) {
        emit(currentState.copyWith(message: failure.message));
        return false;
      },
    );
  }

  Future<bool> deleteFolder(String folderId) async {
    final currentState = state;
    if (currentState is! TeacherExamsLoaded) return false;
    final res = await _repository.deleteExamFolder(folderId);
    return res.when(
      onSuccess: (_) {
        final updatedFolders = currentState.folders
            .where((f) => f.id != folderId)
            .toList();
        final shouldClearSelected = currentState.selectedFolderId == folderId;
        final updatedExams = currentState.exams.map((e) {
          if (e.folderId == folderId) {
            return e.copyWith(
              folderId: null,
              folderName: null,
              folderColor: null,
            );
          }
          return e;
        }).toList();
        emit(
          currentState.copyWith(
            folders: updatedFolders,
            exams: updatedExams,
            clearSelectedFolder: shouldClearSelected,
          ),
        );
        return true;
      },
      onFailure: (failure) {
        emit(currentState.copyWith(message: failure.message));
        return false;
      },
    );
  }

  Future<bool> moveExamToFolder({
    required String examId,
    String? folderId,
  }) async {
    final currentState = state;
    if (currentState is! TeacherExamsLoaded) return false;
    final res = await _repository.moveExamToFolder(
      examId: examId,
      folderId: folderId,
    );
    return res.when(
      onSuccess: (_) {
        final targetFolder = folderId != null
            ? currentState.folders.where((f) => f.id == folderId).firstOrNull
            : null;
        final updatedExams = currentState.exams.map((e) {
          if (e.id == examId) {
            return e.copyWith(
              folderId: folderId,
              folderName: targetFolder?.name,
              folderColor: targetFolder?.color,
            );
          }
          return e;
        }).toList();

        // Refresh folders to update counts
        _repository.getExamFolders().then((fRes) {
          if (!isClosed && state is TeacherExamsLoaded) {
            final latestFolders = fRes.dataOrNull ?? currentState.folders;
            emit(
              (state as TeacherExamsLoaded).copyWith(
                exams: updatedExams,
                folders: latestFolders,
              ),
            );
          }
        });

        emit(currentState.copyWith(exams: updatedExams));
        return true;
      },
      onFailure: (failure) {
        emit(currentState.copyWith(message: failure.message));
        return false;
      },
    );
  }
}
