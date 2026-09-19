import 'package:edu_saas/core/di/injection_container.dart';
import 'package:edu_saas/core/errors/failures.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/features/attendance/data/models/attendance_model.dart';
import 'package:edu_saas/features/attendance/domain/entities/attendance_entity.dart';
import 'package:edu_saas/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:edu_saas/features/attendance/presentation/cubit/attendance_cubit.dart';
import 'package:edu_saas/features/attendance/presentation/cubit/attendance_state.dart';
import 'package:edu_saas/features/attendance/presentation/pages/student_attendance_page.dart';
import 'package:edu_saas/features/attendance/presentation/pages/teacher_attendance_page.dart';
import 'package:edu_saas/features/attendance/presentation/widgets/attendance_stat_card.dart';
import 'package:edu_saas/features/attendance/presentation/widgets/attendance_status_badge.dart';
import 'package:edu_saas/features/auth/domain/entities/user_entity.dart';
import 'package:edu_saas/features/auth/domain/repositories/auth_repository.dart';
import 'package:edu_saas/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:edu_saas/features/groups/domain/entities/group_entity.dart';
import 'package:edu_saas/features/groups/domain/entities/group_member_entity.dart';
import 'package:edu_saas/features/groups/domain/repositories/groups_repository.dart';
import 'package:edu_saas/features/groups/presentation/cubit/groups_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAttendanceRepository implements AttendanceRepository {
  List<StudentAttendanceItem> mockStudents = [
    const StudentAttendanceItem(
      studentId: 'student-1',
      studentName: 'أحمد علي',
      phone: '01000000001',
      status: AttendanceStatus.present,
    ),
    const StudentAttendanceItem(
      studentId: 'student-2',
      studentName: 'سارة محمد',
      phone: '01000000002',
      status: AttendanceStatus.absent,
    ),
  ];

  List<AttendanceEntity> mockHistory = [
    AttendanceEntity(
      id: 'att-1',
      tenantId: 'tenant-1',
      groupId: 'group-1',
      studentId: 'student-1',
      date: DateTime(2026, 3, 1),
      status: AttendanceStatus.present,
      markedAt: DateTime.now(),
      groupName: 'SAT Math Advanced',
    ),
    AttendanceEntity(
      id: 'att-2',
      tenantId: 'tenant-1',
      groupId: 'group-1',
      studentId: 'student-1',
      date: DateTime(2026, 3, 2),
      status: AttendanceStatus.late,
      markedAt: DateTime.now(),
      note: 'تأخر 10 دقائق بعذر',
      groupName: 'SAT Math Advanced',
    ),
  ];

  bool shouldFail = false;

  @override
  Future<Result<List<StudentAttendanceItem>>> getGroupStudentsWithAttendance({
    required String groupId,
    required DateTime date,
  }) async {
    if (shouldFail) {
      return const FailureResult(ServerFailure('Database error'));
    }
    return Success(mockStudents);
  }

  @override
  Future<Result<void>> saveGroupAttendance({
    required String groupId,
    required DateTime date,
    required List<StudentAttendanceItem> items,
  }) async {
    if (shouldFail) {
      return const FailureResult(ServerFailure('Save failed'));
    }
    mockStudents = items;
    return const Success(null);
  }

  @override
  Future<Result<List<AttendanceEntity>>> getStudentAttendanceHistory({
    required String studentId,
    String? groupId,
    int? page,
    int? pageSize,
  }) async {
    if (shouldFail) {
      return const FailureResult(ServerFailure('History error'));
    }
    return Success(mockHistory);
  }

  @override
  Future<Result<AttendanceStats>> getStudentAttendanceStats({
    required String studentId,
    String? groupId,
  }) async {
    if (shouldFail) {
      return const FailureResult(ServerFailure('Stats error'));
    }
    return const Success(AttendanceStats(
      totalSessions: 10,
      presentCount: 8,
      absentCount: 1,
      lateCount: 1,
      excusedCount: 0,
    ));
  }
}

class FakeGroupsRepository implements GroupsRepository {
  @override
  Future<Result<List<GroupEntity>>> getGroups() async {
    return const Success([
      GroupEntity(
        id: 'group-1',
        tenantId: 'tenant-1',
        name: 'SAT Math Advanced',
        level: 'SAT',
        previousContentAccess: 'deny',
        status: 'active',
      ),
    ]);
  }

