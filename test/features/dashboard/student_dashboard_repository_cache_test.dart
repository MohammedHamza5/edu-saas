import 'package:edu_saas/core/errors/exceptions.dart';
import 'package:edu_saas/features/dashboard/data/datasources/student_dashboard_remote_datasource.dart';
import 'package:edu_saas/features/dashboard/data/repositories/student_dashboard_repository_impl.dart';
import 'package:edu_saas/features/dashboard/domain/entities/student_dashboard_stats.dart';
import 'package:edu_saas/features/dashboard/presentation/cubit/student_dashboard_cubit.dart';
import 'package:edu_saas/features/dashboard/presentation/cubit/student_dashboard_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockStudentDashboardRemoteDataSource implements StudentDashboardRemoteDataSource {
  int callCount = 0;
  bool shouldThrow = false;
  StudentDashboardStats mockStats = const StudentDashboardStats(
    attendancePercentage: 95,
    examAverage: 88,
    assignmentsSubmitted: 5,
    videoCompletionPercentage: 80,
    activeGroupName: 'SAT Prep Group',
    activeGroupLevel: 'SAT',
  );

  @override
  Future<StudentDashboardStats> getStudentDashboardStats(String studentId) async {
    callCount++;
    if (shouldThrow) {
      throw const ServerException('Failed to fetch from server');
    }
    return mockStats;
  }
}

void main() {
  group('StudentDashboardRepositoryImpl Cache & Performance Tests', () {
    late _MockStudentDashboardRemoteDataSource mockDataSource;
    late StudentDashboardRepositoryImpl repository;

    setUp(() {
      mockDataSource = _MockStudentDashboardRemoteDataSource();
      repository = StudentDashboardRepositoryImpl(remoteDataSource: mockDataSource);
    });

    test('Initial call fetches from remote data source and caches result', () async {
      final result = await repository.getStudentDashboardStats('student-123');

      expect(result.isSuccess, isTrue);
      expect(mockDataSource.callCount, equals(1));
      expect(result.dataOrNull?.activeGroupName, equals('SAT Prep Group'));
    });

    test('Immediate subsequent call returns cached stats without hitting remote data source (0ms)', () async {
      // First call: hits remote
      await repository.getStudentDashboardStats('student-123');
      expect(mockDataSource.callCount, equals(1));

      // Second call: served from memory cache
      final cachedResult = await repository.getStudentDashboardStats('student-123');
      expect(cachedResult.isSuccess, isTrue);
      expect(mockDataSource.callCount, equals(1)); // Still 1!
      expect(cachedResult.dataOrNull?.activeGroupName, equals('SAT Prep Group'));
    });

    test('forceRefresh: true bypasses in-memory cache and re-fetches from remote data source', () async {
      await repository.getStudentDashboardStats('student-123');
      expect(mockDataSource.callCount, equals(1));

      // Force refresh
      final refreshedResult = await repository.getStudentDashboardStats(
        'student-123',
        forceRefresh: true,
      );

      expect(refreshedResult.isSuccess, isTrue);
      expect(mockDataSource.callCount, equals(2)); // Re-fetched!
    });

    test('Different studentId does not reuse cache of another student', () async {
      await repository.getStudentDashboardStats('student-123');
      expect(mockDataSource.callCount, equals(1));

      await repository.getStudentDashboardStats('student-456');
      expect(mockDataSource.callCount, equals(2)); // Different student!
    });

    test('ServerException falls back to cached stats if available', () async {
      // Warm up cache
      await repository.getStudentDashboardStats('student-123');
      expect(mockDataSource.callCount, equals(1));

      // Server goes down
      mockDataSource.shouldThrow = true;

      // Call again with forceRefresh
      final result = await repository.getStudentDashboardStats('student-123', forceRefresh: true);
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.activeGroupName, equals('SAT Prep Group'));
    });
  });

  group('StudentDashboardCubit Smooth Transition Tests', () {
    late _MockStudentDashboardRemoteDataSource mockDataSource;
    late StudentDashboardRepositoryImpl repository;
    late StudentDashboardCubit cubit;

    setUp(() {
      mockDataSource = _MockStudentDashboardRemoteDataSource();
      repository = StudentDashboardRepositoryImpl(remoteDataSource: mockDataSource);
      cubit = StudentDashboardCubit(repository: repository);
    });

    tearDown(() {
      cubit.close();
    });

    test('Initial load emits Loading then Loaded', () async {
      final states = <StudentDashboardState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.loadDashboardStats('student-123');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(states.length, equals(2));
      expect(states[0], isA<StudentDashboardLoading>());
      expect(states[1], isA<StudentDashboardLoaded>());

      await sub.cancel();
    });

    test('Subsequent load does not emit Loading to prevent screen flicker', () async {
      // First load
      await cubit.loadDashboardStats('student-123');
      expect(cubit.state, isA<StudentDashboardLoaded>());

      final states = <StudentDashboardState>[];
      final sub = cubit.stream.listen(states.add);

      // Return to dashboard / subsequent load
      await cubit.loadDashboardStats('student-123');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Should NOT emit StudentDashboardLoading again
      expect(states.whereType<StudentDashboardLoading>(), isEmpty);

      await sub.cancel();
    });
  });
}
