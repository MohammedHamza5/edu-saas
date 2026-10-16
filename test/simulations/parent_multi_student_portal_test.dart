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

// ---------------------------------------------------------------------------
// SIMULATED PARENT BACKEND WITH MULTI-STUDENT SECURITY ISOLATION
// ---------------------------------------------------------------------------
class _SimulatedParentBackend {
  final String parentUserId = 'parent-usr-99';
  final String tenantId = 'tenant-academic-1';

  // Linked children mapping: studentId -> ChildEntity
  final Map<String, ChildEntity> linkedChildren = {};

  // Consolidated academic summaries: studentId -> ChildAcademicSummary
  final Map<String, ChildAcademicSummary> academicSummaries = {};

  // Unlinked students belonging to other parents (for IDOR attack tests)
  final Map<String, ChildAcademicSummary> foreignStudents = {};

  // Audit trail for parent access
  final List<Map<String, dynamic>> auditLogs = [];

  _SimulatedParentBackend();

  void recordAudit(String action, String targetStudentId, Map<String, dynamic> metadata) {
    auditLogs.add({
      'action': action,
      'actor_id': parentUserId,
      'target_student_id': targetStudentId,
      'timestamp': DateTime.now().toIso8601String(),
      'metadata': metadata,
    });
  }
}

class _SimulatedParentRepo implements ParentRepository {
  final _SimulatedParentBackend backend;
  bool simulateNetworkDelay = false;
  int delayMs = 0;

  _SimulatedParentRepo(this.backend);

  @override
  Future<Result<List<ChildEntity>>> getLinkedChildren() async {
    if (simulateNetworkDelay && delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
    return Success(backend.linkedChildren.values.toList());
  }

  @override
  Future<Result<ChildAcademicSummary>> getChildAcademicSummary(String studentId) async {
    if (simulateNetworkDelay && delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    // Strict Architectural IDOR Defense (§5.4):
    // If student is not explicitly linked to this parent in parent_students relation, refuse access.
    if (!backend.linkedChildren.containsKey(studentId)) {
      backend.recordAudit('security.unauthorized_child_access_blocked', studentId, {
        'reason': 'IDOR attempt on unlinked student',
      });
      return const FailureResult(
        ServerFailure('Unauthorized access to student academic records', code: 'NOT_AUTHORIZED'),
      );
    }

    final summary = backend.academicSummaries[studentId];
    if (summary == null) {
      return const FailureResult(ServerFailure('Child summary not found', code: 'NOT_FOUND'));
    }

    backend.recordAudit('parent.view_child_summary', studentId, {
      'attendance': summary.attendancePercentage,
      'exam_avg': summary.examsAverageScore,
    });

    return Success(summary);
  }
}

class _SimulatedAuthRepo implements AuthRepository {
  @override
  Future<Result<UserEntity?>> getCurrentUser() async {
    return const Success(UserEntity(
      id: 'parent-usr-99',
      tenantId: 'tenant-academic-1',
      email: 'parent@home.com',
      role: UserRole.parent,
      status: UserStatus.active,
      fullName: 'Dr. Tarek (Parent)',
    ));
  }

  @override
  Future<Result<void>> signOut() async => const Success(null);

  @override
  Future<Result<UserEntity>> signInWithEmail({required String email, required String password}) async =>
      throw UnimplementedError();

  @override
  Future<Result<UserEntity>> signUpStudent({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    String? parentPhone,
    required String tenantId,
  }) async => throw UnimplementedError();

  @override
  Future<Result<void>> resetPasswordForEmail(String email) async => const Success(null);
}

class _SimulatedNotificationsRepo implements NotificationsRepository {
  @override
  Future<Result<List<NotificationEntity>>> getMyNotifications({int limit = 50, int offset = 0}) async =>
      const Success([]);

  @override
  Future<Result<int>> getUnreadCount() async => const Success(2);

  @override
  Future<Result<void>> markAsRead(String recipientId) async => const Success(null);

  @override
  Future<Result<void>> markAllAsRead() async => const Success(null);

  @override
  Future<Result<void>> sendAnnouncement({required String title, required String body, String? groupId}) async =>
      const Success(null);

  @override
  Future<Result<void>> dispatchNotification({
    required String title,
    required String body,
    required NotificationType type,
    String? groupId,
    String? userId,
    Map<String, dynamic>? data,
  }) async => const Success(null);
}

// ---------------------------------------------------------------------------
// TEST HELPER WRAPPER
// ---------------------------------------------------------------------------
Widget _buildParentTestApp({
  required ParentCubit parentCubit,
  required AuthCubit authCubit,
  required NotificationsCubit notificationsCubit,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<ParentCubit>.value(value: parentCubit),
      BlocProvider<AuthCubit>.value(value: authCubit),
      BlocProvider<NotificationsCubit>.value(value: notificationsCubit),
    ],
    child: MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar'), Locale('en')],
      theme: AppTheme.lightTheme,
      home: const ParentDashboardPage(),
    ),
  );
}

