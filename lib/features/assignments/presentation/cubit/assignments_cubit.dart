import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/cache_manager.dart';
import '../../domain/entities/assignment_entity.dart';
import '../../domain/repositories/assignments_repository.dart';
import 'assignments_state.dart';

class AssignmentsCubit extends Cubit<AssignmentsState> {
  final AssignmentsRepository _repository;

  AssignmentsCubit({required AssignmentsRepository repository})
      : _repository = repository,
        super(const AssignmentsInitial());

  /// Loads assignments for a specific group (Teacher flow) with instant SWR cache
  Future<void> loadGroupAssignments(String groupId) async {
    final cacheKey = 'teacher_group_$groupId';

    // ── Stale-While-Revalidate: Instant display from memory cache ──────────
    final cached = AppCache.assignments.getStale(cacheKey);
    if (cached is List<AssignmentEntity>) {
      emit(TeacherAssignmentsLoaded(
        groupId: groupId,
        assignments: cached,
      ));
      if (AppCache.assignments.has(cacheKey)) return; // Fresh cache, skip network
    } else {
      emit(const AssignmentsLoading());
    }

    final result = await _repository.getGroupAssignments(groupId);

    result.when(
      onSuccess: (assignments) {
        AppCache.assignments.put(cacheKey, assignments);
        emit(TeacherAssignmentsLoaded(
          groupId: groupId,
          assignments: assignments,
        ));
      },
      onFailure: (failure) {
        if (state is! TeacherAssignmentsLoaded) {
          emit(AssignmentsError(failure.message));
        }
      },
    );
  }

  /// Selects an assignment to view its submissions (Teacher flow)
  Future<void> selectAssignmentForTeacher(AssignmentEntity assignment) async {
    final currentState = state;
    if (currentState is! TeacherAssignmentsLoaded) return;

    emit(currentState.copyWith(
      selectedAssignment: assignment,
      isLoadingSubmissions: true,
    ));

    final result = await _repository.getSubmissions(assignment.id);

    result.when(
      onSuccess: (submissions) {
        emit(currentState.copyWith(
          selectedAssignment: assignment,
          submissions: submissions,
          isLoadingSubmissions: false,
        ));
      },
      onFailure: (failure) {
        emit(currentState.copyWith(
          selectedAssignment: assignment,
          isLoadingSubmissions: false,
          message: failure.message,
        ));
      },
    );
  }

  /// Creates a new assignment for a group (Teacher flow)
  Future<bool> createAssignment({
    required String groupId,
    required String title,
    String? instructions,
    DateTime? dueAt,
    bool allowLateSubmission = false,
    int maxScore = 100,
  }) async {
    final currentState = state;
    if (currentState is TeacherAssignmentsLoaded) {
      emit(currentState.copyWith(isCreating: true));
    } else {
      emit(const AssignmentsLoading());
    }

    final result = await _repository.createAssignment(
      groupId: groupId,
      title: title,
      instructions: instructions,
      dueAt: dueAt,
      allowLateSubmission: allowLateSubmission,
      maxScore: maxScore,
    );

    return result.when(
      onSuccess: (created) {
        // Refresh assignments list
        loadGroupAssignments(groupId);
        return true;
      },
      onFailure: (failure) {
        if (currentState is TeacherAssignmentsLoaded) {
          emit(currentState.copyWith(
            isCreating: false,
            message: failure.message,
          ));
        } else {
          emit(AssignmentsError(failure.message));
        }
        return false;
      },
    );
  }

