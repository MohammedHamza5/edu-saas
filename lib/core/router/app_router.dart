import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../di/injection_container.dart';
import '../../features/students/domain/entities/student_entity.dart';
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
import '../../features/notifications/presentation/pages/notifications_center_page.dart';
import '../../features/notifications/presentation/pages/send_announcement_page.dart';
import '../../features/onboarding/presentation/pages/platform_onboarding_page.dart';
import '../../features/students/presentation/pages/assign_groups_page.dart';
import '../../features/students/presentation/pages/pending_students_page.dart';
import '../../features/students/presentation/pages/student_360_page.dart';
import '../../features/students/presentation/pages/students_list_page.dart';

import '../network/supabase_service.dart';

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

  // Feature: Students routes
  static const String studentsList = '/teacher/students';
  static const String pendingStudents = '/teacher/students/pending';
  static const String student360 = '/teacher/students/profile';
  static const String assignGroups = '/teacher/students/assign-groups';

  // Feature: Notifications routes
  static const String notificationsCenter = '/notifications';
  static const String sendAnnouncement = '/teacher/announcements/new';

  // Feature: Platform Onboarding
  static const String platformOnboarding = '/platform/onboarding';

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    redirect: (BuildContext context, GoRouterState state) {
      final isAuthenticated = SupabaseService.isAuthenticated;
      final path = state.matchedLocation;

      // Unauthenticated users trying to access protected role routes
      if (!isAuthenticated) {
        final isProtected = path.startsWith('/teacher') ||
            path.startsWith('/student') ||
            path.startsWith('/parent');
        if (isProtected) {
          return login;
        }
      }

      return null;
    },
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
      GoRoute(
        path: notificationsCenter,
        builder: (BuildContext context, GoRouterState state) {
          return const NotificationsCenterPage();
        },
      ),
      GoRoute(
        path: sendAnnouncement,
        builder: (BuildContext context, GoRouterState state) {
          final groupId = state.uri.queryParameters['groupId'];
          return SendAnnouncementPage(initialGroupId: groupId);
        },
      ),
      // ── Students routes ────────────────────────────────────────────────
      GoRoute(
        path: studentsList,
        builder: (BuildContext context, GoRouterState state) {
          return BlocProvider(
            create: (_) => InjectionContainer.createStudentsCubit(),
            child: const StudentsListPage(),
          );
        },
      ),
      GoRoute(
        path: pendingStudents,
        builder: (BuildContext context, GoRouterState state) {
          return BlocProvider(
            create: (_) => InjectionContainer.createStudentsCubit(),
            child: const PendingStudentsPage(),
          );
        },
      ),
      GoRoute(
        path: student360,
        builder: (BuildContext context, GoRouterState state) {
          final studentId = state.uri.queryParameters['id']!;
          final student = state.extra as StudentEntity?;
          return BlocProvider(
            create: (_) => InjectionContainer.createStudentsCubit(),
            child: Student360Page(
              studentId: studentId,
              initialStudent: student,
            ),
          );
        },
      ),
      GoRoute(
        path: assignGroups,
        builder: (BuildContext context, GoRouterState state) {
          final studentId = state.extra as String;
          return BlocProvider(
            create: (_) => InjectionContainer.createStudentsCubit(),
            child: AssignGroupsPage(studentId: studentId),
          );
        },
      ),
      GoRoute(
        path: platformOnboarding,
        builder: (BuildContext context, GoRouterState state) {
          return BlocProvider(
            create: (_) => InjectionContainer.createOnboardingCubit(),
            child: const PlatformOnboardingPage(),
          );
        },
      ),
    ],
  );
}
