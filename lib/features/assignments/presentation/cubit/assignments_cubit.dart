import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/cache_manager.dart';
import '../../domain/entities/assignment_entity.dart';
import '../../domain/repositories/assignments_repository.dart';
import 'assignments_state.dart';

class AssignmentsCubit extends Cubit<AssignmentsState> {
  final AssignmentsRepository _repository;

  static const int _pageSize = 15;
  int _teacherPage = 0;
  int _studentPage = 0;

  AssignmentsCubit({required AssignmentsRepository repository})
      : _repository = repository,
        super(const AssignmentsInitial());

  /// Loads assignments for a specific group (Teacher flow) with instant SWR cache
  Future<void> loadGroupAssignments(String groupId, {bool forceRefresh = false}) async {
    _teacherPage = 0;
    final cacheKey = 'teacher_group_$groupId';
    if (forceRefresh) {
      AppCache.assignments.invalidate(cacheKey);
    }

    // ── Stale-While-Revalidate: Instant display from memory cache ──────────
    final cached = AppCache.assignments.getStale(cacheKey);
    if (cached is List<AssignmentEntity>) {
      emit(TeacherAssignmentsLoaded(
        groupId: groupId,
        assignments: cached,
        hasMore: cached.length >= _pageSize,
      ));
      if (!forceRefresh && AppCache.assignments.has(cacheKey)) return; // Fresh cache, skip network
    } else {
      emit(const AssignmentsLoading());
    }

    final result = await _repository.getGroupAssignments(
      groupId,
      page: 0,
      pageSize: _pageSize,
    );

    result.when(
      onSuccess: (assignments) {
        AppCache.assignments.put(cacheKey, assignments);
        emit(TeacherAssignmentsLoaded(
          groupId: groupId,
          assignments: assignments,
          hasMore: assignments.length == _pageSize,
          isLoadingMore: false,
        ));
      },
      onFailure: (failure) {
        if (state is! TeacherAssignmentsLoaded) {
          emit(AssignmentsError(failure.message));
        }
      },
    );
  }

  /// Loads next page of teacher assignments on scroll (Infinite Scroll)
  Future<void> loadMoreTeacherAssignments() async {
    final currentState = state;
    if (currentState is! TeacherAssignmentsLoaded) return;
    if (!currentState.hasMore || currentState.isLoadingMore || currentState.groupId == null) return;

    emit(currentState.copyWith(isLoadingMore: true));
    final nextPage = _teacherPage + 1;

    final result = await _repository.getGroupAssignments(
      currentState.groupId!,
      page: nextPage,
      pageSize: _pageSize,
    );

    if (isClosed) return;

    result.when(
      onSuccess: (newAssignments) {
        _teacherPage = nextPage;
        final allAssignments = [...currentState.assignments, ...newAssignments];
        AppCache.assignments.put('teacher_group_${currentState.groupId}', allAssignments);
        emit(currentState.copyWith(
          assignments: allAssignments,
          hasMore: newAssignments.length == _pageSize,
          isLoadingMore: false,
        ));
      },
      onFailure: (failure) {
        emit(currentState.copyWith(isLoadingMore: false));
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
        // Refresh assignments list and bust cache
        AppCache.assignments.invalidate('teacher_group_$groupId');
        loadGroupAssignments(groupId, forceRefresh: true);
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
  Future<void> loadStudentAssignments({bool forceRefresh = false}) async {
    _studentPage = 0;
    const cacheKey = 'student_assignments_all';
    if (forceRefresh) {
      AppCache.assignments.invalidate(cacheKey);
    }

    // ── Stale-While-Revalidate: Instant display from memory cache ──────────
    final cached = AppCache.assignments.getStale(cacheKey);
    if (cached is List<AssignmentEntity>) {
      if (cached.isEmpty) {
        emit(const AssignmentsEmpty(message: 'لا توجد واجبات مطلوبة حالياً'));
      } else {
        emit(StudentAssignmentsLoaded(
          assignments: cached,
          hasMore: cached.length >= _pageSize,
        ));
      }
      if (!forceRefresh && AppCache.assignments.has(cacheKey)) return; // Fresh cache, skip network
    } else {
      emit(const AssignmentsLoading());
    }

    final result = await _repository.getStudentAssignments(
      page: 0,
      pageSize: _pageSize,
    );

    result.when(
      onSuccess: (assignments) {
        AppCache.assignments.put(cacheKey, assignments);
        if (assignments.isEmpty) {
          emit(const AssignmentsEmpty(message: 'لا توجد واجبات مطلوبة حالياً'));
        } else {
          emit(StudentAssignmentsLoaded(
            assignments: assignments,
            hasMore: assignments.length == _pageSize,
            isLoadingMore: false,
          ));
        }
      },
      onFailure: (failure) {
        if (state is! StudentAssignmentsLoaded) {
          emit(AssignmentsError(failure.message));
        }
      },
    );
  }

  /// Loads next page of student assignments on scroll (Infinite Scroll)
  Future<void> loadMoreStudentAssignments() async {
    final currentState = state;
    if (currentState is! StudentAssignmentsLoaded) return;
    if (!currentState.hasMore || currentState.isLoadingMore) return;

    emit(currentState.copyWith(isLoadingMore: true));
    final nextPage = _studentPage + 1;

    final result = await _repository.getStudentAssignments(
      page: nextPage,
      pageSize: _pageSize,
    );

    if (isClosed) return;

    result.when(
      onSuccess: (newAssignments) {
        _studentPage = nextPage;
        final allAssignments = [...currentState.assignments, ...newAssignments];
        AppCache.assignments.put('student_assignments_all', allAssignments);
        emit(currentState.copyWith(
          assignments: allAssignments,
          hasMore: newAssignments.length == _pageSize,
          isLoadingMore: false,
        ));
      },
      onFailure: (failure) {
        emit(currentState.copyWith(isLoadingMore: false));
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
