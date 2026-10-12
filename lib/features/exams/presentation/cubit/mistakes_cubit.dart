import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/utils/cache_manager.dart';
import '../../domain/entities/mistake_entities.dart';
import '../../domain/repositories/exams_repository.dart';
import 'mistakes_state.dart';

class MistakesCubit extends Cubit<MistakesState> {
  final ExamsRepository _repository;

  MistakesCubit({required ExamsRepository repository})
      : _repository = repository,
        super(const MistakesInitial());

  String? get _currentStudentId => SupabaseService.client.auth.currentUser?.id;

  Future<void> loadMistakes({
    String? examId,
    bool onlyUnresolved = true,
    bool forceRefresh = false,
  }) async {
    final studentId = _currentStudentId;
    if (studentId == null || studentId.isEmpty) {
      emit(const MistakesError('auth_required'));
      return;
    }

    final cacheKey = AppCache.userKey('mistakes_${examId ?? "all"}_$onlyUnresolved');

    if (!forceRefresh) {
      final cached = AppCache.exams.getStale(cacheKey);
      if (cached is ({MistakeSummaryEntity summary, List<MistakeQuestionEntity> questions})) {
        emit(
          MistakesLoaded(
            summary: cached.summary,
            questions: cached.questions,
            selectedExamId: examId,
            onlyUnresolved: onlyUnresolved,
          ),
        );
        if (AppCache.exams.has(cacheKey)) return;
      } else {
        emit(const MistakesLoading());
      }
    } else {
      emit(const MistakesLoading());
    }

    // Parallel fetch: cuts network round-trip in half
    final summaryFuture = _repository.getStudentMistakesSummary(studentId);
    final questionsFuture = _repository.getStudentMistakesQuestions(
      studentId,
      examId: examId,
      onlyUnresolved: onlyUnresolved,
    );

    final summaryResult = await summaryFuture;
    final questionsResult = await questionsFuture;

    if (isClosed) return;

    if (summaryResult.isSuccess && questionsResult.isSuccess) {
      final summary = summaryResult.dataOrNull!;
      final questions = questionsResult.dataOrNull ?? [];
      AppCache.exams.put(cacheKey, (summary: summary, questions: questions));
      emit(
        MistakesLoaded(
          summary: summary,
          questions: questions,
          selectedExamId: examId,
          onlyUnresolved: onlyUnresolved,
        ),
      );
    } else {
      final msg = summaryResult.failureOrNull?.message ??
          questionsResult.failureOrNull?.message ??
          'failed_to_load_mistakes';
      if (state is! MistakesLoaded) {
        emit(MistakesError(msg));
      }
    }
  }

  Future<void> filterByExam(String? examId) async {
    final s = state;
    if (s is MistakesLoaded) {
      await loadMistakes(
        examId: examId,
        onlyUnresolved: s.onlyUnresolved,
      );
    } else {
      await loadMistakes(examId: examId);
    }
  }

  Future<void> toggleResolvedFilter(bool onlyUnresolved) async {
    final s = state;
    if (s is MistakesLoaded) {
      await loadMistakes(
        examId: s.selectedExamId,
        onlyUnresolved: onlyUnresolved,
      );
    } else {
      await loadMistakes(onlyUnresolved: onlyUnresolved);
    }
  }

  Future<void> submitPractice(List<Map<String, String>> answers) async {
    emit(const MistakesPracticeSubmitting());

    final result = await _repository.submitMistakesPractice(answers);
    result.when(
      onSuccess: (data) {
        emit(MistakesPracticeCompleted(data));
      },
      onFailure: (failure) {
        emit(MistakesError(failure.message));
      },
    );
  }
}
