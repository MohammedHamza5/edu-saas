import 'package:equatable/equatable.dart';
import '../../domain/entities/attendance_entity.dart';

sealed class AttendanceState extends Equatable {
  const AttendanceState();

  @override
  List<Object?> get props => [];
}

final class AttendanceInitial extends AttendanceState {
  const AttendanceInitial();
}

final class AttendanceLoading extends AttendanceState {
  const AttendanceLoading();
}

final class TeacherAttendanceLoaded extends AttendanceState {
  final String groupId;
  final DateTime selectedDate;
  final List<StudentAttendanceItem> students;
  final bool isSaving;
  final bool saveSuccess;
  final String? message;

  const TeacherAttendanceLoaded({
    required this.groupId,
    required this.selectedDate,
    required this.students,
    this.isSaving = false,
    this.saveSuccess = false,
    this.message,
  });

  AttendanceStats get currentStats {
    int present = 0;
    int absent = 0;
    int late = 0;
    int excused = 0;

    for (final s in students) {
      switch (s.status) {
        case AttendanceStatus.present:
          present++;
        case AttendanceStatus.absent:
          absent++;
        case AttendanceStatus.late:
          late++;
        case AttendanceStatus.excused:
          excused++;
      }
    }

    return AttendanceStats(
      totalSessions: students.length,
      presentCount: present,
      absentCount: absent,
      lateCount: late,
      excusedCount: excused,
    );
  }

  TeacherAttendanceLoaded copyWith({
    String? groupId,
    DateTime? selectedDate,
    List<StudentAttendanceItem>? students,
    bool? isSaving,
    bool? saveSuccess,
    String? message,
  }) {
    return TeacherAttendanceLoaded(
      groupId: groupId ?? this.groupId,
      selectedDate: selectedDate ?? this.selectedDate,
      students: students ?? this.students,
      isSaving: isSaving ?? this.isSaving,
      saveSuccess: saveSuccess ?? this.saveSuccess,
      message: message,
    );
  }

  @override
  List<Object?> get props => [
        groupId,
        selectedDate,
        students,
        isSaving,
        saveSuccess,
        message,
      ];
}

final class StudentAttendanceLoaded extends AttendanceState {
  final List<AttendanceEntity> records;
  final AttendanceStats stats;
  final String? selectedGroupId;
  final bool isRefreshing;

  const StudentAttendanceLoaded({
    required this.records,
    required this.stats,
    this.selectedGroupId,
    this.isRefreshing = false,
  });

  StudentAttendanceLoaded copyWith({
    List<AttendanceEntity>? records,
    AttendanceStats? stats,
    String? selectedGroupId,
    bool? isRefreshing,
  }) {
    return StudentAttendanceLoaded(
      records: records ?? this.records,
      stats: stats ?? this.stats,
      selectedGroupId: selectedGroupId ?? this.selectedGroupId,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [
        records,
        stats,
        selectedGroupId,
        isRefreshing,
      ];
}

final class AttendanceError extends AttendanceState {
  final String message;

  const AttendanceError(this.message);

  @override
  List<Object?> get props => [message];
}
