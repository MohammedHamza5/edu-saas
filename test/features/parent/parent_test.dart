import 'package:edu_saas/core/errors/failures.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/core/utils/cache_manager.dart';
import 'package:edu_saas/features/attendance/domain/entities/attendance_entity.dart';
import 'package:edu_saas/features/auth/domain/entities/user_entity.dart';
import 'package:edu_saas/features/auth/domain/repositories/auth_repository.dart';
import 'package:edu_saas/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:edu_saas/features/dashboard/presentation/pages/parent_dashboard_page.dart';
import 'package:edu_saas/features/notifications/domain/entities/notification_entity.dart';
import 'package:edu_saas/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:edu_saas/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:edu_saas/features/parent/data/models/child_model.dart';
import 'package:edu_saas/features/parent/domain/entities/child_entity.dart';
import 'package:edu_saas/features/parent/domain/repositories/parent_repository.dart';
import 'package:edu_saas/features/parent/presentation/cubit/parent_cubit.dart';
import 'package:edu_saas/features/parent/presentation/cubit/parent_state.dart';
import 'package:edu_saas/features/parent/presentation/widgets/child_selector_bar.dart';
import 'package:edu_saas/features/parent/presentation/widgets/parent_academic_overview_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeParentRepository implements ParentRepository {
  List<ChildEntity> mockChildren = [
    const ChildEntity(
      id: 'student-1',
      parentStudentId: 'ps-1',
      fullName: 'عمر أحمد',
      email: 'omar@test.com',
      phone: '01000000001',
      relationship: 'Father',
      status: 'active',
    ),
    const ChildEntity(
      id: 'student-2',
      parentStudentId: 'ps-2',
      fullName: 'مريم أحمد',
      email: 'maryam@test.com',
      phone: '01000000002',
      relationship: 'Father',
      status: 'active',
    ),
  ];

  late ChildAcademicSummary mockSummary;

  bool shouldFail = false;
  bool returnEmpty = false;

  FakeParentRepository() {
    mockSummary = ChildAcademicSummary(
      studentId: 'student-1',
      attendancePercentage: 90.0,
      totalClasses: 10,
      presentCount: 9,
      absentCount: 1,
      lateCount: 0,
      excusedCount: 0,
      examsCount: 3,
      examsAverageScore: 88.5,
      recentAttendance: [
        AttendanceEntity(
          id: 'att-1',
          tenantId: 'tenant-1',
          groupId: 'group-1',
          studentId: 'student-1',
          date: DateTime(2026, 3, 5),
          status: AttendanceStatus.present,
          markedAt: DateTime.now(),
          groupName: 'SAT Math Basics',
        ),
      ],
      recentExams: [
        ParentExamResult(
          examId: 'exam-1',
          examTitle: 'امتحان الجبر الشامل',
          score: 45,
          maxScore: 50,
          percentage: 90.0,
          submittedAt: DateTime(2026, 3, 1),
        ),
      ],
      enrolledGroups: const ['SAT Math Basics (SAT)', 'EST Advanced (EST)'],
    );
  }

  @override
  Future<Result<List<ChildEntity>>> getLinkedChildren() async {
    if (shouldFail) {
      return const FailureResult(ServerFailure('Database error'));
    }
    if (returnEmpty) {
      return const Success([]);
    }
    return Success(mockChildren);
  }

  @override
  Future<Result<ChildAcademicSummary>> getChildAcademicSummary(String studentId) async {
    if (shouldFail) {
      return const FailureResult(ServerFailure('Failed to fetch summary'));
    }
    return Success(mockSummary);
  }
}

class FakeNotificationsRepository implements NotificationsRepository {
  @override
  Future<Result<List<NotificationEntity>>> getMyNotifications({
    int limit = 50,
    int offset = 0,
  }) async =>
      const Success([]);

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
  }) async =>
      const Success(null);
}

class FakeAuthRepository implements AuthRepository {
  @override
  Future<Result<UserEntity?>> getCurrentUser() async => const Success(
        UserEntity(
          id: 'parent-1',
          tenantId: 'tenant-1',
          email: 'parent@test.com',
          fullName: 'أحمد محمود',
          role: UserRole.parent,
          status: UserStatus.active,
        ),
      );

