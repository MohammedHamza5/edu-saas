import 'package:equatable/equatable.dart';
import '../../domain/entities/assignment_entity.dart';

sealed class AssignmentsState extends Equatable {
  const AssignmentsState();

  @override
  List<Object?> get props => [];
}

final class AssignmentsInitial extends AssignmentsState {
  const AssignmentsInitial();
}

final class AssignmentsLoading extends AssignmentsState {
  const AssignmentsLoading();
}

final class AssignmentsEmpty extends AssignmentsState {
  final String message;
  const AssignmentsEmpty({this.message = 'لا توجد واجبات حالياً'});

  @override
  List<Object?> get props => [message];
}

final class TeacherAssignmentsLoaded extends AssignmentsState {
  final String? groupId;
  final List<AssignmentEntity> assignments;
  final AssignmentEntity? selectedAssignment;
  final List<AssignmentSubmissionEntity> submissions;
  final bool isLoadingSubmissions;
  final bool isGrading;
  final bool isCreating;
  final bool actionSuccess;
  final String? message;

  const TeacherAssignmentsLoaded({
    this.groupId,
    required this.assignments,
    this.selectedAssignment,
    this.submissions = const [],
    this.isLoadingSubmissions = false,
    this.isGrading = false,
    this.isCreating = false,
    this.actionSuccess = false,
    this.message,
  });

  TeacherAssignmentsLoaded copyWith({
    String? groupId,
    List<AssignmentEntity>? assignments,
    AssignmentEntity? selectedAssignment,
    List<AssignmentSubmissionEntity>? submissions,
    bool? isLoadingSubmissions,
    bool? isGrading,
    bool? isCreating,
    bool? actionSuccess,
    String? message,
  }) {
    return TeacherAssignmentsLoaded(
      groupId: groupId ?? this.groupId,
      assignments: assignments ?? this.assignments,
      selectedAssignment: selectedAssignment ?? this.selectedAssignment,
      submissions: submissions ?? this.submissions,
      isLoadingSubmissions: isLoadingSubmissions ?? this.isLoadingSubmissions,
      isGrading: isGrading ?? this.isGrading,
      isCreating: isCreating ?? this.isCreating,
      actionSuccess: actionSuccess ?? this.actionSuccess,
      message: message,
    );
  }

  @override
  List<Object?> get props => [
        groupId,
        assignments,
        selectedAssignment,
        submissions,
        isLoadingSubmissions,
        isGrading,
        isCreating,
        actionSuccess,
        message,
      ];
}

final class StudentAssignmentsLoaded extends AssignmentsState {
  final List<AssignmentEntity> assignments;
  final AssignmentEntity? selectedAssignment;
  final bool isSubmitting;
  final bool submitSuccess;
  final String? message;

  const StudentAssignmentsLoaded({
    required this.assignments,
    this.selectedAssignment,
    this.isSubmitting = false,
    this.submitSuccess = false,
    this.message,
  });

  StudentAssignmentsLoaded copyWith({
    List<AssignmentEntity>? assignments,
    AssignmentEntity? selectedAssignment,
    bool? isSubmitting,
    bool? submitSuccess,
    String? message,
  }) {
    return StudentAssignmentsLoaded(
      assignments: assignments ?? this.assignments,
      selectedAssignment: selectedAssignment ?? this.selectedAssignment,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitSuccess: submitSuccess ?? this.submitSuccess,
      message: message,
    );
  }

  @override
  List<Object?> get props => [
        assignments,
        selectedAssignment,
        isSubmitting,
        submitSuccess,
        message,
      ];
}

final class AssignmentsError extends AssignmentsState {
  final String message;

  const AssignmentsError(this.message);

  @override
  List<Object?> get props => [message];
}
