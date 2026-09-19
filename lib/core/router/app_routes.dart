/// Centralized route paths for EduSaaS platform.
///
/// Keeping this pure (no UI/widget dependencies) eliminates circular dependencies
/// between [AppRouter] and the presentation pages that navigate between routes.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String registerStudent = '/register-student';
  static const String studentPending = '/student-pending';
  static const String tenantSuspended = '/tenant-suspended';

  // Role dashboards
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
  static const String teacherNotifications = '/teacher/notifications';
  static const String studentNotifications = '/student/notifications';
  static const String sendAnnouncement = '/teacher/announcements/new';

  // Feature: Content routes
  static const String teacherContent = '/teacher/content';
  static const String teacherGroupContent = '/teacher/groups/:groupId/content';
  static const String studentGroupContent = '/student/groups/:groupId/content';

  // Feature: Assignments routes
  static const String teacherAssignments = '/teacher/assignments';
  static const String teacherGroupAssignments =
      '/teacher/groups/:groupId/assignments';
  static const String studentAssignments = '/student/assignments';

  // Feature: Exams routes
  static const String teacherExams = '/teacher/exams';
  static const String teacherGroupExams = '/teacher/groups/:groupId/exams';
  static const String studentExams = '/student/exams';

  // Feature: Platform Onboarding
  static const String platformOnboarding = '/platform/onboarding';

  // Feature: Settings
  static const String teacherSettings = '/teacher/settings';

  // Feature: Videos routes
  static const String teacherVideos = '/teacher/videos';
  static const String videoPlayer = '/videos/player';
}