  @override
  Future<Result<UserEntity>> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      const Success(
        UserEntity(
          id: 'parent-1',
          tenantId: 'tenant-1',
          email: 'parent@test.com',
          fullName: 'أحمد محمود',
          role: UserRole.parent,
          status: UserStatus.active,
        ),
      );

  @override
  Future<Result<void>> signOut() async => const Success(null);

  @override
  Future<Result<UserEntity>> signUpStudent({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String tenantId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Result<void>> resetPasswordForEmail(String email) async => const Success(null);
}

void main() {
  late FakeParentRepository fakeRepo;
  late ParentCubit parentCubit;
  late FakeNotificationsRepository fakeNotificationsRepo;
  late NotificationsCubit notificationsCubit;
  late FakeAuthRepository fakeAuthRepo;
  late AuthCubit authCubit;

  setUp(() {
    AppCache.clearAll();
    fakeRepo = FakeParentRepository();
    parentCubit = ParentCubit(repository: fakeRepo);
    fakeNotificationsRepo = FakeNotificationsRepository();
    notificationsCubit = NotificationsCubit(repository: fakeNotificationsRepo);
    fakeAuthRepo = FakeAuthRepository();
    authCubit = AuthCubit(repository: fakeAuthRepo);
  });

  tearDown(() {
    parentCubit.close();
    notificationsCubit.close();
    authCubit.close();
  });

  Widget createTestWidget(Widget child) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ParentCubit>.value(value: parentCubit),
        BlocProvider<NotificationsCubit>.value(value: notificationsCubit),
        BlocProvider<AuthCubit>.value(value: authCubit),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    );
  }

  group('Parent Domain & Model Tests', () {
    test('ChildModel.fromJson deserializes joined parent_students query', () {
      final json = {
        'id': 'ps-100',
        'relationship': 'Mother',
        'users': {
          'id': 'student-100',
          'full_name': 'يوسف خالد',
          'email': 'youssef@test.com',
          'phone': '01122334455',
          'avatar_url': null,
          'status': 'active',
        },
      };

      final model = ChildModel.fromJson(json);

      expect(model.id, 'student-100');
      expect(model.parentStudentId, 'ps-100');
      expect(model.fullName, 'يوسف خالد');
      expect(model.email, 'youssef@test.com');
      expect(model.phone, '01122334455');
      expect(model.relationship, 'Mother');
      expect(model.status, 'active');
    });

    test('ChildModel.toJson serializes properly', () {
      const model = ChildModel(
        id: 's-1',
        parentStudentId: 'ps-1',
        fullName: 'عمر',
        email: 'omar@test.com',
        status: 'active',
      );

      final map = model.toJson();
      expect(map['id'], 's-1');
      expect(map['full_name'], 'عمر');
      expect(map['email'], 'omar@test.com');
    });
  });

  group('ParentCubit Unit Tests', () {
    test('loadParentDashboard emits Loading, then Loaded with first child summary', () async {
      final expected = [
        isA<ParentLoading>(),
        isA<ParentLoaded>()
            .having((s) => s.children.length, 'childrenCount', 2)
            .having((s) => s.selectedChild.id, 'selectedChildId', 'student-1')
            .having((s) => s.isLoadingSummary, 'isLoadingSummary', true),
        isA<ParentLoaded>()
            .having((s) => s.selectedChild.id, 'selectedChildId', 'student-1')
            .having((s) => s.summary?.attendancePercentage, 'attendancePercentage', 90.0)
            .having((s) => s.isLoadingSummary, 'isLoadingSummary', false),
      ];

      final expectation = expectLater(parentCubit.stream, emitsInOrder(expected));
      await parentCubit.loadParentDashboard();
      await expectation;
    });

    test('loadParentDashboard emits ParentNoChildren when children list is empty', () async {
      fakeRepo.returnEmpty = true;

      final expected = [
        isA<ParentLoading>(),
        isA<ParentNoChildren>(),
      ];

      final expectation = expectLater(parentCubit.stream, emitsInOrder(expected));
      await parentCubit.loadParentDashboard();
      await expectation;
    });

    test('loadParentDashboard emits ParentError on failure', () async {
      fakeRepo.shouldFail = true;

      final expected = [
        isA<ParentLoading>(),
        isA<ParentError>().having((s) => s.message, 'message', 'Database error'),
      ];

      final expectation = expectLater(parentCubit.stream, emitsInOrder(expected));
      await parentCubit.loadParentDashboard();
      await expectation;
    });

    test('selectChild updates selectedChild and loads child summary', () async {
      await parentCubit.loadParentDashboard();

      final child2 = fakeRepo.mockChildren[1];
      await parentCubit.selectChild(child2);

      final state = parentCubit.state as ParentLoaded;
      expect(state.selectedChild.id, 'student-2');
      expect(state.selectedChild.fullName, 'مريم أحمد');
      expect(state.summary, isNotNull);
    });
  });

