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
import '../../features/videos/presentation/cubit/videos_cubit.dart';
import '../../features/videos/presentation/pages/video_player_page.dart';
import '../../features/content/presentation/pages/teacher_content_library_page.dart';
import '../../features/content/presentation/pages/teacher_lesson_details_page.dart';
import '../../features/content/presentation/pages/teacher_video_bank_page.dart';
import '../../features/content/presentation/pages/student_content_feed_page.dart';
import '../../features/content/domain/entities/content_entity.dart';
import '../../features/assignments/presentation/pages/teacher_assignments_page.dart';
import '../../features/assignments/presentation/pages/student_assignments_page.dart';
import '../../features/exams/presentation/pages/teacher_exams_page.dart';
import '../../features/exams/presentation/pages/student_exams_page.dart';
import '../../features/settings/presentation/pages/teacher_settings_page.dart';

import '../network/supabase_service.dart';
import '../utils/group_slug_resolver.dart';
import '../widgets/student_shell.dart';
import '../widgets/teacher_shell.dart';
import 'app_route_observer.dart';
import 'app_routes.dart';

export 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static const String splash = AppRoutes.splash;
  static const String login = AppRoutes.login;
  static const String registerStudent = AppRoutes.registerStudent;
  static const String studentPending = AppRoutes.studentPending;
  static const String tenantSuspended = AppRoutes.tenantSuspended;

  // Role dashboards (No single dashboard with if-role - Task 5)
  static const String teacherDashboard = AppRoutes.teacherDashboard;
  static const String studentDashboard = AppRoutes.studentDashboard;
  static const String parentDashboard = AppRoutes.parentDashboard;

  // Feature: Groups routes
  static const String groupsList = AppRoutes.groupsList;
  static const String groupDetail = AppRoutes.groupDetail;

  // Feature: Attendance routes
  static const String teacherAttendance = AppRoutes.teacherAttendance;
  static const String studentAttendance = AppRoutes.studentAttendance;

  // Feature: Students routes
  static const String studentsList = AppRoutes.studentsList;
  static const String pendingStudents = AppRoutes.pendingStudents;
  static const String student360 = AppRoutes.student360;
  static const String assignGroups = AppRoutes.assignGroups;

  // Feature: Notifications routes
  static const String notificationsCenter = AppRoutes.notificationsCenter;
  static const String teacherNotifications = AppRoutes.teacherNotifications;
  static const String studentNotifications = AppRoutes.studentNotifications;
  static const String sendAnnouncement = AppRoutes.sendAnnouncement;

  // Feature: Content routes
  static const String teacherContent = AppRoutes.teacherContent;
  static const String teacherGroupContent = AppRoutes.teacherGroupContent;
  static const String teacherLessonDetails = AppRoutes.teacherLessonDetails;
  static const String studentGroupContent = AppRoutes.studentGroupContent;

  // Feature: Assignments routes
  static const String teacherAssignments = AppRoutes.teacherAssignments;
  static const String teacherGroupAssignments = AppRoutes.teacherGroupAssignments;
  static const String studentAssignments = AppRoutes.studentAssignments;

  // Feature: Exams routes
  static const String teacherExams = AppRoutes.teacherExams;
  static const String teacherGroupExams = AppRoutes.teacherGroupExams;
  static const String studentExams = AppRoutes.studentExams;

  // Feature: Platform Onboarding
  static const String platformOnboarding = AppRoutes.platformOnboarding;

  // Feature: Settings
  static const String teacherSettings = AppRoutes.teacherSettings;

  // Feature: Videos routes
  static const String teacherVideos = AppRoutes.teacherVideos;
  static const String videoPlayer = AppRoutes.videoPlayer;

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    observers: [AppRouteObserver.instance],
    redirect: (BuildContext context, GoRouterState state) {
      final isAuthenticated = SupabaseService.isAuthenticated;
      final path = state.matchedLocation;

      // Unauthenticated users trying to access protected role routes
      if (!isAuthenticated) {
        final isProtected = path.startsWith('/teacher') ||
            path.startsWith('/student') ||
            path.startsWith('/parent') ||
            path.startsWith('/platform') ||
            path.startsWith('/notifications') ||
            path.startsWith('/videos') ||
            path.startsWith('/video');
        if (isProtected) {
          return login;
        }
      } else {
        final role = SupabaseService.currentUserRole;

        // Redirect already authenticated users away from auth pages
        if (path == login || path == registerStudent) {
          if (role == 'student') return studentDashboard;
          if (role == 'parent') return parentDashboard;
          return teacherDashboard;
        }

        // Redirect generic /notifications to role-specific notifications shell route
        if (path == notificationsCenter) {
          if (role == 'student') return studentNotifications;
          return teacherNotifications;
        }

        // Enforce strict role-based access isolation
        if (role == 'student') {
          if (path.startsWith('/teacher') ||
              path.startsWith('/platform') ||
              path.startsWith('/parent')) {
            return studentDashboard;
          }
        }
        if (role == 'teacher') {
          if (path.startsWith('/student') || path.startsWith('/parent')) {
            return teacherDashboard;
          }
        }
        if (role == 'parent') {
          if (path.startsWith('/teacher') ||
              path.startsWith('/platform') ||
              path.startsWith('/student')) {
            return parentDashboard;
          }
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

      // ── Shared notifications redirect ───────────────────────────────
      GoRoute(
        path: notificationsCenter,
        redirect: (BuildContext context, GoRouterState state) {
          final role = SupabaseService.currentUserRole;
          if (role == 'student') return studentNotifications;
          return teacherNotifications;
        },
      ),

      // ── Teacher Shell (Persistent Navigation Bar & Categorized Sidebar) ────────
      // PERF: StudentsCubit is now provided at root level (main.dart) to avoid
      // re-creation on every route change within the teacher shell.
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return TeacherShell(
            currentLocation: state.matchedLocation,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: teacherDashboard,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                NoTransitionPage(
              child: BlocProvider(
                create: (_) => InjectionContainer.createTeacherDashboardCubit(),
                child: const TeacherDashboardPage(),
              ),
            ),
          ),
          GoRoute(
            path: groupsList,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                const NoTransitionPage(child: GroupsListPage()),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (BuildContext context, GoRouterState state) {
                  final id = state.pathParameters['id']!;
                  final group = state.extra as GroupEntity?;
                  return NoTransitionPage(
                    child: GroupDetailPage(groupId: id, initialGroup: group),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: teacherAttendance,
            pageBuilder: (BuildContext context, GoRouterState state) {
              final groupId = state.uri.queryParameters['groupId'];
              return NoTransitionPage(
                child: TeacherAttendancePage(initialGroupId: groupId),
              );
            },
          ),
          GoRoute(
            path: sendAnnouncement,
            pageBuilder: (BuildContext context, GoRouterState state) {
              final groupId = state.uri.queryParameters['groupId'];
              return NoTransitionPage(
                child: SendAnnouncementPage(initialGroupId: groupId),
              );
            },
          ),
          GoRoute(
            path: studentsList,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                const NoTransitionPage(child: StudentsListPage()),
          ),
          GoRoute(
            path: pendingStudents,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                const NoTransitionPage(child: PendingStudentsPage()),
          ),
          GoRoute(
            path: '/teacher/pending-approvals',
            redirect: (BuildContext context, GoRouterState state) => pendingStudents,
          ),
          GoRoute(
            path: student360,
            pageBuilder: (BuildContext context, GoRouterState state) {
              final studentId = state.uri.queryParameters['id']!;
              final student = state.extra as StudentEntity?;
              return NoTransitionPage(
                child: Student360Page(
                  studentId: studentId,
                  initialStudent: student,
                ),
              );
            },
          ),
          GoRoute(
            path: assignGroups,
            pageBuilder: (BuildContext context, GoRouterState state) {
              final studentId = state.extra as String;
              return NoTransitionPage(
                child: AssignGroupsPage(studentId: studentId),
              );
            },
          ),
          GoRoute(
            path: teacherSettings,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                const NoTransitionPage(
              child: TeacherSettingsPage(),
            ),
          ),
          GoRoute(
            path: platformOnboarding,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                NoTransitionPage(
              child: BlocProvider(
                create: (_) => InjectionContainer.createOnboardingCubit(),
                child: const PlatformOnboardingPage(),
              ),
            ),
          ),
          GoRoute(
            path: teacherContent,
            pageBuilder: (BuildContext context, GoRouterState state) {
              final groupId = state.uri.queryParameters['groupId'];
              final groupName = state.uri.queryParameters['name'];
              final preselectedVideo =
                  state.extra is ContentEntity ? state.extra as ContentEntity : null;
              return NoTransitionPage(
                child: BlocProvider(
                  create: (_) => InjectionContainer.createContentCubit(),
                  child: TeacherContentLibraryPage(
                    groupId: groupId,
                    groupName: groupName,
                    preselectedVideo: preselectedVideo,
                  ),
                ),
              );
            },
          ),
          GoRoute(
            path: teacherGroupContent,
            pageBuilder: (BuildContext context, GoRouterState state) {
              final rawGroupId = state.pathParameters['groupId'];
              final groupId =
                  rawGroupId != null ? GroupSlugResolver.toId(rawGroupId) : null;
              final extra = state.extra;
              final groupName =
                  (extra is String ? extra : null) ?? state.uri.queryParameters['name'];
              final preselectedVideo =
                  extra is ContentEntity ? extra : null;
              return NoTransitionPage(
                child: BlocProvider(
                  create: (_) => InjectionContainer.createContentCubit(),
                  child: TeacherContentLibraryPage(
                    groupId: groupId,
                    groupName: groupName,
                    preselectedVideo: preselectedVideo,
                  ),
                ),
              );
            },
          ),
          GoRoute(
            path: teacherLessonDetails,
            pageBuilder: (BuildContext context, GoRouterState state) {
              final rawGroupId = state.pathParameters['groupId']!;
              final groupId = GroupSlugResolver.toId(rawGroupId);
              final lessonId = state.pathParameters['lessonId']!;
              final groupName = state.uri.queryParameters['name'];
              return NoTransitionPage(
                child: BlocProvider(
                  create: (_) => InjectionContainer.createContentCubit(),
                  child: TeacherLessonDetailsPage(
                    groupId: groupId,
                    lessonId: lessonId,
                    groupName: groupName,
                  ),
                ),
              );
            },
          ),
          GoRoute(
            path: teacherVideos,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                NoTransitionPage(
              child: MultiBlocProvider(
                providers: [
                  BlocProvider(
                    create: (_) => InjectionContainer.createContentCubit(),
                  ),
                  BlocProvider(
                    create: (_) => InjectionContainer.createGroupsCubit(),
                  ),
                ],
                child: const TeacherVideoBankPage(),
              ),
            ),
          ),
          GoRoute(
            path: teacherAssignments,
            pageBuilder: (BuildContext context, GoRouterState state) {
              final groupId = state.uri.queryParameters['groupId'];
              final groupName = state.uri.queryParameters['name'];
              return NoTransitionPage(
                child: BlocProvider(
                  create: (_) => InjectionContainer.createAssignmentsCubit(),
                  child: TeacherAssignmentsPage(
                    groupId: groupId,
                    groupName: groupName,
                  ),
                ),
              );
            },
          ),
          GoRoute(
            path: teacherGroupAssignments,
            pageBuilder: (BuildContext context, GoRouterState state) {
              final rawGroupId = state.pathParameters['groupId'];
              final groupId = rawGroupId != null ? GroupSlugResolver.toId(rawGroupId) : null;
              final groupName = (state.extra as String?) ?? state.uri.queryParameters['name'];
              return NoTransitionPage(
                child: BlocProvider(
                  create: (_) => InjectionContainer.createAssignmentsCubit(),
                  child: TeacherAssignmentsPage(
                    groupId: groupId,
                    groupName: groupName,
                  ),
                ),
              );
            },
          ),
          GoRoute(
            path: teacherExams,
            pageBuilder: (BuildContext context, GoRouterState state) {
              final groupId = state.uri.queryParameters['groupId'];
              final groupName = state.uri.queryParameters['name'];
              final examId = state.uri.queryParameters['examId'];
              return NoTransitionPage(
                child: BlocProvider(
                  create: (_) => InjectionContainer.createExamsCubit(),
                  child: TeacherExamsPage(
                    groupId: groupId,
                    groupName: groupName,
                    initialExamId: examId,
                  ),
                ),
              );
            },
          ),
          GoRoute(
            path: teacherGroupExams,
            pageBuilder: (BuildContext context, GoRouterState state) {
              final rawGroupId = state.pathParameters['groupId'];
              final groupId = rawGroupId != null ? GroupSlugResolver.toId(rawGroupId) : null;
              final groupName = (state.extra as String?) ?? state.uri.queryParameters['name'];
              return NoTransitionPage(
                child: BlocProvider(
                  create: (_) => InjectionContainer.createExamsCubit(),
                  child: TeacherExamsPage(
                    groupId: groupId,
                    groupName: groupName,
                  ),
                ),
              );
            },
          ),
          GoRoute(
            path: teacherNotifications,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                const NoTransitionPage(child: NotificationsCenterPage()),
          ),
        ],
      ),

      // ── Student Shell (Persistent Navigation Bar & Categorized Sidebar) ────────
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return StudentShell(
            currentLocation: state.matchedLocation,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: studentDashboard,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                NoTransitionPage(
              child: BlocProvider(
                create: (_) => InjectionContainer.createStudentDashboardCubit(),
                child: const StudentDashboardPage(),
              ),
            ),
          ),
          GoRoute(
            path: studentAssignments,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                NoTransitionPage(
              child: BlocProvider(
                create: (_) => InjectionContainer.createAssignmentsCubit(),
                child: const StudentAssignmentsPage(),
              ),
            ),
          ),
          GoRoute(
            path: studentExams,
            pageBuilder: (BuildContext context, GoRouterState state) {
              final examId = state.uri.queryParameters['examId'];
              return NoTransitionPage(
                child: BlocProvider(
                  create: (_) => InjectionContainer.createExamsCubit(),
                  child: StudentExamsPage(initialExamId: examId),
                ),
              );
            },
          ),
          GoRoute(
            path: studentAttendance,
            pageBuilder: (BuildContext context, GoRouterState state) {
              final studentId = state.uri.queryParameters['studentId'];
              return NoTransitionPage(
                child: StudentAttendancePage(studentId: studentId),
              );
            },
          ),
          GoRoute(
            path: studentGroupContent,
            pageBuilder: (BuildContext context, GoRouterState state) {
              final rawGroupId = state.pathParameters['groupId']!;
              final groupId = GroupSlugResolver.toId(rawGroupId);
              final groupName = (state.extra as String?) ?? state.uri.queryParameters['name'];
              return NoTransitionPage(
                child: MultiBlocProvider(
                  providers: [
                    BlocProvider(
                      create: (_) => InjectionContainer.createCourseProgressCubit(),
                    ),
                    BlocProvider(
                      create: (_) => InjectionContainer.createContentCubit(), // Keep this for MaterialViewerSheet requirements (getSignedUrl)
                    ),
                  ],
                  child: StudentContentFeedPage(
                    groupId: groupId,
                    groupName: groupName,
                  ),
                ),
              );
            },
          ),
          GoRoute(
            path: studentNotifications,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                const NoTransitionPage(child: NotificationsCenterPage()),
          ),
        ],
      ),

      // ── Parent standalone routes ────────────────────────────────────
      GoRoute(
        path: parentDashboard,
        builder: (BuildContext context, GoRouterState state) {
          return const ParentDashboardPage();
        },
      ),

      // ── Fullscreen immersive Video Player route ─────────────────────
      GoRoute(
        path: videoPlayer,
        builder: (BuildContext context, GoRouterState state) {
          final videoId = state.uri.queryParameters['id'] ?? (state.extra as String? ?? '');
          final studentId = state.uri.queryParameters['studentId'];
          final associatedExamId = state.uri.queryParameters['associatedExamId'];
          final associatedExamTitle = state.uri.queryParameters['associatedExamTitle'];
          final groupId = state.uri.queryParameters['groupId'];
          final groupName = state.uri.queryParameters['groupName'];
          final lessonIndex = int.tryParse(state.uri.queryParameters['lessonIndex'] ?? '');
          final totalLessons = int.tryParse(state.uri.queryParameters['totalLessons'] ?? '');
          return BlocProvider<VideosCubit>(
            create: (_) => InjectionContainer.createVideosCubit(),
            child: VideoPlayerPage(
              videoId: videoId,
              studentId: studentId,
              associatedExamId: associatedExamId?.isNotEmpty == true ? associatedExamId : null,
              associatedExamTitle: associatedExamTitle?.isNotEmpty == true ? associatedExamTitle : null,
              groupId: groupId?.isNotEmpty == true ? groupId : null,
              groupName: groupName?.isNotEmpty == true ? groupName : null,
              lessonIndex: lessonIndex,
              totalLessons: totalLessons,
            ),
          );
        },
      ),
      GoRoute(
        path: '/video/:id',
        builder: (BuildContext context, GoRouterState state) {
          final videoId = state.pathParameters['id'] ?? (state.extra as String? ?? '');
          final studentId = state.uri.queryParameters['studentId'];
          final associatedExamId = state.uri.queryParameters['associatedExamId'];
          final associatedExamTitle = state.uri.queryParameters['associatedExamTitle'];
          final groupId = state.uri.queryParameters['groupId'];
          final groupName = state.uri.queryParameters['groupName'];
          final lessonIndex = int.tryParse(state.uri.queryParameters['lessonIndex'] ?? '');
          final totalLessons = int.tryParse(state.uri.queryParameters['totalLessons'] ?? '');
          return BlocProvider<VideosCubit>(
            create: (_) => InjectionContainer.createVideosCubit(),
            child: VideoPlayerPage(
              videoId: videoId,
              studentId: studentId,
              associatedExamId: associatedExamId?.isNotEmpty == true ? associatedExamId : null,
              associatedExamTitle: associatedExamTitle?.isNotEmpty == true ? associatedExamTitle : null,
              groupId: groupId?.isNotEmpty == true ? groupId : null,
              groupName: groupName?.isNotEmpty == true ? groupName : null,
              lessonIndex: lessonIndex,
              totalLessons: totalLessons,
            ),
          );
        },
      ),
    ],
  );
}