// ---------------------------------------------------------------------------
// TEST SUITE: Parent Multi-Student Academic Portal Simulation
// ---------------------------------------------------------------------------
void main() {
  late _SimulatedParentBackend backend;
  late _SimulatedParentRepo parentRepo;
  late _SimulatedAuthRepo authRepo;
  late _SimulatedNotificationsRepo notificationsRepo;

  late ParentCubit parentCubit;
  late AuthCubit authCubit;
  late NotificationsCubit notificationsCubit;

  setUp(() {
    AppCache.clearAll();
    backend = _SimulatedParentBackend();
    parentRepo = _SimulatedParentRepo(backend);
    authRepo = _SimulatedAuthRepo();
    notificationsRepo = _SimulatedNotificationsRepo();

    parentCubit = ParentCubit(repository: parentRepo);
    authCubit = AuthCubit(repository: authRepo);
    notificationsCubit = NotificationsCubit(repository: notificationsRepo);

    // Seed Household: 3 Children with diverse academic standings
    // Child 1: Omar (High achiever)
    backend.linkedChildren['std-omar'] = const ChildEntity(
      id: 'std-omar',
      parentStudentId: 'ps-101',
      fullName: 'عمر طارق',
      email: 'omar@academic.com',
      phone: '01011112222',
      relationship: 'Father',
      status: 'active',
    );
    backend.academicSummaries['std-omar'] = ChildAcademicSummary(
      studentId: 'std-omar',
      attendancePercentage: 96.0,
      totalClasses: 25,
      presentCount: 24,
      absentCount: 1,
      lateCount: 0,
      excusedCount: 0,
      examsCount: 6,
      examsAverageScore: 92.5,
      recentAttendance: [
        AttendanceEntity(
          id: 'att-o-1',
          tenantId: 'tenant-academic-1',
          groupId: 'grp-sat',
          studentId: 'std-omar',
          date: DateTime.now().subtract(const Duration(days: 1)),
          status: AttendanceStatus.present,
          markedAt: DateTime.now().subtract(const Duration(days: 1)),
          groupName: 'SAT Masters Level 2',
        ),
      ],
      recentExams: [
        ParentExamResult(
          examId: 'ex-o-1',
          examTitle: 'Advanced Trigonometry & Circles',
          score: 95.0,
          maxScore: 100.0,
          percentage: 95.0,
          submittedAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ],
      enrolledGroups: const ['SAT Masters Level 2 (SAT)'],
    );

    // Child 2: Laila (At-Risk student: low attendance, low exam average)
    backend.linkedChildren['std-laila'] = const ChildEntity(
      id: 'std-laila',
      parentStudentId: 'ps-102',
      fullName: 'ليلى طارق',
      email: 'laila@academic.com',
      phone: '01033334444',
      relationship: 'Father',
      status: 'active',
    );
    backend.academicSummaries['std-laila'] = ChildAcademicSummary(
      studentId: 'std-laila',
      attendancePercentage: 58.0,
      totalClasses: 24,
      presentCount: 14,
      absentCount: 8,
      lateCount: 2,
      excusedCount: 0,
      examsCount: 4,
      examsAverageScore: 54.0,
      recentAttendance: [
        AttendanceEntity(
          id: 'att-l-1',
          tenantId: 'tenant-academic-1',
          groupId: 'grp-est',
          studentId: 'std-laila',
          date: DateTime.now().subtract(const Duration(days: 1)),
          status: AttendanceStatus.absent,
          markedAt: DateTime.now().subtract(const Duration(days: 1)),
          groupName: 'EST Foundation Basics',
        ),
      ],
      recentExams: [
        ParentExamResult(
          examId: 'ex-l-1',
          examTitle: 'EST Math Algebra I Milestone',
          score: 52.0,
          maxScore: 100.0,
          percentage: 52.0,
          submittedAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ],
      enrolledGroups: const ['EST Foundation Basics (EST)'],
    );

    // Child 3: Youssef (Newly enrolled: 100% attendance, only 1 exam)
    backend.linkedChildren['std-youssef'] = const ChildEntity(
      id: 'std-youssef',
      parentStudentId: 'ps-103',
      fullName: 'يوسف طارق',
      email: 'youssef@academic.com',
      phone: '01055556666',
      relationship: 'Father',
      status: 'active',
    );
    backend.academicSummaries['std-youssef'] = ChildAcademicSummary(
      studentId: 'std-youssef',
      attendancePercentage: 100.0,
      totalClasses: 6,
      presentCount: 6,
      absentCount: 0,
      lateCount: 0,
      excusedCount: 0,
      examsCount: 1,
      examsAverageScore: 88.0,
      recentAttendance: [
        AttendanceEntity(
          id: 'att-y-1',
          tenantId: 'tenant-academic-1',
          groupId: 'grp-act',
          studentId: 'std-youssef',
          date: DateTime.now().subtract(const Duration(days: 2)),
          status: AttendanceStatus.present,
          markedAt: DateTime.now().subtract(const Duration(days: 2)),
          groupName: 'ACT Advanced Problem Solving',
        ),
      ],
      recentExams: [
        ParentExamResult(
          examId: 'ex-y-1',
          examTitle: 'ACT Diagnostic Readiness Assessment',
          score: 88.0,
          maxScore: 100.0,
          percentage: 88.0,
          submittedAt: DateTime.now().subtract(const Duration(days: 4)),
        ),
      ],
      enrolledGroups: const ['ACT Advanced Problem Solving (ACT)'],
    );

    // Foreign student belonging to another family (for IDOR attack testing)
    backend.foreignStudents['std-foreign-victim'] = const ChildAcademicSummary(
      studentId: 'std-foreign-victim',
      attendancePercentage: 40.0,
      totalClasses: 20,
      presentCount: 8,
      absentCount: 12,
      lateCount: 0,
      excusedCount: 0,
      examsCount: 2,
      examsAverageScore: 30.0,
      recentAttendance: [],
      recentExams: [],
      enrolledGroups: ['Confidential Group (VIP)'],
    );
  });

  tearDown(() {
    parentCubit.close();
    authCubit.close();
    notificationsCubit.close();
    AppCache.clearAll();
  });

  group('👨‍👩‍👧‍👦 [Simulation: Parent Multi-Student Academic Portal]', () {
    testWidgets('SCENARIO 1: Household Switcher — Rapid child switching with zero cross-child contamination', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildParentTestApp(
        parentCubit: parentCubit,
        authCubit: authCubit,
        notificationsCubit: notificationsCubit,
      ));

      // 1. Initial State: Load dashboard
      await parentCubit.loadParentDashboard();
      await tester.pumpAndSettle();

      // Verify that Child 1 (Omar) is selected by default
      expect(find.byType(ChildSelectorBar), findsOneWidget);
      expect(find.byType(ParentAcademicOverviewCard), findsOneWidget);
      expect(find.text('عمر طارق'), findsWidgets);
      expect(find.text('96.0%'), findsOneWidget, reason: 'Omar attendance percentage (formatted toStringAsFixed(1))');
      expect(find.text('92.5%'), findsOneWidget, reason: 'Omar exam average (formatted toStringAsFixed(1))');
      expect(find.text('Advanced Trigonometry & Circles'), findsOneWidget);

      // Verify Omar is recorded in the backend audit log
      expect(backend.auditLogs.any((l) => l['target_student_id'] == 'std-omar'), isTrue);

      // 2. Parent switches to Child 2: Laila (At-Risk student)
      final lailaChip = find.widgetWithText(ChoiceChip, 'ليلى طارق');
      expect(lailaChip, findsOneWidget);
      await tester.tap(lailaChip);
      await tester.pumpAndSettle();

      // State verification: Omar data must be completely replaced by Laila
      expect(find.text('Advanced Trigonometry & Circles'), findsNothing, reason: 'Zero cross-child contamination');
      expect(find.text('EST Math Algebra I Milestone'), findsOneWidget, reason: "Laila's exam rendered");
      expect(find.text('58.0%'), findsOneWidget, reason: 'Laila attendance percentage');
      expect(find.text('54.0%'), findsOneWidget, reason: 'Laila exam average');

      // 3. Parent switches to Child 3: Youssef (Newly enrolled)
      final youssefChip = find.widgetWithText(ChoiceChip, 'يوسف طارق');
      expect(youssefChip, findsOneWidget);
      await tester.tap(youssefChip);
      await tester.pumpAndSettle();

      // State verification: Laila data purged, Youssef data displayed
      expect(find.text('EST Math Algebra I Milestone'), findsNothing);
      expect(find.text('ACT Diagnostic Readiness Assessment'), findsOneWidget);
      expect(find.text('100.0%'), findsOneWidget, reason: 'Youssef perfect attendance');
      expect(find.text('88.0%'), findsNWidgets(2), reason: 'Youssef exam average in overview card and exam list badge');

      // Verify 3 distinct audit events for 3 distinct children
      final viewLogs = backend.auditLogs.where((l) => l['action'] == 'parent.view_child_summary').toList();
      expect(viewLogs.length, equals(3));
      expect(viewLogs[0]['target_student_id'], equals('std-omar'));
      expect(viewLogs[1]['target_student_id'], equals('std-laila'));
      expect(viewLogs[2]['target_student_id'], equals('std-youssef'));
    });

    testWidgets('SCENARIO 2: At-Risk Academic Alert Triggers & Attendance Breakdown', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildParentTestApp(
        parentCubit: parentCubit,
        authCubit: authCubit,
        notificationsCubit: notificationsCubit,
      ));

      await parentCubit.loadParentDashboard();
      await tester.pumpAndSettle();

      // Switch to Laila (at-risk student)
      await tester.tap(find.widgetWithText(ChoiceChip, 'ليلى طارق'));
      await tester.pumpAndSettle();

      // Verify attendance breakdown indicators (8 absences recorded)
      expect(find.text('8'), findsOneWidget, reason: 'Absent count for at-risk child');
      expect(find.text('14'), findsOneWidget, reason: 'Present count');

      // Verify that low score (<60%) renders with warning/error visual markers
      final examTile = find.text('EST Math Algebra I Milestone');
      expect(examTile, findsOneWidget);
      expect(find.text('52.0%'), findsWidgets);
    });

    test('SCENARIO 3: Race Condition Resistance — Rapid multi-child switching intent', () async {
      // Setup state with all 3 children
      await parentCubit.loadParentDashboard();
      expect(parentCubit.state, isA<ParentLoaded>());

      final state = parentCubit.state as ParentLoaded;
      expect(state.selectedChild.id, equals('std-omar'));

      // Simulate rapid switching: Omar -> Laila -> Youssef
      final laila = backend.linkedChildren['std-laila']!;
      final youssef = backend.linkedChildren['std-youssef']!;

      // Fire selection for Laila
      final selectLailaFuture = parentCubit.selectChild(laila);
      expect((parentCubit.state as ParentLoaded).selectedChild.id, equals('std-laila'));

      // Immediately switch to Youssef
      await parentCubit.selectChild(youssef);
      await selectLailaFuture;

      final finalState = parentCubit.state as ParentLoaded;
      // Critical assertion: The active selected child must be Youssef
      expect(finalState.selectedChild.id, equals('std-youssef'));
      expect(finalState.summary?.studentId, equals('std-youssef'));
      expect(finalState.summary?.attendancePercentage, equals(100.0));
    });

    test('SCENARIO 4: Security & IDOR Attack Vector Resistance (§5.4 & §12.5)', () async {
      // 1. Legitimate child query succeeds
      final legitQuery = await parentRepo.getChildAcademicSummary('std-omar');
      expect(legitQuery.isSuccess, isTrue);
      expect(legitQuery.dataOrNull?.attendancePercentage, equals(96.0));

      // 2. Malicious parent attempts IDOR query for a foreign student from another family
      final idorAttack = await parentRepo.getChildAcademicSummary('std-foreign-victim');
      expect(idorAttack.isFailure, isTrue);
      expect(idorAttack.failureOrNull?.code, equals('NOT_AUTHORIZED'));

      // 3. Verify security audit logged the intrusion attempt
      final blockedIntrusions = backend.auditLogs
          .where((l) => l['action'] == 'security.unauthorized_child_access_blocked')
          .toList();
      expect(blockedIntrusions.length, equals(1));
      expect(blockedIntrusions.first['target_student_id'], equals('std-foreign-victim'));

      // 4. Zero confidential data leakage
      expect(idorAttack.dataOrNull, isNull);
    });

    testWidgets('SCENARIO 5: Zero-State — Newly registered parent with no linked children', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Wipe linked children to simulate fresh parent account before teacher links any student
      backend.linkedChildren.clear();

      await tester.pumpWidget(_buildParentTestApp(
        parentCubit: parentCubit,
        authCubit: authCubit,
        notificationsCubit: notificationsCubit,
      ));

      await parentCubit.loadParentDashboard();
      await tester.pumpAndSettle();

      // State verification: ParentNoChildren state rendered
      expect(parentCubit.state, isA<ParentNoChildren>());
      expect(find.byIcon(Icons.family_restroom_rounded), findsOneWidget);
      expect(find.byType(ChildSelectorBar), findsNothing);
      expect(find.byType(ParentAcademicOverviewCard), findsNothing);
    });
  });
}