  group('Parent Widgets UI Tests', () {
    testWidgets('ChildSelectorBar renders single child view when only 1 child exists',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          Scaffold(
            body: ChildSelectorBar(
              children: [fakeRepo.mockChildren.first],
              selectedChild: fakeRepo.mockChildren.first,
              onChildSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('عمر أحمد'), findsOneWidget);
      expect(find.text('صلة القرابة: Father'), findsOneWidget);
      expect(find.text('الابن الحالي'), findsOneWidget);
    });

    testWidgets('ChildSelectorBar renders choice chips and allows switching when multiple children exist',
        (tester) async {
      ChildEntity? selected;

      await tester.pumpWidget(
        createTestWidget(
          Scaffold(
            body: ChildSelectorBar(
              children: fakeRepo.mockChildren,
              selectedChild: fakeRepo.mockChildren.first,
              onChildSelected: (child) => selected = child,
            ),
          ),
        ),
      );

      expect(find.text('اختر الطالب للمتابعة'), findsOneWidget);
      expect(find.text('عمر أحمد'), findsOneWidget);
      expect(find.text('مريم أحمد'), findsOneWidget);

      await tester.tap(find.text('مريم أحمد'));
      expect(selected?.fullName, 'مريم أحمد');
    });

    testWidgets('ParentAcademicOverviewCard renders stats, groups, and attendance metrics',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          Scaffold(
            body: SingleChildScrollView(
              child: ParentAcademicOverviewCard(summary: fakeRepo.mockSummary),
            ),
          ),
        ),
      );

      expect(find.text('نسبة الحضور'), findsOneWidget);
      expect(find.text('90.0%'), findsOneWidget);
      expect(find.text('حضر 9 من 10 حصة'), findsOneWidget);
      expect(find.text('متوسط الامتحانات'), findsOneWidget);
      expect(find.text('88.5%'), findsOneWidget);
      expect(find.text('المجموعات المسجل بها'), findsOneWidget);
      expect(find.text('SAT Math Basics (SAT)'), findsOneWidget);
    });

    testWidgets('ParentDashboardPage renders ParentNoChildren empty state when no children linked',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      fakeRepo.returnEmpty = true;
      await parentCubit.loadParentDashboard();

      await tester.pumpWidget(
        createTestWidget(
          const Scaffold(
            body: ParentDashboardPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('لوحة متابعة ولي الأمر'), findsOneWidget);
      expect(
        find.text(
          'لا يوجد طلاب مرتبطون بحسابك حالياً.\nيرجى تزويد المعلم ببريدك الإلكتروني لربط حسابك بابنك أو ابنتك.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('ParentDashboardPage renders loaded state with overview and sections',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await parentCubit.loadParentDashboard();

      await tester.pumpWidget(
        createTestWidget(
          const Scaffold(
            body: ParentDashboardPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('لوحة متابعة ولي الأمر'), findsOneWidget);
      expect(find.text('نسبة الحضور'), findsOneWidget);
      expect(find.text('آخر جلسات الحضور (P-06)'), findsOneWidget);
      expect(find.text('نتائج الاختبارات والامتحانات (P-05)'), findsOneWidget);
      expect(find.text('امتحان الجبر الشامل'), findsOneWidget);
    });
  });
}
