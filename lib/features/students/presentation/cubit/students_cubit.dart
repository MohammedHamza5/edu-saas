import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/cache_manager.dart';
import '../../domain/entities/student_360_entity.dart';
import '../../domain/entities/student_entity.dart';
import '../../domain/repositories/students_repository.dart';
import 'students_state.dart';

class StudentsCubit extends Cubit<StudentsState> {
  final StudentsRepository _repository;

  // Pagination state
  int _currentPage = 0;
  static const int _pageSize = 25;
  String? _currentStatus;
  String? _currentSearch;

  // ── Cache keys ──────────────────────────────────────────────────────────
  static const _cacheKeyPending = 'pending';

  StudentsCubit({required StudentsRepository repository})
      : _repository = repository,
        super(const StudentsInitial());

  // ── Load list ─────────────────────────────────────────────────────────────

  Future<void> loadStudents({
    String? status,
    String? searchQuery,
    bool refresh = false,
  }) async {
    if (refresh) {
      _currentPage = 0;
      _currentStatus = status;
      _currentSearch = searchQuery;
    } else {
      _currentStatus = status ?? _currentStatus;
      _currentSearch = searchQuery ?? _currentSearch;
      _currentPage = 0;
    }

    final cacheKey = _buildCacheKey();

    // ── Stale-While-Revalidate: show cached data instantly ──────────────
    final cachedPayload = AppCache.students.getStale(cacheKey);
    if (cachedPayload is _StudentsCachePayload) {
      emit(StudentsLoaded(
        students: cachedPayload.students,
        filterStatus: _currentStatus,
        searchQuery: _currentSearch,
        hasMore: cachedPayload.hasMore,
        pendingCount: cachedPayload.pendingCount,
      ));
      // If cache is still fresh and not an explicit refresh, skip network
      if (!refresh && AppCache.students.has(cacheKey)) return;
      // Otherwise continue to refresh silently (no loading state emitted)
    } else {
      emit(const StudentsLoading());
    }

    // ── Parallel fetch: students + pending count simultaneously ─────────
    final studentsFuture = _repository.getStudents(
      status: _currentStatus,
      searchQuery: _currentSearch,
      page: 0,
      pageSize: _pageSize,
    );
    final pendingFuture = _repository.getPendingStudents();

    final studentsResult = await studentsFuture;
    final pendingResult = await pendingFuture;

    if (isClosed) return;

    int pending = 0;
    pendingResult.when(
      onSuccess: (List<StudentEntity> list) => pending = list.length,
      onFailure: (_) {},
    );

    studentsResult.when(
      onSuccess: (List<StudentEntity> students) {
        if (!isClosed) {
          // Cache the result
          AppCache.students.put(cacheKey, _StudentsCachePayload(
            students: students,
            hasMore: students.length == _pageSize,
            pendingCount: pending,
          ));

          emit(StudentsLoaded(
            students: students,
            filterStatus: _currentStatus,
            searchQuery: _currentSearch,
            hasMore: students.length == _pageSize,
            pendingCount: pending,
          ));
        }
      },
      onFailure: (Failure failure) {
        if (!isClosed) emit(StudentsError(failure.message));
      },
    );
  }

  /// Silently refreshes data in the background without showing loading.
  /// Perfect for stale-while-revalidate on page revisits.
  Future<void> silentRefresh() async {
    if (state is! StudentsLoaded && state is! StudentsInitial) return;

    final cacheKey = _buildCacheKey();
    if (AppCache.students.has(cacheKey)) return; // Still fresh, skip

    final studentsFuture = _repository.getStudents(
      status: _currentStatus,
      searchQuery: _currentSearch,
      page: 0,
      pageSize: _pageSize,
    );
    final pendingFuture = _repository.getPendingStudents();

    final studentsResult = await studentsFuture;
    final pendingResult = await pendingFuture;

    if (isClosed) return;

    int pending = 0;
    pendingResult.when(
      onSuccess: (List<StudentEntity> list) => pending = list.length,
      onFailure: (_) {},
    );

    studentsResult.when(
      onSuccess: (List<StudentEntity> students) {
        if (!isClosed) {
          AppCache.students.put(cacheKey, _StudentsCachePayload(
            students: students,
            hasMore: students.length == _pageSize,
            pendingCount: pending,
          ));

          emit(StudentsLoaded(
            students: students,
            filterStatus: _currentStatus,
            searchQuery: _currentSearch,
            hasMore: students.length == _pageSize,
            pendingCount: pending,
          ));
        }
      },
      onFailure: (_) {}, // Silent — don't show error on background refresh
    );
  }

