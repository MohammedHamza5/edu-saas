import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
      AppLogger.d('Prefetch', '✅ Teacher data prefetched (${futures.length} sources)');
    }
  }

  /// Prefetch student dashboard data in parallel.
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

    if (futures.isNotEmpty) {
      await Future.wait(futures);
      AppLogger.d('Prefetch', '✅ Student data prefetched (${futures.length} sources)');
    }
  }
}
