import 'package:flutter_bloc/flutter_bloc.dart';
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
  }) async {
    final dateKey = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final cacheKey = '${groupId}_$dateKey';

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
      if (AppCache.attendance.has(cacheKey)) return; // Fresh cache, skip network
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

  /// Loads student attendance history and computed stats
  Future<void> loadStudentAttendance({
    required String studentId,
    String? groupId,
  }) async {
    emit(const AttendanceLoading());

    final historyResult = await _repository.getStudentAttendanceHistory(
      studentId: studentId,
      groupId: groupId,
    );

    if (isClosed) return;

    final statsResult = await _repository.getStudentAttendanceStats(
      studentId: studentId,
      groupId: groupId,
    );

    if (isClosed) return;

    if (historyResult.isSuccess && statsResult.isSuccess) {
      if (!isClosed) {
        emit(
          StudentAttendanceLoaded(
            records: historyResult.dataOrNull ?? [],
            stats: statsResult.dataOrNull ?? const AttendanceStats.empty(),
            selectedGroupId: groupId,
          ),
        );
      }
    } else {
      final error =
          historyResult.failureOrNull?.message ??
          statsResult.failureOrNull?.message ??
          'فشل تحميل سجل الحضور';
      if (!isClosed) emit(AttendanceError(error));
    }
  }
}
