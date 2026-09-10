import 'package:equatable/equatable.dart';
import '../../domain/entities/student_360_entity.dart';
import '../../domain/entities/student_entity.dart';

sealed class StudentsState extends Equatable {
  const StudentsState();

  @override
  List<Object?> get props => [];
}

// ── Initial ───────────────────────────────────────────────────────────────

final class StudentsInitial extends StudentsState {
  const StudentsInitial();
}

// ── Loading ───────────────────────────────────────────────────────────────

final class StudentsLoading extends StudentsState {
  const StudentsLoading();
}

// ── Loaded ────────────────────────────────────────────────────────────────

final class StudentsLoaded extends StudentsState {
  final List<StudentEntity> students;
  final String? filterStatus; // null = all
  final String? searchQuery;
  final bool hasMore; // pagination sentinel
  final bool isLoadingMore;
  final int pendingCount; // badge on T-03 tab

  const StudentsLoaded({
    required this.students,
    this.filterStatus,
    this.searchQuery,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.pendingCount = 0,
  });

  StudentsLoaded copyWith({
    List<StudentEntity>? students,
    String? filterStatus,
    bool clearFilter = false,
    String? searchQuery,
    bool clearSearch = false,
    bool? hasMore,
    bool? isLoadingMore,
    int? pendingCount,
  }) {
    return StudentsLoaded(
      students: students ?? this.students,
      filterStatus: clearFilter ? null : (filterStatus ?? this.filterStatus),
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      pendingCount: pendingCount ?? this.pendingCount,
    );
  }

  @override
  List<Object?> get props => [
        students,
        filterStatus,
        searchQuery,
        hasMore,
        isLoadingMore,
        pendingCount,
      ];
}

// ── Error ─────────────────────────────────────────────────────────────────

final class StudentsError extends StudentsState {
  final String message;

  const StudentsError(this.message);

  @override
  List<Object?> get props => [message];
}

// ── Action feedback (approve/reject/suspend) ──────────────────────────────

final class StudentActionInProgress extends StudentsState {
  final String studentId;
  final String action;

  const StudentActionInProgress({
    required this.studentId,
    required this.action,
  });

  @override
  List<Object?> get props => [studentId, action];
}

final class StudentActionSuccess extends StudentsState {
  final StudentEntity updatedStudent;
  final String action;

  const StudentActionSuccess({
    required this.updatedStudent,
    required this.action,
  });

  @override
  List<Object?> get props => [updatedStudent, action];
}

// ── Student 360° ──────────────────────────────────────────────────────────

final class Student360Loading extends StudentsState {
  const Student360Loading();
}

final class Student360Loaded extends StudentsState {
  final StudentEntity student;
  final Student360Entity stats;

  const Student360Loaded({required this.student, required this.stats});

  @override
  List<Object?> get props => [student, stats];
}

// ── Pending (T-03) ────────────────────────────────────────────────────────

final class PendingStudentsLoaded extends StudentsState {
  final List<StudentEntity> pending;

  const PendingStudentsLoaded({required this.pending});

  @override
  List<Object?> get props => [pending];
}

// ── Groups assignment (T-05) ──────────────────────────────────────────────

final class AssignGroupsLoaded extends StudentsState {
  final StudentEntity student;
  final List<StudentGroupInfo> currentGroups;
  final List<StudentGroupInfo> availableGroups;

  const AssignGroupsLoaded({
    required this.student,
    required this.currentGroups,
    required this.availableGroups,
  });

  @override
  List<Object?> get props => [student, currentGroups, availableGroups];
}
