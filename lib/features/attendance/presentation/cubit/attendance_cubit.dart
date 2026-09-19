import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/cache_manager.dart';
import '../../domain/entities/attendance_entity.dart';
import '../../domain/repositories/attendance_repository.dart';
import 'attendance_state.dart';

class AttendanceCubit extends Cubit<AttendanceState> {
  final AttendanceRepository _repository;

  AttendanceCubit({required AttendanceRepository repository})
    : _repository = repository,
      super(const AttendanceInitial());

  /// Loads the students and attendance records for a specific group and date with instant SWR cache
  Future<void> loadGroupAttendance({
    required String groupId,
    required DateTime date,
    bool forceRefresh = false,
  }) async {
    final dateKey = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final cacheKey = '${groupId}_$dateKey';
    if (forceRefresh) {
      AppCache.attendance.invalidate(cacheKey);
    }

    // ── Stale-While-Revalidate: Instant display from memory cache ──────────
    final cached = AppCache.attendance.getStale(cacheKey);
    if (cached is List<StudentAttendanceItem>) {
      emit(
        TeacherAttendanceLoaded(
          groupId: groupId,
          selectedDate: date,
          students: cached,
        ),
      );
      if (!forceRefresh && AppCache.attendance.has(cacheKey)) return; // Fresh cache, skip network
    } else {
      emit(const AttendanceLoading());
    }

    final result = await _repository.getGroupStudentsWithAttendance(
      groupId: groupId,
      date: date,
    );

    if (isClosed) return;

    result.when(
      onSuccess: (students) {
        if (!isClosed) {
          AppCache.attendance.put(cacheKey, students);
          emit(
            TeacherAttendanceLoaded(
              groupId: groupId,
              selectedDate: date,
              students: students,
            ),
          );
        }
      },
      onFailure: (failure) {
        if (!isClosed && state is! TeacherAttendanceLoaded) {
          emit(AttendanceError(failure.message));
        }
      },
    );
  }

  /// Updates the status or note for a specific student locally in the attendance sheet
  void updateStudentStatus(
    String studentId,
    AttendanceStatus status, {
    String? note,
  }) {
    final currentState = state;
    if (currentState is! TeacherAttendanceLoaded) return;

    final updatedStudents = currentState.students.map((student) {
      if (student.studentId == studentId) {
        return student.copyWith(status: status, note: note ?? student.note);
      }
      return student;
    }).toList();

    emit(currentState.copyWith(students: updatedStudents, saveSuccess: false));
  }

  /// Quickly marks all students with the given status (e.g., "Mark All Present")
  void markAll(AttendanceStatus status) {
    final currentState = state;
    if (currentState is! TeacherAttendanceLoaded) return;

    final updatedStudents = currentState.students.map((student) {
      return student.copyWith(status: status);
    }).toList();

    emit(currentState.copyWith(students: updatedStudents, saveSuccess: false));
  }

  /// Commits the attendance sheet to Supabase atomically (upsert)
  Future<void> saveAttendance() async {
    final currentState = state;
    if (currentState is! TeacherAttendanceLoaded) return;

    emit(currentState.copyWith(isSaving: true, saveSuccess: false));

    final result = await _repository.saveGroupAttendance(
      groupId: currentState.groupId,
      date: currentState.selectedDate,
      items: currentState.students,
    );

    if (isClosed) return;

    result.when(
      onSuccess: (_) {
        if (!isClosed) {
          final dateKey = "${currentState.selectedDate.year}-${currentState.selectedDate.month.toString().padLeft(2, '0')}-${currentState.selectedDate.day.toString().padLeft(2, '0')}";
          AppCache.attendance.put('${currentState.groupId}_$dateKey', currentState.students);
          emit(
            currentState.copyWith(
              isSaving: false,
              saveSuccess: true,
              message: 'تم حفظ سجل الحضور بنجاح',
            ),
          );
        }
      },
      onFailure: (failure) {
        if (!isClosed) {
          emit(
            currentState.copyWith(
              isSaving: false,
              saveSuccess: false,
              message: failure.message,
            ),
          );
        }
      },
    );
  }

  static const int _pageSize = 20;
  int _studentPage = 0;
  String? _lastStudentId;
  String? _lastGroupId;

  /// Loads student attendance history and computed stats
  Future<void> loadStudentAttendance({
    required String studentId,
    String? groupId,
  }) async {
    _studentPage = 0;
    _lastStudentId = studentId;
    _lastGroupId = groupId;
    emit(const AttendanceLoading());

    final historyFuture = _repository.getStudentAttendanceHistory(
      studentId: studentId,
      groupId: groupId,
      page: 0,
      pageSize: _pageSize,
    );
    final statsFuture = _repository.getStudentAttendanceStats(
      studentId: studentId,
      groupId: groupId,
    );

    final results = await Future.wait([historyFuture, statsFuture]);

    if (isClosed) return;

    final historyResult = results[0] as Result<List<AttendanceEntity>>;
    final statsResult = results[1] as Result<AttendanceStats>;

    if (historyResult.isSuccess) {
      final records = historyResult.dataOrNull ?? [];
      final stats = statsResult.dataOrNull ?? AttendanceStats.fromRecords(records);
      emit(
        StudentAttendanceLoaded(
          records: records,
          stats: stats,
          selectedGroupId: groupId,
          hasMore: records.length == _pageSize,
          isLoadingMore: false,
        ),
      );
    } else {
      final error =
          historyResult.failureOrNull?.message ?? 'Failed to load attendance';
      emit(AttendanceError(error));
    }
  }

  /// Loads more attendance history for the student (Infinite Scroll / Pagination)
  Future<void> loadMoreStudentAttendance() async {
    final currentState = state;
    if (currentState is! StudentAttendanceLoaded) return;
    if (!currentState.hasMore || currentState.isLoadingMore) return;
    if (_lastStudentId == null) return;

    emit(currentState.copyWith(isLoadingMore: true));

    final nextPage = _studentPage + 1;
    final result = await _repository.getStudentAttendanceHistory(
      studentId: _lastStudentId!,
      groupId: _lastGroupId,
      page: nextPage,
      pageSize: _pageSize,
    );

    if (isClosed) return;

    result.when(
      onSuccess: (newRecords) {
        if (!isClosed) {
          _studentPage = nextPage;
          final updated = [...currentState.records, ...newRecords];
          emit(
            currentState.copyWith(
              records: updated,
              hasMore: newRecords.length == _pageSize,
              isLoadingMore: false,
            ),
          );
        }
      },
      onFailure: (_) {
        if (!isClosed) {
          emit(currentState.copyWith(isLoadingMore: false));
        }
      },
    );
  }
}
