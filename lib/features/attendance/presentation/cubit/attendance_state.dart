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
  final List<LectureItem> availableLectures;
  final String? selectedLectureContentId;
  final bool isSaving;
  final bool saveSuccess;
  final String? message;

  const TeacherAttendanceLoaded({
    required this.groupId,
    required this.selectedDate,
    required this.students,
    this.availableLectures = const [],
    this.selectedLectureContentId,
    this.isSaving = false,
    this.saveSuccess = false,
    this.message,
  });

  LectureItem? get activeLecture {
    if (availableLectures.isEmpty) return null;
    if (selectedLectureContentId != null) {
      return availableLectures.cast<LectureItem?>().firstWhere(
        (l) => l?.contentId == selectedLectureContentId,
        orElse: () => null,
      );
    }
    return null;
  }

  AttendanceStats get currentStats {
    int present = 0;
    int absent = 0;
    int late = 0;
    int excused = 0;
    double totalWatch = 0.0;

    for (final s in students) {
      totalWatch += s.watchProgressPercent;
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

    final avgWatch = students.isNotEmpty ? (totalWatch / students.length) : 0.0;

    return AttendanceStats(
      totalSessions: students.length,
      presentCount: present,
      absentCount: absent,
      lateCount: late,
      excusedCount: excused,
      averageWatchPercentage: avgWatch,
    );
  }

  TeacherAttendanceLoaded copyWith({
    String? groupId,
    DateTime? selectedDate,
    List<StudentAttendanceItem>? students,
    List<LectureItem>? availableLectures,
    String? selectedLectureContentId,
    bool? isSaving,
    bool? saveSuccess,
    String? message,
    bool clearSelectedLecture = false,
  }) {
    return TeacherAttendanceLoaded(
      groupId: groupId ?? this.groupId,
      selectedDate: selectedDate ?? this.selectedDate,
      students: students ?? this.students,
      availableLectures: availableLectures ?? this.availableLectures,
      selectedLectureContentId: clearSelectedLecture
          ? null
          : (selectedLectureContentId ?? this.selectedLectureContentId),
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
    availableLectures,
    selectedLectureContentId,
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
  final bool hasMore;
  final bool isLoadingMore;

  const StudentAttendanceLoaded({
    required this.records,
    required this.stats,
    this.selectedGroupId,
    this.isRefreshing = false,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  StudentAttendanceLoaded copyWith({
    List<AttendanceEntity>? records,
    AttendanceStats? stats,
    String? selectedGroupId,
    bool? isRefreshing,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return StudentAttendanceLoaded(
      records: records ?? this.records,
      stats: stats ?? this.stats,
      selectedGroupId: selectedGroupId ?? this.selectedGroupId,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
    records,
    stats,
    selectedGroupId,
    isRefreshing,
    hasMore,
    isLoadingMore,
  ];
}

final class AttendanceError extends AttendanceState {
  final String message;

  const AttendanceError(this.message);

  @override
  List<Object?> get props => [message];
}
