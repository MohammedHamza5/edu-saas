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
    bool onlyUnresolved = false,
    MistakeStatusFilter? initialStatusFilter,
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
        final currentStatus = initialStatusFilter ??
            (state is MistakesLoaded
                ? (state as MistakesLoaded).statusFilter
                : MistakeStatusFilter.unresolved);
        emit(
          MistakesLoaded(
            summary: cached.summary,
            questions: cached.questions,
            selectedExamId: examId,
            statusFilter: currentStatus,
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
      final currentTypeFilter = state is MistakesLoaded
          ? (state as MistakesLoaded).typeFilter
          : MistakeTypeFilter.all;
      final currentSearchQuery = state is MistakesLoaded
          ? (state as MistakesLoaded).searchQuery
          : '';
      final currentStatusFilter = initialStatusFilter ??
          (state is MistakesLoaded
              ? (state as MistakesLoaded).statusFilter
              : MistakeStatusFilter.unresolved);
      emit(
        MistakesLoaded(
          summary: summary,
          questions: questions,
          selectedExamId: examId,
          statusFilter: currentStatusFilter,
          typeFilter: currentTypeFilter,
          searchQuery: currentSearchQuery,
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

  void setStatusFilter(MistakeStatusFilter filter) {
    final s = state;
    if (s is MistakesLoaded) {
      emit(s.copyWith(statusFilter: filter));
    }
  }

  void setTypeFilter(MistakeTypeFilter filter) {
    final s = state;
    if (s is MistakesLoaded) {
      emit(s.copyWith(typeFilter: filter));
    }
  }

  void setReasonFilter(MistakeReasonFilter filter) {
    final s = state;
    if (s is MistakesLoaded) {
      emit(s.copyWith(reasonFilter: filter));
    }
  }

  void setSortOrder(MistakeSortOrder sortOrder) {
    final s = state;
    if (s is MistakesLoaded) {
      emit(s.copyWith(sortOrder: sortOrder));
    }
  }

  Future<void> updateReflection({
    required String mistakeId,
    required String? reason,
  }) async {
    final s = state;
    if (s is! MistakesLoaded) return;

    // Optimistically update the question and taxonomy counts in UI
    final updatedList = s.questions.map((q) {
      if (q.mistakeId == mistakeId) {
        return q.copyWith(reflectionReason: reason);
      }
      return q;
    }).toList();

    final updatedSummary = s.summary.copyWith(
      conceptGapCount: updatedList.where((q) => q.reflectionReason == 'concept_gap').length,
      carelessErrorCount: updatedList.where((q) => q.reflectionReason == 'careless_error').length,
      misreadQuestionCount: updatedList.where((q) => q.reflectionReason == 'misread_question').length,
      timePressureCount: updatedList.where((q) => q.reflectionReason == 'time_pressure').length,
      unclassifiedCount: updatedList.where((q) => q.reflectionReason == null).length,
    );

    emit(s.copyWith(questions: updatedList, summary: updatedSummary));

    // Call repository
    final result = await _repository.updateMistakeReflection(
      mistakeId: mistakeId,
      reflectionReason: reason,
    );

    if (!result.isSuccess) {
      // Revert if failed
      emit(s);
    } else {
      // Invalidate cache to ensure sync
      AppCache.exams.invalidate(AppCache.userKey('mistakes_'));
    }
  }

  void setSearchQuery(String query) {
    final s = state;
    if (s is MistakesLoaded) {
      emit(s.copyWith(searchQuery: query));
    }
  }

  Future<void> filterByExam(String? examId) async {
    final s = state;
    if (s is MistakesLoaded) {
      await loadMistakes(
        examId: examId,
        onlyUnresolved: false,
        initialStatusFilter: s.statusFilter,
      );
    } else {
      await loadMistakes(examId: examId);
    }
  }

  void toggleResolvedFilter(bool onlyUnresolved) {
    setStatusFilter(onlyUnresolved
        ? MistakeStatusFilter.unresolved
        : MistakeStatusFilter.resolved);
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