  // ── Load more (pagination) ─────────────────────────────────────────────

  Future<void> loadMore() async {
    final current = state;
    if (current is! StudentsLoaded) return;
    if (!current.hasMore || current.isLoadingMore) return;

    emit(current.copyWith(isLoadingMore: true));
    _currentPage++;

    final result = await _repository.getStudents(
      status: _currentStatus,
      searchQuery: _currentSearch,
      page: _currentPage,
      pageSize: _pageSize,
    );

    if (isClosed) return;

    result.when(
      onSuccess: (newStudents) {
        if (!isClosed) {
          emit(current.copyWith(
            students: [...current.students, ...newStudents],
            hasMore: newStudents.length == _pageSize,
            isLoadingMore: false,
          ));
        }
      },
      onFailure: (failure) {
        _currentPage--;
        if (!isClosed) {
          emit(current.copyWith(isLoadingMore: false));
        }
      },
    );
  }

  // ── Filter ────────────────────────────────────────────────────────────────

  void setFilter(String? status) {
    loadStudents(status: status, refresh: true);
  }

  // ── Search ────────────────────────────────────────────────────────────────

  void search(String query) {
    final trimmed = query.trim();
    final newSearch = trimmed.isEmpty ? null : trimmed;
    if (newSearch == _currentSearch) return;
    _currentSearch = newSearch;
    loadStudents(searchQuery: _currentSearch, refresh: true);
  }

  // ── Approve / Reject / Suspend / Activate ─────────────────────────────────

  Future<bool> changeStatus({
    required String studentId,
    required String action, // approve | reject | suspend | activate
  }) async {
    final prev = state;

    emit(StudentActionInProgress(studentId: studentId, action: action));

    final result = await _repository.changeStudentStatus(
      studentId: studentId,
      action: action,
    );

    if (isClosed) return false;

    return result.when(
      onSuccess: (updated) {
        if (!isClosed) {
          // Invalidate cache after status change
          AppCache.students.clear();

          emit(StudentActionSuccess(updatedStudent: updated, action: action));
          // Refresh the appropriate list to reflect new status
          if (prev is PendingStudentsLoaded) {
            loadPendingStudents();
          } else {
            loadStudents(
              status: _currentStatus,
              searchQuery: _currentSearch,
              refresh: true,
            );
          }
        }
        return true;
      },
      onFailure: (failure) {
        if (!isClosed) {
          // Restore previous state and bubble up error
          emit(prev);
          emit(StudentsError(failure.message));
        }
        return false;
      },
    );
  }

  // ── Pending students (T-03) ───────────────────────────────────────────────

  Future<void> loadPendingStudents() async {
    // ── Stale-While-Revalidate ────────────────────────────────────────────
    final cached = AppCache.students.getStale(_cacheKeyPending);
    if (cached is List<StudentEntity>) {
      emit(PendingStudentsLoaded(pending: cached));
      if (AppCache.students.has(_cacheKeyPending)) return;
      // Continue to refresh silently
    } else {
      emit(const StudentsLoading());
    }

    final result = await _repository.getPendingStudents();
    if (isClosed) return;

    result.when(
      onSuccess: (list) {
        if (!isClosed) {
          AppCache.students.put(_cacheKeyPending, list);
          emit(PendingStudentsLoaded(pending: list));
        }
      },
      onFailure: (f) {
        if (!isClosed) emit(StudentsError(f.message));
      },
    );
  }

