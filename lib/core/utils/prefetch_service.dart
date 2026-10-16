import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/assignments/presentation/cubit/assignments_cubit.dart';
import '../../features/assignments/presentation/cubit/assignments_state.dart';
import '../../features/attendance/presentation/cubit/attendance_cubit.dart';
import '../../features/attendance/presentation/cubit/attendance_state.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/auth_state.dart';
import '../../features/exams/presentation/cubit/exams_cubit.dart';
import '../../features/exams/presentation/cubit/exams_state.dart';
import '../../features/exams/presentation/cubit/mistakes_cubit.dart';
import '../../features/exams/presentation/cubit/mistakes_state.dart';
import '../../features/groups/presentation/cubit/groups_cubit.dart';
import '../../features/groups/presentation/cubit/groups_state.dart';
import '../../features/notifications/presentation/cubit/notifications_cubit.dart';
import '../../features/notifications/presentation/cubit/notifications_state.dart';
import '../../features/students/presentation/cubit/students_cubit.dart';
import '../../features/students/presentation/cubit/students_state.dart';
import 'app_logger.dart';

/// Smart prefetch service that loads data for screens the user is likely to visit next.
///
/// Call from the shell/dashboard on first load to ensure all primary data is
/// warm in cache. Uses silentRefresh where possible to avoid loading states.
///
/// Supabase remains the single source of truth — this only warms the cache.
abstract final class PrefetchService {
  /// Prefetch all teacher dashboard data in parallel.
  /// Called once from TeacherShell or TeacherDashboard on first mount.
  ///
  /// Loads: Students, Groups, Notifications — all in parallel, silently.
  static Future<void> prefetchTeacherData(BuildContext context) async {
    AppLogger.d('Prefetch', '🔮 Prefetching teacher data...');

    final futures = <Future<void>>[];

    // Students
    try {
      final cubit = context.read<StudentsCubit>();
      if (cubit.state is StudentsInitial) {
        futures.add(cubit.loadStudents());
      } else {
        futures.add(cubit.silentRefresh());
      }
    } catch (_) {}

    // Groups
    try {
      final cubit = context.read<GroupsCubit>();
      if (cubit.state is GroupsInitial) {
        futures.add(cubit.loadGroups());
      } else {
        futures.add(cubit.silentRefresh());
      }
    } catch (_) {}

    // Notifications
    try {
      final cubit = context.read<NotificationsCubit>();
      if (cubit.state is NotificationsInitial) {
        futures.add(cubit.loadNotifications());
      } else {
        futures.add(cubit.silentRefresh());
      }
    } catch (_) {}

    if (futures.isNotEmpty) {
      await Future.wait(futures);
      AppLogger.d(
        'Prefetch',
        '✅ Teacher data prefetched (${futures.length} sources)',
      );
    }
  }

  /// Prefetch student dashboard data in parallel.
  /// Called on StudentShell mount to warm up all student domains silently.
  static Future<void> prefetchStudentData(BuildContext context) async {
    AppLogger.d('Prefetch', '🔮 Prefetching student data...');

    final futures = <Future<void>>[];

    // Notifications
    try {
      final cubit = context.read<NotificationsCubit>();
      if (cubit.state is NotificationsInitial) {
        futures.add(cubit.loadNotifications());
      } else {
        futures.add(cubit.silentRefresh());
      }
    } catch (_) {}

    // Groups
    try {
      final cubit = context.read<GroupsCubit>();
      if (cubit.state is GroupsInitial) {
        futures.add(cubit.loadGroups());
      } else {
        futures.add(cubit.silentRefresh());
      }
    } catch (_) {}

    // Exams
    try {
      final cubit = context.read<ExamsCubit>();
      if (cubit.state is ExamsInitial) {
        futures.add(cubit.loadStudentExams());
      }
    } catch (_) {}

    // Assignments
    try {
      final cubit = context.read<AssignmentsCubit>();
      if (cubit.state is AssignmentsInitial) {
        futures.add(cubit.loadStudentAssignments());
      }
    } catch (_) {}

    // Mistakes
    try {
      final cubit = context.read<MistakesCubit>();
      if (cubit.state is MistakesInitial) {
        futures.add(cubit.loadMistakes());
      }
    } catch (_) {}

    // Attendance
    try {
      final authState = context.read<AuthCubit>().state;
      if (authState is AuthAuthenticated) {
        final cubit = context.read<AttendanceCubit>();
        if (cubit.state is AttendanceInitial) {
          futures.add(cubit.loadStudentAttendance(studentId: authState.user.id));
        }
      }
    } catch (_) {}

    if (futures.isNotEmpty) {
      await Future.wait(futures);
      AppLogger.d(
        'Prefetch',
        '✅ Student data prefetched (${futures.length} sources)',
      );
    }
  }
}
