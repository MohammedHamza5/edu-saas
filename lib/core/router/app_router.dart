import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/attendance/presentation/pages/student_attendance_page.dart';
import '../../features/attendance/presentation/pages/teacher_attendance_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_student_page.dart';
import '../../features/auth/presentation/pages/student_pending_page.dart';
import '../../features/auth/presentation/pages/tenant_suspended_page.dart';
import '../../features/dashboard/presentation/pages/parent_dashboard_page.dart';
import '../../features/dashboard/presentation/pages/splash_page.dart';
import '../../features/dashboard/presentation/pages/student_dashboard_page.dart';
import '../../features/dashboard/presentation/pages/teacher_dashboard_page.dart';
import '../../features/groups/domain/entities/group_entity.dart';
import '../../features/groups/presentation/pages/group_detail_page.dart';
import '../../features/groups/presentation/pages/groups_list_page.dart';

class AppRouter {
  AppRouter._();

  static const String splash = '/';
  static const String login = '/login';
  static const String registerStudent = '/register-student';
  static const String studentPending = '/student-pending';
  static const String tenantSuspended = '/tenant-suspended';

  // Role dashboards (No single dashboard with if-role - Task 5)
  static const String teacherDashboard = '/teacher';
  static const String studentDashboard = '/student';
  static const String parentDashboard = '/parent';

  // Feature: Groups routes
  static const String groupsList = '/teacher/groups';
  static const String groupDetail = '/teacher/groups/:id';

  // Feature: Attendance routes
  static const String teacherAttendance = '/teacher/attendance';
  static const String studentAttendance = '/student/attendance';

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    routes: [
      GoRoute(
        path: splash,
        builder: (BuildContext context, GoRouterState state) {
          return const SplashPage();
        },
      ),
      GoRoute(
        path: login,
        builder: (BuildContext context, GoRouterState state) {
          return const LoginPage();
        },
      ),
      GoRoute(
        path: registerStudent,
        builder: (BuildContext context, GoRouterState state) {
          final tenantId = state.uri.queryParameters['tenant_id'];
          return RegisterStudentPage(tenantId: tenantId);
        },
      ),
      GoRoute(
        path: studentPending,
        builder: (BuildContext context, GoRouterState state) {
          final studentName = state.extra as String? ?? 'طالبنا العزيز';
          return StudentPendingPage(studentName: studentName);
        },
      ),
      GoRoute(
        path: tenantSuspended,
        builder: (BuildContext context, GoRouterState state) {
          return const TenantSuspendedPage();
        },
      ),
      GoRoute(
        path: teacherDashboard,
        builder: (BuildContext context, GoRouterState state) {
          return const TeacherDashboardPage();
        },
      ),
      GoRoute(
        path: groupsList,
        builder: (BuildContext context, GoRouterState state) {
          return const GroupsListPage();
        },
        routes: [
          GoRoute(
            path: ':id',
            builder: (BuildContext context, GoRouterState state) {
              final id = state.pathParameters['id']!;
              final group = state.extra as GroupEntity?;
              return GroupDetailPage(groupId: id, initialGroup: group);
            },
          ),
        ],
      ),
      GoRoute(
        path: teacherAttendance,
        builder: (BuildContext context, GoRouterState state) {
          final groupId = state.uri.queryParameters['groupId'];
          return TeacherAttendancePage(initialGroupId: groupId);
        },
      ),
      GoRoute(
        path: studentAttendance,
        builder: (BuildContext context, GoRouterState state) {
          final studentId = state.uri.queryParameters['studentId'];
          return StudentAttendancePage(studentId: studentId);
        },
      ),
      GoRoute(
        path: studentDashboard,
        builder: (BuildContext context, GoRouterState state) {
          return const StudentDashboardPage();
        },
      ),
      GoRoute(
        path: parentDashboard,
        builder: (BuildContext context, GoRouterState state) {
          return const ParentDashboardPage();
        },
      ),
    ],
  );
}