  // ── Student 360° (T-04) ───────────────────────────────────────────────────

  Future<void> loadStudent360(String studentId) async {
    final cacheKey = 'student_360_$studentId';

    // ⚡ Fast path: Return cached 360 profile if available
    final cached = AppCache.students.get(cacheKey) as Student360Loaded?;
    if (cached != null) {
      AppLogger.d('StudentsCubit', '⚡ Cache hit for student 360: $studentId');
      emit(cached);
      return;
    }

    emit(const Student360Loading());

    // Parallel fetch: student + stats
    final results = await Future.wait([
      _repository.getStudent(studentId),
      _repository.getStudent360(studentId),
    ]);

    if (isClosed) return;

    final studentResult = results[0] as Result<StudentEntity>;
    final statsResult = results[1] as Result<Student360Entity>;

    if (studentResult.isFailure) {
      final msg = studentResult.failureOrNull!.message;
      AppLogger.e('StudentsCubit', 'Failed to load student profile ($studentId): $msg');
      if (!isClosed) emit(StudentsError(msg));
      return;
    }
    final student = studentResult.data;

    final Student360Entity stats;
    if (statsResult.isSuccess) {
      stats = statsResult.data;
    } else {
      AppLogger.w(
        'StudentsCubit',
        'Student 360 stats query non-fatal fallback for $studentId: ${statsResult.failureOrNull?.message}',
      );
      // Resilient fallback: baseline stats entity so teacher can view student details
      stats = Student360Entity(studentId: studentId);
    }

    if (!isClosed) {
      final loadedState = Student360Loaded(student: student, stats: stats);
      AppCache.students.put(cacheKey, loadedState);
      emit(loadedState);
    }
  }

  // ── Assign Groups (T-05) ──────────────────────────────────────────────────

  Future<void> loadAssignGroups(String studentId) async {
    emit(const StudentsLoading());

    // Parallel fetch: student + stats + available groups
    final results = await Future.wait([
      _repository.getStudent(studentId),
      _repository.getStudent360(studentId),
      _repository.getAvailableGroupsForStudent(studentId),
    ]);

    if (isClosed) return;

    final studentResult = results[0] as Result<StudentEntity>;
    final stats360Result = results[1] as Result<Student360Entity>;
    final availableResult = results[2] as Result<List<StudentGroupInfo>>;

    if (studentResult.isFailure) {
      if (!isClosed) emit(StudentsError(studentResult.failureOrNull!.message));
      return;
    }
    final student = studentResult.data;

    final currentGroups = stats360Result.dataOrNull?.groups ?? <StudentGroupInfo>[];
    final available = availableResult.dataOrNull ?? <StudentGroupInfo>[];

    if (!isClosed) {
      emit(AssignGroupsLoaded(
        student: student,
        currentGroups: currentGroups,
        availableGroups: available,
      ));
    }
  }

  Future<bool> toggleGroupMembership({
    required String studentId,
    required String groupId,
    required bool add,
  }) async {
    final result = await _repository.assignStudentToGroup(
      studentId: studentId,
      groupId: groupId,
      add: add,
    );

    if (isClosed) return false;

    return result.when(
      onSuccess: (_) {
        if (!isClosed) {
          // Invalidate caches
          AppCache.students.clear();
          AppCache.groups.clear();
          // Reload assign groups screen
          loadAssignGroups(studentId);
        }
        return true;
      },
      onFailure: (f) {
        if (!isClosed) emit(StudentsError(f.message));
        return false;
      },
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _buildCacheKey() {
    return 'list_${_currentStatus ?? 'all'}_${_currentSearch ?? ''}_p$_currentPage';
  }
}

/// Internal cache payload for students list data.
class _StudentsCachePayload {
  final List<StudentEntity> students;
  final bool hasMore;
  final int pendingCount;

  const _StudentsCachePayload({
    required this.students,
    required this.hasMore,
    required this.pendingCount,
  });
}