  @override
  Future<Result<GroupEntity>> createGroup({
    required String name,
    required String level,
    String? description,
    required String previousContentAccess,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Result<GroupEntity>> updateGroup({
    required String id,
    String? name,
    String? level,
    String? description,
    String? previousContentAccess,
    String? status,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Result<List<GroupMemberEntity>>> getGroupMembers(String groupId) async =>
      const Success([]);

  @override
  Future<Result<GroupMemberEntity>> addMemberToGroup({
    required String groupId,
    required String studentId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Result<void>> removeMemberFromGroup({
    required String groupId,
    required String studentId,
  }) async =>
      throw UnimplementedError();
}

class FakeAuthRepository implements AuthRepository {
  @override
  Future<Result<UserEntity?>> getCurrentUser() async {
    return const Success(UserEntity(
      id: 'student-1',
      tenantId: 'tenant-1',
      role: UserRole.student,
      status: UserStatus.active,
      fullName: 'أحمد علي',
      email: 'ahmed@test.com',
    ));
  }

  @override
  Future<Result<UserEntity>> signInWithEmail({required String email, required String password}) async =>
      throw UnimplementedError();
  @override
  Future<Result<UserEntity>> signUpStudent({required String email, required String password, required String fullName, required String phone, String? parentPhone, required String tenantId}) async =>
      throw UnimplementedError();
  @override
  Future<Result<void>> signOut() async => const Success(null);
  @override
  Future<Result<void>> resetPasswordForEmail(String email) async => const Success(null);
}

void main() {
  setUpAll(() async {
    // Initialize container with fakes for widget testing
    InjectionContainer.attendanceRepository = FakeAttendanceRepository();
  });

  group('Attendance Domain & Model Tests', () {
    test('AttendanceStatus parses correctly and returns labels', () {
      expect(AttendanceStatus.fromString('present'), AttendanceStatus.present);
      expect(AttendanceStatus.fromString('absent'), AttendanceStatus.absent);
      expect(AttendanceStatus.fromString('late'), AttendanceStatus.late);
      expect(AttendanceStatus.fromString('excused'), AttendanceStatus.excused);
      expect(AttendanceStatus.fromString('unknown'), AttendanceStatus.present);

      expect(AttendanceStatus.present.labelAr, 'حاضر');
      expect(AttendanceStatus.absent.labelAr, 'غائب');
      expect(AttendanceStatus.late.labelAr, 'متأخر');
      expect(AttendanceStatus.excused.labelAr, 'معذور');
    });

    test('AttendanceStats calculates percentages accurately', () {
      const stats = AttendanceStats(
        totalSessions: 10,
        presentCount: 7,
        absentCount: 1,
        lateCount: 1,
        excusedCount: 1,
      );

      // Compliant percentage: (present + excused) / total = (7 + 1) / 10 = 80.0%
      expect(stats.attendancePercentage, 80.0);
      // Strict present percentage: 7 / 10 = 70.0%
      expect(stats.strictPresentPercentage, 70.0);
    });

    test('AttendanceModel fromJson and toJson roundtrip properly', () {
      final json = {
        'id': 'att-100',
        'tenant_id': 'tenant-uuid',
        'group_id': 'group-uuid',
        'student_id': 'student-uuid',
        'date': '2026-03-08',
        'status': 'present',
        'marked_at': '2026-03-08T10:00:00.000Z',
        'marked_by': 'teacher-uuid',
        'note': 'حضور متميز',
        'student_name': 'محمد حمزة',
        'group_name': 'Math Basics',
      };

      final model = AttendanceModel.fromJson(json);
      expect(model.id, 'att-100');
      expect(model.studentName, 'محمد حمزة');
      expect(model.status, AttendanceStatus.present);

      final upsertMap = AttendanceModel.toUpsertMap(
        tenantId: 'tenant-uuid',
        groupId: 'group-uuid',
        studentId: 'student-uuid',
        date: DateTime(2026, 3, 8),
        status: AttendanceStatus.late,
        markedBy: 'teacher-uuid',
        note: 'تأخير 5 دقائق',
      );

      expect(upsertMap['date'], '2026-03-08');
      expect(upsertMap['status'], 'late');
      expect(upsertMap['note'], 'تأخير 5 دقائق');
    });
  });

  group('AttendanceCubit State Tests', () {
    late FakeAttendanceRepository repository;
    late AttendanceCubit cubit;

    setUp(() {
      repository = FakeAttendanceRepository();
      cubit = AttendanceCubit(repository: repository);
    });

    tearDown(() {
      cubit.close();
    });

    test('initial state is AttendanceInitial', () {
      expect(cubit.state, isA<AttendanceInitial>());
    });

    test('loadGroupAttendance emits Loading then TeacherAttendanceLoaded', () async {
      final future = cubit.loadGroupAttendance(
        groupId: 'group-1',
        date: DateTime(2026, 3, 8),
      );

      expect(cubit.state, isA<AttendanceLoading>());
      await future;

      expect(cubit.state, isA<TeacherAttendanceLoaded>());
      final loaded = cubit.state as TeacherAttendanceLoaded;
      expect(loaded.students.length, 2);
      expect(loaded.currentStats.presentCount, 1);
      expect(loaded.currentStats.absentCount, 1);
    });

    test('updateStudentStatus modifies status locally', () async {
      await cubit.loadGroupAttendance(
        groupId: 'group-1',
        date: DateTime(2026, 3, 8),
      );

      cubit.updateStudentStatus('student-2', AttendanceStatus.present);

      final loaded = cubit.state as TeacherAttendanceLoaded;
      final student2 = loaded.students.firstWhere((s) => s.studentId == 'student-2');
      expect(student2.status, AttendanceStatus.present);
      expect(loaded.currentStats.presentCount, 2);
    });

    test('markAll sets all students to specified status', () async {
      await cubit.loadGroupAttendance(
        groupId: 'group-1',
        date: DateTime(2026, 3, 8),
      );

      cubit.markAll(AttendanceStatus.present);

      final loaded = cubit.state as TeacherAttendanceLoaded;
      expect(loaded.students.every((s) => s.status == AttendanceStatus.present), isTrue);
      expect(loaded.currentStats.presentCount, 2);
      expect(loaded.currentStats.absentCount, 0);
    });

    test('saveAttendance commits atomically and sets saveSuccess true', () async {
      await cubit.loadGroupAttendance(
        groupId: 'group-1',
        date: DateTime(2026, 3, 8),
      );

      await cubit.saveAttendance();

      final loaded = cubit.state as TeacherAttendanceLoaded;
      expect(loaded.saveSuccess, isTrue);
      expect(loaded.isSaving, isFalse);
    });

    test('loadStudentAttendance emits StudentAttendanceLoaded with stats and pagination state', () async {
      await cubit.loadStudentAttendance(studentId: 'student-1');

      expect(cubit.state, isA<StudentAttendanceLoaded>());
      final loaded = cubit.state as StudentAttendanceLoaded;
      expect(loaded.records.length, 2);
      expect(loaded.stats.attendancePercentage, 80.0);
      expect(loaded.hasMore, isFalse);
      expect(loaded.isLoadingMore, isFalse);
    });
  });

  group('Attendance Widgets UI Tests', () {
    testWidgets('AttendanceStatusBadge displays status label and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AttendanceStatusBadge(status: AttendanceStatus.present),
                AttendanceStatusBadge(status: AttendanceStatus.absent),
                AttendanceStatusBadge(status: AttendanceStatus.late),
                AttendanceStatusBadge(status: AttendanceStatus.excused),
              ],
            ),
          ),
        ),
      );

      expect(find.text('حاضر'), findsOneWidget);
      expect(find.text('غائب'), findsOneWidget);
      expect(find.text('متأخر'), findsOneWidget);
      expect(find.text('معذور'), findsOneWidget);
    });

    testWidgets('AttendanceStatCard displays metric and value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AttendanceStatCard(
              title: 'نسبة الحضور',
              value: '95%',
              subtitle: 'ممتاز',
            ),
          ),
        ),
      );

      expect(find.text('نسبة الحضور'), findsOneWidget);
      expect(find.text('95%'), findsOneWidget);
      expect(find.text('ممتاز'), findsOneWidget);
    });

    testWidgets('TeacherAttendancePage renders with group and date controls', (tester) async {
      final groupsRepo = FakeGroupsRepository();
      final groupsCubit = GroupsCubit(repository: groupsRepo);
      final attendanceRepo = FakeAttendanceRepository();
      final attendanceCubit = AttendanceCubit(repository: attendanceRepo);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: BlocProvider.value(
            value: groupsCubit,
            child: TeacherAttendancePage(
              initialGroupId: 'group-1',
              attendanceCubit: attendanceCubit,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('متابعة حضور المحاضرات'), findsOneWidget);
      expect(find.text('أحمد علي', skipOffstage: false), findsOneWidget);
      expect(find.text('سارة محمد', skipOffstage: false), findsOneWidget);
    });

    testWidgets('StudentAttendancePage renders attendance stats and history', (tester) async {
      final authRepo = FakeAuthRepository();
      final authCubit = AuthCubit(repository: authRepo);
      final attendanceRepo = FakeAttendanceRepository();
      final attendanceCubit = AttendanceCubit(repository: attendanceRepo);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: BlocProvider.value(
            value: authCubit,
            child: StudentAttendancePage(
              studentId: 'student-1',
              attendanceCubit: attendanceCubit,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('سجل الحضور والغياب'), findsOneWidget);
      expect(find.text('نسبة الالتزام بالحضور'), findsOneWidget);
      expect(find.text('سجل الجلسات السابقة'), findsOneWidget);
    });
  });
}
