import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/attendance_entity.dart';
import '../../domain/repositories/attendance_repository.dart';
import 'attendance_state.dart';

class AttendanceCubit extends Cubit<AttendanceState> {
  final AttendanceRepository _repository;

  AttendanceCubit({required AttendanceRepository repository})
      : _repository = repository,
        super(const AttendanceInitial());

  /// Loads the students and attendance records for a specific group and date
  Future<void> loadGroupAttendance({
    required String groupId,
    required DateTime date,
  }) async {
    emit(const AttendanceLoading());

    final result = await _repository.getGroupStudentsWithAttendance(
      groupId: groupId,
      date: date,
    );

    result.when(
      onSuccess: (students) {
        emit(TeacherAttendanceLoaded(
          groupId: groupId,
          selectedDate: date,
          students: students,
        ));
      },
      onFailure: (failure) {
        emit(AttendanceError(failure.message));
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
        return student.copyWith(
          status: status,
          note: note ?? student.note,
        );
      }
      return student;
    }).toList();

    emit(currentState.copyWith(
      students: updatedStudents,
      saveSuccess: false,
    ));
  }

  /// Quickly marks all students with the given status (e.g., "Mark All Present")
  void markAll(AttendanceStatus status) {
    final currentState = state;
    if (currentState is! TeacherAttendanceLoaded) return;

    final updatedStudents = currentState.students.map((student) {
      return student.copyWith(status: status);
    }).toList();

    emit(currentState.copyWith(
      students: updatedStudents,
      saveSuccess: false,
    ));
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

    result.when(
      onSuccess: (_) {
        emit(currentState.copyWith(
          isSaving: false,
          saveSuccess: true,
          message: 'تم حفظ سجل الحضور بنجاح',
        ));
      },
      onFailure: (failure) {
        emit(currentState.copyWith(
          isSaving: false,
          saveSuccess: false,
          message: failure.message,
        ));
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

    final statsResult = await _repository.getStudentAttendanceStats(
      studentId: studentId,
      groupId: groupId,
    );

    if (historyResult.isSuccess && statsResult.isSuccess) {
      emit(StudentAttendanceLoaded(
        records: historyResult.dataOrNull ?? [],
        stats: statsResult.dataOrNull ?? const AttendanceStats.empty(),
        selectedGroupId: groupId,
      ));
    } else {
      final error = historyResult.failureOrNull?.message ??
          statsResult.failureOrNull?.message ??
          'فشل تحميل سجل الحضور';
      emit(AttendanceError(error));
    }
  }
}
