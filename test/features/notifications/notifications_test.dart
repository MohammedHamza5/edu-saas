import 'dart:async';
import 'package:edu_saas/core/errors/failures.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/core/utils/cache_manager.dart';
import 'package:edu_saas/features/auth/domain/entities/user_entity.dart';
import 'package:edu_saas/features/auth/domain/repositories/auth_repository.dart';
import 'package:edu_saas/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:edu_saas/features/groups/domain/entities/group_entity.dart';
import 'package:edu_saas/features/groups/domain/entities/group_member_entity.dart';
import 'package:edu_saas/features/groups/domain/repositories/groups_repository.dart';
import 'package:edu_saas/features/groups/presentation/cubit/groups_cubit.dart';
import 'package:edu_saas/features/notifications/data/models/notification_model.dart';
import 'package:edu_saas/features/notifications/domain/entities/notification_entity.dart';
import 'package:edu_saas/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:edu_saas/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:edu_saas/features/notifications/presentation/cubit/notifications_state.dart';
import 'package:edu_saas/features/notifications/presentation/pages/notifications_center_page.dart';
import 'package:edu_saas/features/notifications/presentation/pages/send_announcement_page.dart';
import 'package:edu_saas/features/notifications/presentation/widgets/notification_badge_button.dart';
import 'package:edu_saas/features/notifications/presentation/widgets/notification_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeNotificationsRepository implements NotificationsRepository {
  List<NotificationEntity> mockNotifications = [
    NotificationEntity(
      id: 'notif-1',
      recipientId: 'rec-1',
      tenantId: 'tenant-1',
      title: 'إعلان هام',
      body: 'تم تحديد موعد المراجعة النهائية',
      type: NotificationType.importantAnnouncement,
      readAt: null,
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    NotificationEntity(
      id: 'notif-2',
      recipientId: 'rec-2',
      tenantId: 'tenant-1',
      title: 'رصد الحضور',
      body: 'تم تسجيل حضورك في حصة SAT Math',
      type: NotificationType.attendanceMarked,
      readAt: DateTime.now().subtract(const Duration(hours: 1)),
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  bool shouldFail = false;

  @override
  Future<Result<List<NotificationEntity>>> getMyNotifications({
    bool? unreadOnly,
    int limit = 50,
    int offset = 0,
  }) async {
    if (shouldFail) {
      return const FailureResult(ServerFailure('Failed to fetch notifications'));
    }
    if (unreadOnly == true) {
      return Success(mockNotifications.where((n) => !n.isRead).toList());
    }
    return Success(mockNotifications);
  }

  @override
  Future<Result<int>> getUnreadCount() async {
    if (shouldFail) {
      return const FailureResult(ServerFailure('Failed to get unread count'));
    }
    final count = mockNotifications.where((n) => !n.isRead).length;
    return Success(count);
  }

  @override
  Future<Result<void>> markAsRead(String recipientId) async {
    if (shouldFail) {
      return const FailureResult(ServerFailure('Failed to mark as read'));
    }
    final index = mockNotifications.indexWhere((n) => n.recipientId == recipientId);
    if (index != -1) {
      final old = mockNotifications[index];
      mockNotifications[index] = old.copyWith(readAt: DateTime.now());
    }
    return const Success(null);
  }

  @override
  Future<Result<void>> markAllAsRead() async {
    if (shouldFail) {
      return const FailureResult(ServerFailure('Failed to mark all as read'));
    }
    mockNotifications = mockNotifications
        .map((n) => n.copyWith(readAt: DateTime.now()))
        .toList();
    return const Success(null);
  }

  @override
  Future<Result<void>> sendAnnouncement({
    required String title,
    required String body,
    String? groupId,
  }) async {
    if (shouldFail) {
      return const FailureResult(ServerFailure('Failed to send announcement'));
    }
    mockNotifications.insert(
      0,
      NotificationEntity(
        id: 'notif-${mockNotifications.length + 1}',
        recipientId: 'rec-${mockNotifications.length + 1}',
        tenantId: 'tenant-1',
        title: title,
        body: body,
        type: NotificationType.importantAnnouncement,
        readAt: null,
        createdAt: DateTime.now(),
        data: groupId != null ? {'group_id': groupId} : const {},
      ),
    );
    return const Success(null);
  }
}

class FakeGroupsRepository implements GroupsRepository {
  List<GroupEntity> mockGroups = [
    const GroupEntity(
      id: 'group-1',
      tenantId: 'tenant-1',
      name: 'SAT Math Basics',
      level: 'SAT',
      previousContentAccess: 'allow',
      createdAt: null,
      membersCount: 5,
    ),
    const GroupEntity(
      id: 'group-2',
      tenantId: 'tenant-1',
      name: 'EST Advanced',
      level: 'EST',
      previousContentAccess: 'deny',
      createdAt: null,
      membersCount: 4,
    ),
  ];

  @override
  Future<Result<List<GroupEntity>>> getGroups() async => Success(mockGroups);

  @override
  Future<Result<GroupEntity>> createGroup({
    required String name,
    required String level,
    String? description,
    required String previousContentAccess,
  }) async =>
      Success(mockGroups.first);

  @override
  Future<Result<GroupEntity>> updateGroup({
    required String id,
    String? name,
    String? level,
    String? description,
    String? previousContentAccess,
    String? status,
  }) async =>
      Success(mockGroups.first);

  @override
  Future<Result<List<GroupMemberEntity>>> getGroupMembers(String groupId) async =>
      const Success([]);

  @override
  Future<Result<GroupMemberEntity>> addMemberToGroup({
    required String groupId,
    required String studentId,
  }) async =>
      Success(GroupMemberEntity(
        id: 'mem-1',
        groupId: groupId,
        studentId: studentId,
        studentName: 'أحمد',
        joinedAt: DateTime.now(),
      ));

  @override
  Future<Result<void>> removeMemberFromGroup({
    required String groupId,
    required String studentId,
  }) async =>
      const Success(null);
}

class FakeAuthRepository implements AuthRepository {
  @override
  Future<Result<UserEntity?>> getCurrentUser() async {
    return const Success(
      UserEntity(
        id: 'teacher-1',
        tenantId: 'tenant-1',
        email: 'teacher@test.com',
        fullName: 'أستاذ أحمد',
        role: UserRole.teacher,
        status: UserStatus.active,
      ),
    );
  }

  @override
  Future<Result<UserEntity>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return const Success(
      UserEntity(
        id: 'teacher-1',
        tenantId: 'tenant-1',
        email: 'teacher@test.com',
        fullName: 'أستاذ أحمد',
        role: UserRole.teacher,
        status: UserStatus.active,
      ),
    );
  }

  @override
  Future<Result<void>> signOut() async => const Success(null);

  @override
  Future<Result<UserEntity>> signUpStudent({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    String? parentPhone,
    required String tenantId,
  }) async =>
      const Success(
        UserEntity(
          id: 'student-1',
          tenantId: 'tenant-1',
          email: 'student@test.com',
          fullName: 'طالب جديد',
          role: UserRole.student,
          status: UserStatus.pending,
        ),
      );

  @override
  Future<Result<void>> resetPasswordForEmail(String email) async => const Success(null);
}

void main() {
  late FakeNotificationsRepository fakeRepo;
  late NotificationsCubit cubit;
  late FakeGroupsRepository fakeGroupsRepo;
  late GroupsCubit groupsCubit;
  late FakeAuthRepository fakeAuthRepo;
  late AuthCubit authCubit;

  setUp(() {
    AppCache.clearAll();
    fakeRepo = FakeNotificationsRepository();
    cubit = NotificationsCubit(repository: fakeRepo);
    fakeGroupsRepo = FakeGroupsRepository();
    groupsCubit = GroupsCubit(repository: fakeGroupsRepo);
    fakeAuthRepo = FakeAuthRepository();
    authCubit = AuthCubit(repository: fakeAuthRepo);
  });

  tearDown(() {
    cubit.close();
    groupsCubit.close();
    authCubit.close();
  });

  Widget createTestWidget(Widget child) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<NotificationsCubit>.value(value: cubit),
        BlocProvider<GroupsCubit>.value(value: groupsCubit),
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

  group('NotificationType Enum & Whitelist tests', () {
    test('NotificationType matches all 8 whitelist dbValues', () {
      expect(NotificationType.newContent.dbValue, 'new_content');
      expect(NotificationType.assignmentCreated.dbValue, 'assignment_created');
      expect(NotificationType.assignmentDue.dbValue, 'assignment_due');
      expect(NotificationType.assignmentReviewed.dbValue, 'assignment_reviewed');
      expect(NotificationType.examPublished.dbValue, 'exam_published');
      expect(NotificationType.examResult.dbValue, 'exam_result');
      expect(NotificationType.attendanceMarked.dbValue, 'attendance_marked');
      expect(NotificationType.importantAnnouncement.dbValue, 'important_announcement');
    });

    test('NotificationType.fromString parses valid strings and defaults correctly', () {
      expect(NotificationType.fromString('attendance_marked'), NotificationType.attendanceMarked);
      expect(NotificationType.fromString('exam_published'), NotificationType.examPublished);
      expect(NotificationType.fromString('assignment_due'), NotificationType.assignmentDue);
      expect(NotificationType.fromString('unknown_type'), NotificationType.importantAnnouncement);
    });

    test('NotificationType returns localized Arabic labels and icons', () {
      expect(NotificationType.attendanceMarked.labelAr, 'رصد حضور');
      expect(NotificationType.importantAnnouncement.labelAr, 'إعلان مهم');
      expect(NotificationType.newContent.labelAr, 'محتوى جديد');
      expect(NotificationType.examResult.labelAr, 'نتيجة امتحان');
      expect(NotificationType.attendanceMarked.icon, Icons.fact_check_rounded);
    });
  });

  group('NotificationModel JSON serialization tests', () {
    test('NotificationModel.fromJson parses flat and joined notification maps', () {
      final json = {
        'id': 'rec-100',
        'notification_id': 'notif-100',
        'is_read': false,
        'read_at': null,
        'notifications': {
          'id': 'notif-100',
          'tenant_id': 'tenant-1',
          'title': 'واجب جديد',
          'body': 'تم نشر واجب الجبر والإحصاء',
          'type': 'assignment_created',
          'data': {'assignment_id': 'asg-1'},
          'created_at': '2026-03-01T10:00:00.000Z',
        }
      };

      final model = NotificationModel.fromJson(json);

      expect(model.id, 'notif-100');
      expect(model.recipientId, 'rec-100');
      expect(model.title, 'واجب جديد');
      expect(model.body, 'تم نشر واجب الجبر والإحصاء');
      expect(model.type, NotificationType.assignmentCreated);
      expect(model.isRead, false);
      expect(model.data['assignment_id'], 'asg-1');
    });
  });

  group('NotificationsCubit Unit Tests', () {
    test('loadNotifications emits Loading then Loaded on success', () async {
      final expected = [
        isA<NotificationsLoading>(),
        isA<NotificationsLoaded>()
            .having((s) => s.notifications.length, 'length', 2)
            .having((s) => s.unreadCount, 'unreadCount', 1),
      ];

      final expectation = expectLater(cubit.stream, emitsInOrder(expected));
      unawaited(expectation);
      await cubit.loadNotifications();
      await expectation;
    });

    test('loadNotifications emits Loading then Error on failure', () async {
      fakeRepo.shouldFail = true;

      final expected = [
        isA<NotificationsLoading>(),
        isA<NotificationsError>(),
      ];

      final expectation = expectLater(cubit.stream, emitsInOrder(expected));
      unawaited(expectation);
      await cubit.loadNotifications();
      await expectation;
    });

    test('markAsRead performs optimistic update and reduces unread count', () async {
      await cubit.loadNotifications();
      expect((cubit.state as NotificationsLoaded).unreadCount, 1);

      await cubit.markAsRead('rec-1');
      final updated = cubit.state as NotificationsLoaded;
      expect(updated.unreadCount, 0);
      expect(updated.notifications.firstWhere((n) => n.recipientId == 'rec-1').isRead, true);
    });

    test('markAllAsRead marks all notifications as read', () async {
      await cubit.loadNotifications();
      expect((cubit.state as NotificationsLoaded).unreadCount, 1);

      await cubit.markAllAsRead();
      final updated = cubit.state as NotificationsLoaded;
      expect(updated.unreadCount, 0);
      expect(updated.notifications.every((n) => n.isRead), true);
    });

    test('toggleUnreadFilter updates filter flag', () async {
      await cubit.loadNotifications();
      expect((cubit.state as NotificationsLoaded).filterUnreadOnly, false);

      cubit.toggleUnreadFilter(true);
      expect((cubit.state as NotificationsLoaded).filterUnreadOnly, true);
    });

    test('sendAnnouncement successfully dispatches and emits success state', () async {
      await cubit.loadNotifications();

      await cubit.sendAnnouncement(
        title: 'تنبيه عاجل',
        body: 'الرجاء تسليم الواجب قبل الغد',
        groupId: 'group-1',
      );

      final updated = cubit.state as NotificationsLoaded;
      expect(updated.sendSuccess, true);
    });
  });

  group('Notifications UI Widgets Tests', () {
    testWidgets('NotificationTile displays title, body, and type badge', (tester) async {
      final notif = NotificationEntity(
        id: '1',
        recipientId: 'r1',
        tenantId: 'tenant-1',
        title: 'اختبار الجبر الشهري',
        body: 'تم إتاحة امتحان SAT Math Section 3',
        type: NotificationType.examPublished,
        readAt: null,
        createdAt: DateTime.now(),
      );

      bool tapped = false;

      await tester.pumpWidget(
        createTestWidget(
          Scaffold(
            body: NotificationTile(
              notification: notif,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('اختبار الجبر الشهري'), findsOneWidget);
      expect(find.text('تم إتاحة امتحان SAT Math Section 3'), findsOneWidget);
      expect(find.text('امتحان جديد'), findsOneWidget);

      await tester.tap(find.byType(NotificationTile));
      expect(tapped, true);
    });

    testWidgets('NotificationBadgeButton displays badge only when unreadCount > 0', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const Scaffold(
            body: NotificationBadgeButton(),
          ),
        ),
      );

      // Initially no loaded state -> unread 0 -> no badge
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      expect(find.text('1'), findsNothing);

      // Load notifications with 1 unread
      await cubit.loadNotifications();
      await tester.pumpAndSettle();

      // Badge with '1' should now appear
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('NotificationsCenterPage displays notifications and allows marking all as read',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await cubit.loadNotifications();

      await tester.pumpWidget(
        createTestWidget(const NotificationsCenterPage()),
      );
      await tester.pumpAndSettle();

      // Verify title and notifications exist
      expect(find.text('مركز الإشعارات'), findsOneWidget);
      expect(find.text('إعلان هام'), findsOneWidget);
      expect(find.text('رصد الحضور'), findsOneWidget);

      // Verify mark all as read button exists and can be tapped
      final markAllButton = find.text('قراءة الكل');
      expect(markAllButton, findsOneWidget);
      await tester.tap(markAllButton);
      await tester.pumpAndSettle();

      // Verify unread count is 0
      final state = cubit.state as NotificationsLoaded;
      expect(state.unreadCount, 0);
    });

    testWidgets('SendAnnouncementPage renders form and validates inputs', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await groupsCubit.loadGroups();

      await tester.pumpWidget(
        createTestWidget(const SendAnnouncementPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('إرسال إعلان وتنبيه'), findsOneWidget);
      expect(find.text('تنبيه أكاديمي فوري'), findsOneWidget);

      // Tap submit with empty fields -> should show validation error
      final submitButton = find.text('إرسال الإعلان الآن');
      expect(submitButton, findsOneWidget);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('يرجى إدخال عنوان الإعلان'), findsOneWidget);
    });
  });
}