  /// Grades a student submission (Teacher flow)
  Future<bool> gradeSubmission({
    required String submissionId,
    required int score,
    String? feedback,
  }) async {
    final currentState = state;
    if (currentState is! TeacherAssignmentsLoaded) return false;

    emit(currentState.copyWith(isGrading: true));

    final result = await _repository.gradeSubmission(
      submissionId: submissionId,
      score: score,
      feedback: feedback,
    );

    return result.when(
      onSuccess: (updatedSub) {
        final updatedSubmissions = currentState.submissions.map((s) {
          return s.id == submissionId ? updatedSub : s;
        }).toList();

        // Also update reviewedCount in the selected assignment if applicable
        AssignmentEntity? updatedAssignment = currentState.selectedAssignment;
        if (updatedAssignment != null) {
          final newReviewedCount = updatedSubmissions
              .where((s) => s.status == SubmissionStatus.reviewed)
              .length;
          updatedAssignment = updatedAssignment.copyWith(
            reviewedCount: newReviewedCount,
          );
        }

        emit(currentState.copyWith(
          submissions: updatedSubmissions,
          selectedAssignment: updatedAssignment,
          isGrading: false,
          actionSuccess: true,
          message: 'تم حفظ التقييم بنجاح',
        ));
        return true;
      },
      onFailure: (failure) {
        emit(currentState.copyWith(
          isGrading: false,
          actionSuccess: false,
          message: failure.message,
        ));
        return false;
      },
    );
  }

  /// Loads all assignments for the currently logged-in student (Student flow) with instant SWR cache
  Future<void> loadStudentAssignments() async {
    const cacheKey = 'student_assignments_all';

    // ── Stale-While-Revalidate: Instant display from memory cache ──────────
    final cached = AppCache.assignments.getStale(cacheKey);
    if (cached is List<AssignmentEntity>) {
      if (cached.isEmpty) {
        emit(const AssignmentsEmpty(message: 'لا توجد واجبات مطلوبة حالياً'));
      } else {
        emit(StudentAssignmentsLoaded(assignments: cached));
      }
      if (AppCache.assignments.has(cacheKey)) return; // Fresh cache, skip network
    } else {
      emit(const AssignmentsLoading());
    }

    final result = await _repository.getStudentAssignments();

    result.when(
      onSuccess: (assignments) {
        AppCache.assignments.put(cacheKey, assignments);
        if (assignments.isEmpty) {
          emit(const AssignmentsEmpty(message: 'لا توجد واجبات مطلوبة حالياً'));
        } else {
          emit(StudentAssignmentsLoaded(assignments: assignments));
        }
      },
      onFailure: (failure) {
        if (state is! StudentAssignmentsLoaded) {
          emit(AssignmentsError(failure.message));
        }
      },
    );
  }

  /// Selects an assignment to view details / submit (Student flow)
  void selectAssignmentForStudent(AssignmentEntity assignment) {
    final currentState = state;
    if (currentState is StudentAssignmentsLoaded) {
      emit(currentState.copyWith(selectedAssignment: assignment));
    }
  }

  /// Submits files for an assignment (Student flow)
  Future<bool> submitAssignment({
    required String assignmentId,
    required List<({String fileName, List<int> bytes, String mimeType})> files,
  }) async {
    final currentState = state;
    if (currentState is! StudentAssignmentsLoaded) return false;

    emit(currentState.copyWith(isSubmitting: true));

    final result = await _repository.submitAssignment(
      assignmentId: assignmentId,
      files: files,
    );

    return result.when(
      onSuccess: (submission) {
        // Update the assignment in student assignments list
        final updatedAssignments = currentState.assignments.map((a) {
          if (a.id == assignmentId) {
            return a.copyWith(mySubmission: submission);
          }
          return a;
        }).toList();

        final updatedSelected = currentState.selectedAssignment?.id == assignmentId
            ? currentState.selectedAssignment!.copyWith(mySubmission: submission)
            : currentState.selectedAssignment;

        emit(currentState.copyWith(
          assignments: updatedAssignments,
          selectedAssignment: updatedSelected,
          isSubmitting: false,
          submitSuccess: true,
          message: 'تم تسليم الواجب بنجاح!',
        ));
        return true;
      },
      onFailure: (failure) {
        emit(currentState.copyWith(
          isSubmitting: false,
          submitSuccess: false,
          message: failure.message,
        ));
        return false;
      },
    );
  }

  /// Requests a temporary signed URL for a file
  Future<String?> getFileSignedUrl(String storagePath) async {
    final result = await _repository.getSubmissionFileSignedUrl(storagePath);
    return result.when(
      onSuccess: (url) => url,
      onFailure: (_) => null,
    );
  }
}
