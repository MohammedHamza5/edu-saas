import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/features/auth/domain/entities/user_entity.dart';
import 'package:edu_saas/features/auth/domain/repositories/auth_repository.dart';
import 'package:edu_saas/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:edu_saas/features/auth/presentation/cubit/auth_state.dart';
import 'package:edu_saas/features/dashboard/presentation/pages/student_dashboard_page.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/features/notifications/domain/entities/notification_entity.dart';
import 'package:edu_saas/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:edu_saas/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:edu_saas/features/dashboard/domain/entities/student_dashboard_stats.dart';
import 'package:edu_saas/features/dashboard/domain/repositories/student_dashboard_repository.dart';
import 'package:edu_saas/features/dashboard/presentation/cubit/student_dashboard_cubit.dart';
import 'package:edu_saas/features/dashboard/presentation/cubit/student_dashboard_state.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<Result<UserEntity>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<UserEntity>> signUpStudent({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    String? parentPhone,
    required String tenantId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> signOut() async => const Success(null);

  @override
  Future<Result<void>> resetPasswordForEmail(String email) async => const Success(null);

  @override
  Future<Result<UserEntity?>> getCurrentUser() async => const Success(null);
}

class _FakeNotificationsRepository implements NotificationsRepository {
  @override
  Future<Result<List<NotificationEntity>>> getMyNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    return const Success([]);
  }

  @override
  Future<Result<int>> getUnreadCount() async => const Success(0);

  @override
  Future<Result<void>> markAsRead(String recipientId) async => const Success(null);

  @override
  Future<Result<void>> markAllAsRead() async => const Success(null);

  @override
  Future<Result<void>> sendAnnouncement({
    required String title,
    required String body,
    String? groupId,
  }) async {
    return const Success(null);
  }
}

class _FakeStudentDashboardRepository implements StudentDashboardRepository {
  @override
  Future<Result<StudentDashboardStats>> getStudentDashboardStats(String studentId) async {
    return const Success(StudentDashboardStats(
      attendancePercentage: 100,
      examAverage: 85,
      assignmentsSubmitted: 4,
      videoCompletionPercentage: 90,
      activeGroupName: 'Digital SAT Master',
      activeGroupLevel: 'SAT',
    ));
  }
}

void main() {
  late AuthCubit authCubit;
  late NotificationsCubit notificationsCubit;
  late StudentDashboardCubit studentDashboardCubit;

  setUp(() {
    authCubit = AuthCubit(repository: _FakeAuthRepository())
      ..emit(const AuthAuthenticated(
        UserEntity(
          id: 'student-1',
          tenantId: 'tenant-1',
          role: UserRole.student,
          fullName: 'طالب تجريبي',
          email: 'student@test.com',
          status: UserStatus.active,
        ),
      ));
    notificationsCubit = NotificationsCubit(repository: _FakeNotificationsRepository());
    studentDashboardCubit = StudentDashboardCubit(repository: _FakeStudentDashboardRepository())
      ..emit(const StudentDashboardLoaded(
        stats: StudentDashboardStats(
          attendancePercentage: 100,
          examAverage: 85,
          assignmentsSubmitted: 4,
          videoCompletionPercentage: 90,
          activeGroupName: 'المسار الدراسي',
          activeGroupLevel: 'SAT',
        ),
      ));
  });

  tearDown(() {
    authCubit.close();
    notificationsCubit.close();
    studentDashboardCubit.close();
  });

  Widget buildStudentDashboardTestApp() {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<NotificationsCubit>.value(value: notificationsCubit),
        BlocProvider<StudentDashboardCubit>.value(value: studentDashboardCubit),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ar'),
        theme: AppTheme.lightTheme,
        home: const StudentDashboardPage(),
      ),
    );
  }

  group('StudentDashboardPage Multi-Device Responsive Tests', () {
    testWidgets('Renders cleanly on Extra Small Mobile (320x640) with zero overflow', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildStudentDashboardTestApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('لوحة الطالب'), findsOneWidget);
      expect(find.textContaining('مرحباً بك'), findsOneWidget);
      expect(find.text('المسار الدراسي'), findsOneWidget);
    });

    testWidgets('Renders cleanly on Standard Mobile (390x844)', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildStudentDashboardTestApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('لوحة الطالب'), findsOneWidget);
      expect(find.text('نسبة الحضور'), findsOneWidget);
    });

    testWidgets('Renders cleanly on Tablet Portrait (768x1024)', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(768, 1024);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildStudentDashboardTestApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('لوحة الطالب'), findsOneWidget);
      expect(find.textContaining('مرحباً بك'), findsOneWidget);
    });

    testWidgets('Renders cleanly on Desktop/Laptop (1440x900) with bounded width', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildStudentDashboardTestApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('لوحة الطالب'), findsOneWidget);
      expect(find.text('المسار الدراسي'), findsOneWidget);
    });

    testWidgets('Renders cleanly on 1080p Desktop (1920x1080)', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1920, 1080);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildStudentDashboardTestApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('لوحة الطالب'), findsOneWidget);
    });
  });
}
