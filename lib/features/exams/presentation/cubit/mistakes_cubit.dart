import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/supabase_service.dart';
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
  }) async {
    final studentId = _currentStudentId;
    if (studentId == null || studentId.isEmpty) {
      emit(const MistakesError('auth_required'));
      return;
    }

    emit(const MistakesLoading());

    final summaryResult = await _repository.getStudentMistakesSummary(studentId);
    final questionsResult = await _repository.getStudentMistakesQuestions(
      studentId,
      examId: examId,
      onlyUnresolved: onlyUnresolved,
    );

    if (summaryResult.isSuccess && questionsResult.isSuccess) {
      emit(
        MistakesLoaded(
          summary: summaryResult.dataOrNull!,
          questions: questionsResult.dataOrNull ?? [],
          selectedExamId: examId,
          onlyUnresolved: onlyUnresolved,
        ),
      );
    } else {
      final msg = summaryResult.failureOrNull?.message ??
          questionsResult.failureOrNull?.message ??
          'failed_to_load_mistakes';
      emit(MistakesError(msg));
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
