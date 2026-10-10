import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/exam_parent_dispatch_entity.dart';
import '../../domain/repositories/exams_repository.dart';
import 'exam_dispatch_state.dart';

class ExamDispatchCubit extends Cubit<ExamDispatchState> {
  final ExamsRepository _repository;
  final FlutterSecureStorage _storage;
  String? _currentExamId;

  ExamDispatchCubit({
    required ExamsRepository repository,
    FlutterSecureStorage? storage,
  })  : _repository = repository,
        _storage = storage ?? const FlutterSecureStorage(),
        super(const ExamDispatchInitial());

  String? get currentExamId => _currentExamId;

  Future<void> loadRoster(String examId) async {
    _currentExamId = examId;
    emit(const ExamDispatchLoading());

    // 1. Fetch roster from repository
    final result = await _repository.getExamParentDispatchRoster(examId);

    // 2. Load persisted sent student IDs for this exam
    final sentIds = await _loadSentIds(examId);

    result.when(
      onSuccess: (roster) {
        emit(
          ExamDispatchLoaded(
            roster: roster,
            sentStudentIds: sentIds,
          ),
        );
      },
      onFailure: (failure) {
        emit(ExamDispatchError(failure.message));
      },
    );
  }

  void setFilter(ExamDispatchFilter filter) {
    final state = this.state;
    if (state is ExamDispatchLoaded) {
      emit(state.copyWith(activeFilter: filter));
    }
  }

  void setSearchQuery(String query) {
    final state = this.state;
    if (state is ExamDispatchLoaded) {
      emit(state.copyWith(searchQuery: query));
    }
  }

  void setSort(ExamDispatchSort sort) {
    final state = this.state;
    if (state is ExamDispatchLoaded) {
      emit(state.copyWith(activeSort: sort));
    }
  }

  Future<void> markAsSent(String studentId) async {
    final state = this.state;
    if (state is! ExamDispatchLoaded || _currentExamId == null) return;

    final updated = Set<String>.from(state.sentStudentIds)..add(studentId);
    emit(state.copyWith(sentStudentIds: updated));
    await _saveSentIds(_currentExamId!, updated);
  }

  Future<bool> updateStudentParentPhone({
    required String studentId,
    required String newPhone,
  }) async {
    final state = this.state;
    if (state is! ExamDispatchLoaded) return false;

    emit(state.copyWith(isUpdatingPhone: true));

    final result = await _repository.updateStudentParentPhone(
      studentId: studentId,
      parentPhone: newPhone,
    );

    return result.when(
      onSuccess: (success) {
        // Update local roster in memory
        final updatedStudents = state.roster.students.map((s) {
          if (s.studentId == studentId) {
            return s.copyWith(parentPhone: newPhone);
          }
          return s;
        }).toList();

        final updatedRoster = ExamParentDispatchRosterEntity(
          exam: state.roster.exam,
          stats: state.roster.stats,
          students: updatedStudents,
        );

        emit(state.copyWith(
          roster: updatedRoster,
          isUpdatingPhone: false,
        ));
        return true;
      },
      onFailure: (failure) {
        emit(state.copyWith(isUpdatingPhone: false));
        return false;
      },
    );
  }

  Future<Set<String>> _loadSentIds(String examId) async {
    try {
      final jsonStr = await _storage.read(key: 'exam_dispatch_sent_$examId');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        return list.map((e) => e.toString()).toSet();
      }
    } catch (e) {
      AppLogger.w('ExamDispatchCubit', 'Failed to load sent student IDs: $e');
    }
    return <String>{};
  }

  Future<void> _saveSentIds(String examId, Set<String> ids) async {
    try {
      final jsonStr = jsonEncode(ids.toList());
      await _storage.write(key: 'exam_dispatch_sent_$examId', value: jsonStr);
    } catch (e) {
      AppLogger.w('ExamDispatchCubit', 'Failed to save sent student IDs: $e');
    }
  }
}
